# frozen_string_literal: true

require "thor"
require_relative "../kotoshu"
require_relative "cli/cache_command"
require_relative "cli/errors"

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
    # Exit codes:
    #   0 — no errors found
    #   1 — spelling errors found
    #   2 — usage error (file not found, bad flags)
    #   3 — dictionary fetch failure (network down, offline+uncached)
    #
    # Commands raise Errors::CliError subclasses; the dispatcher in .start
    # catches them and exits with the error's exit_status.
    class Cli < Thor
      class_option :language,
                   type: :string,
                   default: "auto",
                   desc: "Language code (auto, en, de, es, fr, pt, ru)",
                   aliases: ["-l"]

      class_option :format,
                   type: :string,
                   enum: %w[text json sarif],
                   default: "text",
                   desc: "Output format (text, json, sarif)",
                   aliases: ["-f"]

      class_option :offline,
                   type: :boolean,
                   default: false,
                   desc: "Use only cached resources; do not download"

      class_option :strict,
                   type: :boolean,
                   default: false,
                   desc: "Fail (exit 3) if any optional resource cannot be loaded"

      class_option :interactive,
                   type: :boolean,
                   default: false,
                   desc: "Interactively review each error after check",
                   aliases: ["-i"]

      class_option :verbose,
                   type: :boolean,
                   default: false,
                   desc: "Enable verbose output",
                   aliases: ["-v"]

      desc "check [FILE]", "Check spelling in a file or stdin"
      def check(target = nil)
        apply_configuration!

        text, source = read_target(target)
        result = run_check(text)
        display_result(result, source)
        interactive_review(result, source) if options[:interactive] && result.failed?
        exit 1 if result.failed?
      end

      desc "fetch LANGUAGE [LANGUAGE ...]", "Pre-warm spelling and frequency caches"
      long_desc <<~DESC
        Downloads and caches resources for one or more languages so subsequent
        `kotoshu check` runs work offline.

        Exit codes:
          0 — every language resolved successfully
          3 — at least one language could not be resolved (network down, etc.)
      DESC
      def fetch(*languages)
        apply_configuration!

        raise Errors::UsageError, "at least one LANGUAGE is required" if languages.empty?

        results = languages.map do |lang|
          print "Fetching #{lang}... "
          begin
            bundle = Kotoshu::ResourceManager.resolve(
              language: lang,
              want: %i[spelling frequency],
              offline: options[:offline],
              strict: false
            )
            spelling_state = bundle.cached? ? "cached" : "downloaded"
            frequency_state = bundle.frequency ? "cached/downloaded" : "unavailable"
            puts "OK (spelling: #{spelling_state}, frequency: #{frequency_state})"
            { lang: lang, ok: true }
          rescue Kotoshu::Error => e
            puts "FAIL: #{e.message}"
            { lang: lang, ok: false }
          end
        end

        failed = results.reject { |r| r[:ok] }
        puts "Fetched #{results.size} language(s)."
        unless failed.empty?
          raise Errors::ResourceUnavailable,
                "failed to fetch: #{failed.map { |r| r[:lang] }.join(', ')}"
        end
      end

      desc "dict SUBCOMMAND", "Dictionary operations"
      subcommand "dict", DictCommand

      desc "cache SUBCOMMAND", "Cache management"
      subcommand "cache", CacheCommand

      desc "version", "Show version information"
      def version
        puts "Kotoshu version #{Kotoshu::VERSION}"
        puts "Ruby #{RUBY_VERSION}"
      end

      map %w[--version -V] => :version

      # Dispatch entry point — bypasses Thor's start rescue so we can honor
      # exit_status from Errors::CliError subclasses. Thor::Error still falls
      # back to exit 1 for framework-level errors (bad flags, etc.).
      def self.start(given_args = ARGV, config = {})
        config[:shell] ||= Thor::Base.shell.new
        dispatch(nil, given_args.dup, nil, config)
      rescue Errors::CliError => e
        warn "Error: #{e.message}"
        exit e.exit_status
      rescue Thor::Error => e
        warn e.message
        exit 1
      end

      def self.exit_on_failure?
        false
      end

      private

      # Apply CLI flags to the global Configuration.
      def apply_configuration!
        Kotoshu::Configuration.reset
        cfg = Kotoshu::Configuration.instance
        cfg.offline = options[:offline] if options[:offline]
      end

      # Read text from a file path, stdin, or treat the target as text.
      #
      # @param target [String, nil] File path, text, or nil for stdin
      # @return [Array(String, String)] (text, source_label)
      def read_target(target)
        if target.nil?
          [$stdin.read, "<stdin>"]
        elsif File.exist?(target)
          [File.read(target, encoding: Kotoshu.configuration.encoding), target]
        else
          raise Errors::UsageError, "File not found: #{target}"
        end
      end

      # Resolve resources and run the spellcheck.
      #
      # @param text [String] Text to check
      # @return [Models::Result::DocumentResult]
      def run_check(text)
        language = resolve_language
        spellchecker = Kotoshu.spellchecker_for(
          language,
          offline: options[:offline],
          strict: options[:strict]
        )
        spellchecker.check(text)
      rescue Kotoshu::ResourceNotCachedError,
             Kotoshu::ResourceResolutionError,
             Kotoshu::DictionaryNotFoundError => e
        raise Errors::ResourceUnavailable, e.message
      end

      # Resolve the language from --language flag (auto-detect if "auto").
      #
      # @return [String] Language code
      def resolve_language
        lang = options[:language]
        return Kotoshu.configuration.default_language if lang.nil? || lang == "auto"

        lang
      end

      # Display a check result in the requested format.
      #
      # @param result [Models::Result::DocumentResult] The result
      # @param source [String] The source label
      def display_result(result, source)
        case options[:format]
        when "json"
          puts format_as_json(result, source)
        when "sarif"
          puts format_as_sarif(result, source)
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
          "OK #{source} (#{result.word_count} words, no errors)"
        else
          lines = []
          lines << "FAIL #{source} (#{result.error_count} errors)"
          result.each_error do |error|
            suggestions_str = if error.has_suggestions?
                                " -> #{error.top_suggestions(3).join(", ")}"
                              else
                                ""
                              end
            lines << "  #{error.word}#{suggestions_str}"
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
        output["source"] = source
        JSON.pretty_generate(output)
      end

      # Format result as SARIF 2.1.0 (Static Analysis Results Interchange Format).
      #
      # @param result [Models::Result::DocumentResult] The result
      # @param source [String] The source label (file path or "<stdin>")
      # @return [String] SARIF JSON
      def format_as_sarif(result, source)
        require "json"

        results = result.errors.map do |err|
          suggestions = err.top_suggestions(3)
          suggestion_text = suggestions.empty? ? "" : " Suggestions: #{suggestions.join(", ")}"
          {
            "ruleId" => "kotoshu/spelling",
            "level" => "warning",
            "message" => {
              "text" => "'#{err.word}' is not in the dictionary.#{suggestion_text}"
            },
            "locations" => [
              {
                "physicalLocation" => {
                  "artifactLocation" => { "uri" => source_for_sarif(source) },
                  "region" => {
                    "charOffset" => err.position || 0,
                    "charLength" => err.word.length
                  }
                }
              }
            ]
          }
        end

        sarif = {
          "version" => "2.1.0",
          "$schema" => "https://json.schemastore.org/sarif-2.1.0.json",
          "runs" => [
            {
              "tool" => {
                "driver" => {
                  "name" => "kotoshu",
                  "version" => Kotoshu::VERSION,
                  "informationUri" => "https://github.com/kotoshu/kotoshu",
                  "rules" => [
                    {
                      "id" => "kotoshu/spelling",
                      "name" => "SpellingError",
                      "shortDescription" => {
                        "text" => "Word not found in the active dictionary."
                      }
                    }
                  ]
                }
              },
              "results" => results
            }
          ]
        }
        JSON.pretty_generate(sarif)
      end

      # SARIF artifactLocation.uri wants a real file path or a clear placeholder.
      #
      # @param source [String] Source label
      # @return [String]
      def source_for_sarif(source)
        source == "<stdin>" ? "stdin" : source
      end

      # Interactive review loop over a failed DocumentResult.
      #
      # For 0.3 this is navigation-only — it does not rewrite the source file.
      # Keybindings:
      #   [1-9]  accept suggestion N (record only)
      #   s      skip this error
      #   n/Enter move to next error
      #   p      move to previous error
      #   l      list all errors
      #   q      quit
      #
      # @param result [Models::Result::DocumentResult]
      # @param source [String]
      def interactive_review(result, source)
        errors = result.errors
        return if errors.empty?

        index = 0
        accepted = {}
        skipped = Set.new

        puts
        puts "Interactive review: #{errors.size} error(s) in #{source}"
        puts "Commands: [1-9] accept, [s] skip, [n]/Enter next, [p] prev, [l] list, [q] quit"

        while index < errors.size
          err = errors[index]
          puts
          puts "[#{index + 1}/#{errors.size}] '#{err.word}' (offset #{err.position || '?'})"
          suggestions = err.top_suggestions(9)
          if suggestions.empty?
            puts "  (no suggestions)"
          else
            suggestions.each_with_index { |s, i| puts "  [#{i + 1}] #{s}" }
          end
          print "> "
          input = $stdin.gets
          break if input.nil?

          input = input.chomp.downcase

          case input
          when "q"
            puts "Quitting review."
            break
          when "n", ""
            index += 1
          when "p"
            index = [index - 1, 0].max
          when "l"
            errors.each_with_index do |e, i|
              marker = case
                       when accepted.key?(i) then "✓"
                       when skipped.include?(i) then "s"
                       else " "
                       end
              puts "  #{marker} #{i + 1}. #{e.word}"
            end
          when "s"
            skipped << index
            index += 1
          when /\A[1-9]\z/
            choice = input.to_i - 1
            suggestion = suggestions[choice]
            if suggestion
              accepted[index] = suggestion
              puts "  → '#{err.word}' → '#{suggestion}' (recorded)"
              index += 1
            else
              puts "  No suggestion at that number."
            end
          else
            puts "  Unknown command."
          end
        end

        puts
        puts "Review complete: #{accepted.size} accepted, #{skipped.size} skipped, " \
             "#{errors.size - accepted.size - skipped.size} unhandled."
        puts "Note: 0.3 records decisions but does not rewrite source files." unless accepted.empty?
      end
    end
  end
end
