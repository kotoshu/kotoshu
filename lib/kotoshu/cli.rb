# frozen_string_literal: true

require "thor"
require_relative "version"
require_relative "spellchecker"
require_relative "configuration"

# Dictionary command class.
#
# @example
#   kotoshu dict list
#   kotoshu dict info en-US
class DictCommand < Thor
  desc "list", "List available dictionaries"
  def list
    puts "Available dictionary types:"
    puts "  - unix_words: Unix system dictionary"
    puts "  - plain_text: Plain text word list"
    puts "  - custom: Custom in-memory dictionary"
    puts "  - hunspell: Hunspell (.dic/.aff)"
    puts "  - cspell: CSpell (.txt/.trie)"
  end

  desc "info TYPE", "Show information about a dictionary type"
  def info(type)
    case type.to_sym
    when :unix_words
      puts "UnixWords Dictionary:"
      puts "  Reads from Unix system dictionary files"
      puts "  Default paths:"
      puts "    - /usr/share/dict/words"
      puts "    - /usr/share/dict/web2"
      puts "    - /usr/share/dict/american-english"
    when :plain_text
      puts "PlainText Dictionary:"
      puts "  Reads from plain text word lists"
      puts "  One word per line, # comments supported"
    when :custom
      puts "Custom Dictionary:"
      puts "  In-memory dictionary for user-defined words"
    when :hunspell
      puts "Hunspell Dictionary:"
      puts "  Reads Hunspell .dic and .aff files"
      puts "  Supports morphological affix rules"
    when :cspell
      puts "CSpell Dictionary:"
      puts "  Reads CSpell .txt or .trie files"
      puts "  Uses trie data structure for fast lookups"
    else
      puts "Unknown dictionary type: #{type}"
      puts "Run 'kotoshu dict list' for available types"
    end
  end
end

module Kotoshu
  module Cli
    # Command-line interface for Kotoshu spell checker.
    #
    # This class provides the CLI commands using Thor.
    #
    # @example From the command line
    #   kotoshu check "Hello wrold"
    #   kotoshu check README.md
    #   kotoshu version
    class Cli < Thor
      class_option :verbose,
                   type: :boolean,
                   default: false,
                   desc: "Enable verbose output",
                   aliases: ["-v"]

      class_option :dictionary,
                   type: :string,
                   default: nil,
                   desc: "Dictionary type (unix_words, plain_text, hunspell, cspell)",
                   aliases: ["-d"]

      class_option :dictionary_path,
                   type: :string,
                   default: nil,
                   desc: "Path to dictionary file",
                   aliases: ["-p"]

      class_option :language,
                   type: :string,
                   default: "en-US",
                   desc: "Language code (e.g., en-US, en-GB)",
                   aliases: ["-l"]

      class_option :max_suggestions,
                   type: :numeric,
                   default: 10,
                   desc: "Maximum number of suggestions",
                   aliases: ["-m", "-n"]

      class_option :output,
                   type: :string,
                   default: "text",
                   desc: "Output format (text, json)",
                   aliases: ["-o"]

      desc "check TARGET", "Check spelling of text or file"
      method_option :color, type: :boolean, default: true, desc: "Colorize output"
      method_option :exit_code, type: :boolean, default: true, desc: "Set exit code based on result"
      def check(target = nil)
        configure_from_options

        if target.nil?
          # Read from stdin
          text = $stdin.read
          result = spellchecker.check(text)
          display_result(result, "")
        elsif File.exist?(target)
          # Check file
          result = spellchecker.check_file(target)
          display_result(result, target)
        else
          # Check as text
          result = spellchecker.check(target)
          display_result(result, "<input>")
        end

        exit(result.failed? ? 1 : 0) if options[:exit_code]
      end

      desc "dict SUBCOMMAND", "Dictionary operations"
      subcommand "dict", DictCommand

      desc "version", "Show version information"
      def version
        puts "Kotoshu version #{Kotoshu::VERSION}"
        puts "Ruby #{RUBY_VERSION}"
      end

      map %w[--version -v] => :version

      private

      # Get the spellchecker instance.
      #
      # @return [Spellchecker] The spellchecker
      def spellchecker
        @spellchecker ||= Spellchecker.new(config: configuration)
      end

      # Get the configuration instance.
      #
      # @return [Configuration] The configuration
      def configuration
        @configuration ||= Configuration.new(build_config_hash)
      end

      # Build configuration hash from options.
      #
      # @return [Hash] Configuration settings
      def build_config_hash
        {
          dictionary_path: options[:dictionary_path],
          dictionary_type: options[:dictionary]&.to_sym,
          language: options[:language],
          max_suggestions: options[:max_suggestions],
          verbose: options[:verbose]
        }
      end

      # Configure from command-line options.
      def configure_from_options
        # Configuration is already built in #configuration
      end

      # Display a check result.
      #
      # @param result [Models::Result::DocumentResult] The result
      # @param source [String] The source (file path or identifier)
      def display_result(result, source)
        case options[:output]
        when "json"
          puts format_as_json(result, source)
        else
          puts format_as_text(result, source)
        end
      end

      # Format result as text.
      #
      # @param result [Models::Result::DocumentResult] The result
      # @param source [String] The source
      # @return [String] Formatted output
      def format_as_text(result, source)
        if result.success?
          if source && source != "<input>"
            "✓ #{source}: No spelling errors (#{result.word_count} words)"
          else
            "✓ No spelling errors (#{result.word_count} words)"
          end
        else
          lines = []
          lines << if source && source != "<input>"
                     "✗ #{source}: #{result.error_count} error(s) found"
                   else
                     "✗ #{result.error_count} error(s) found"
                   end

          result.each_error do |error|
            suggestions_str = if error.has_suggestions?
                               " (did you mean #{error.top_suggestions(3).join(', ')}?)"
                             else
                             ""
                             end

            lines << "  • #{error.word}#{suggestions_str}"
          end

          lines.join("\n")
        end
      end

      # Format result as JSON.
      #
      # @param result [Models::Result::DocumentResult] The result
      # @param source [String] The source
      # @return [String] JSON output
      def format_as_json(result, source)
        require "json"

        output = result.as_json
        output["source"] = source if source
        JSON.pretty_generate(output)
      end
    end
  end
end
