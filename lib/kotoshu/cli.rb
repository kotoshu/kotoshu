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
    # LAZY: CLI helper components (autoloaded on first reference)
    autoload :NavigationManager, "kotoshu/cli/navigation_manager"
    autoload :DisplayFormatter, "kotoshu/cli/display_formatter"
    autoload :InteractiveReviewer, "kotoshu/cli/interactive_reviewer"
    autoload :BatchReporter, "kotoshu/cli/batch_reporter"
    autoload :AutoSetup, "kotoshu/cli/auto_setup"
    autoload :StatusReport, "kotoshu/cli/status_report"
    autoload :LanguageResolver, "kotoshu/cli/language_resolver"

    # Command-line interface for Kotoshu spell checker.
    #
    # Two-stage model:
    #   Stage 1 (slow, network): `kotoshu setup LANG` downloads/registers resources
    #   Stage 2 (instant, cache-only): `kotoshu check FILE` uses cached resources
    #
    # Exit codes:
    #   0 — no errors found / setup succeeded
    #   1 — spelling errors found
    #   2 — usage error (file not found, bad flags)
    #   3 — resource not set up / setup failure (network, integrity)
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
      long_desc <<~DESC
        Checks spelling in the given file (or stdin if no file is given).
        Cache-only — never downloads. Run `kotoshu setup LANG` first.

        Exit codes:
          0 — no errors
          1 — spelling errors found
          2 — usage error (bad flags, file not found)
          3 — language not set up (run `kotoshu setup LANG`)
      DESC
      def check(target = nil)
        apply_configuration!

        text, source = read_target(target)
        result = run_check(text)
        display_result(result, source)
        interactive_review(result, source) if options[:interactive] && result.failed?
        exit 1 if result.failed?
      end

      desc "setup [LANGUAGE] [LANGUAGE ...]", "Set up languages (download or register local files)"
      long_desc <<~DESC
        Stage 1 of the two-stage model. Downloads spelling/frequency/model
        resources for the named language(s), or registers local .aff/.dic
        files you already have on disk. After setup, `kotoshu check` runs
        instantly with no network access.

        With no args, lists currently set up languages.

        Sources (one per invocation, applies to all listed languages):
          --aff FILE --dic FILE   use specific local Hunspell files
          --from DIR              look for {lang}.aff and {lang}.dic in DIR
          (neither)               download from kotoshu/dictionaries

        Examples:
          kotoshu setup en de fr                       # download from GitHub
          kotoshu setup en --want spelling,frequency   # also fetch Kelly list
          kotoshu setup en --aff /p/en.aff --dic /p/en.dic
          kotoshu setup en --from /usr/share/hunspell/
          kotoshu setup --force en                     # re-download
          kotoshu setup --list                         # show what's set up

        Exit codes:
          0 — every language set up successfully
          3 — at least one language failed (network down, integrity, etc.)
      DESC
      method_option :aff, type: :string, desc: "Path to local .aff file"
      method_option :dic, type: :string, desc: "Path to local .dic file"
      method_option :from, type: :string, desc: "Directory containing local .aff/.dic"
      method_option :frequency, type: :string, desc: "Path to local frequency.json"
      method_option :want,
                    type: :string,
                    default: "spelling",
                    desc: "Comma-separated: spelling,frequency,model"
      method_option :force,
                    type: :boolean,
                    default: false,
                    desc: "Re-fetch even if already cached"
      method_option :strict,
                    type: :boolean,
                    default: false,
                    desc: "Re-raise on optional-resource failure during setup"
      method_option :list,
                    type: :boolean,
                    default: false,
                    desc: "List currently set up languages and exit"
      def setup(*languages)
        apply_configuration!

        if options[:list] || languages.empty?
          list_setup
          return
        end

        want = (options[:want] || "spelling").split(",").map(&:strip).map(&:to_sym)
        opts = setup_source_options(languages)
        opts[:want] = want
        opts[:force] = options[:force]
        opts[:strict] = options[:strict]

        results = languages.map do |lang|
          print "Setup #{lang}... "
          begin
            result = Kotoshu.setup(lang, **opts)
            describe_setup_result(result)
            { lang: lang, ok: true }
          rescue Kotoshu::Error, ArgumentError => e
            puts "FAIL: #{e.message}"
            { lang: lang, ok: false }
          end
        end

        failed = results.reject { |r| r[:ok] }
        puts "Set up #{results.size} language(s)."
        return if failed.empty?

        raise Errors::ResourceUnavailable,
              "failed to set up: #{failed.map { |r| r[:lang] }.join(', ')}"
      end

      # Back-compat alias. New code should use `setup`.
      desc "fetch LANGUAGE [LANGUAGE ...]", "Alias for `setup` (deprecated)", hide: true
      method_option :aff, type: :string, desc: "Path to local .aff file"
      method_option :dic, type: :string, desc: "Path to local .dic file"
      method_option :from, type: :string, desc: "Directory containing local .aff/.dic"
      method_option :frequency, type: :string, desc: "Path to local frequency.json"
      method_option :want,
                    type: :string,
                    default: "spelling",
                    desc: "Comma-separated: spelling,frequency,model"
      method_option :force,
                    type: :boolean,
                    default: false,
                    desc: "Re-fetch even if already cached"
      method_option :strict,
                    type: :boolean,
                    default: false,
                    desc: "Re-raise on optional-resource failure during setup"
      method_option :list,
                    type: :boolean,
                    default: false,
                    desc: "List currently set up languages and exit"
      def fetch(*languages)
        setup(*languages)
      end

      desc "dict SUBCOMMAND", "Dictionary operations"
      subcommand "dict", DictCommand

      desc "cache SUBCOMMAND", "Cache management"
      subcommand "cache", CacheCommand

      desc "status", "Show setup, cache, and runtime status"
      long_desc <<~DESC
        Prints a snapshot of the kotoshu installation: which languages are
        set up (with per-resource status), cache disk usage, audit log path,
        default language, offline flag, and whether onnxruntime is loaded.

        With --json, emits the same report as a JSON object for tooling.
      DESC
      method_option :json,
                    type: :boolean,
                    default: false,
                    desc: "Emit the report as JSON"
      def status
        report = StatusReport.build(version: Kotoshu::VERSION)
        if options[:json]
          puts status_json(report)
        else
          puts status_text(report)
        end
      end

      desc "version", "Show version information"
      def version
        puts "Kotoshu version #{Kotoshu::VERSION}"
        puts "Ruby #{RUBY_VERSION}"
      end

      map %w[--version -V] => :version

      # Dispatch entry point — bypasses Thor's start rescue so we can honor
      # exit_status from Errors::CliError subclasses. Thor::Error still falls
      # back to exit 1 for framework-level errors (bad flags, etc.).
      #
      # ResourceNotSetupError from the strict two-stage model is intercepted
      # here: AutoSetup asks the user once, then we retry the dispatch. In
      # non-TTY or offline mode AutoSetup re-raises so scripts see stable
      # behavior.
      def self.start(given_args = ARGV, config = {})
        config[:shell] ||= Thor::Base.shell.new
        dispatch(nil, given_args.dup, nil, config)
      rescue Kotoshu::ResourceNotSetupError => e
        raise Errors::ResourceUnavailable, e.message unless AutoSetup.new.call(e)

        retry
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

      def apply_configuration!
        Kotoshu::Configuration.reset
        cfg = Kotoshu::Configuration.instance
        cfg.default_language = options[:language] if options[:language] && options[:language] != "auto"
      end

      def status_text(report)
        lines = []
        lines << "Kotoshu #{report.version}"
        lines << ""

        lines << "Setup:"
        if report.resources.empty?
          lines << "  (no languages set up — run `kotoshu setup LANG`)"
        else
          report.resources.each do |r|
            mark = r.available ? "✓" : "✗"
            size = r.available ? StatusReport.format_bytes(r.size_bytes) : "—"
            when_str = r.cached_at ? "cached #{r.cached_at.strftime('%Y-%m-%d')}" : ""
            lines << format("  %-4s %-10s %s  %s%s",
                            r.language, r.resource, mark, size,
                            when_str.empty? ? "" : ", #{when_str}")
          end
        end
        lines << ""

        lines << "Cache:"
        lines << "  Path           #{report.cache_path}"
        lines << "  Size           #{StatusReport.format_bytes(report.cache_size_bytes)}"
        lines << "  Languages      #{report.languages_setup.size}"
        lines << ""

        lines << "Semantic:"
        onnx_state = report.onnx_loaded ? "loaded" : "not loaded (gem install onnxruntime to enable)"
        lines << "  onnxruntime    #{onnx_state}"
        active_models = report.languages_with_model
        models_str = active_models.empty? ? "0" : "#{active_models.size} (#{active_models.join(', ')})"
        lines << "  Active models  #{models_str}"
        lines << ""

        lines << "Other:"
        if report.audit_log_path
          lines << "  Audit log      #{report.audit_log_path} (#{StatusReport.format_bytes(report.audit_log_size_bytes)})"
        else
          lines << "  Audit log      (none yet — created on first audited operation)"
        end
        lines << "  Default lang   #{report.default_language || '(none)'}"
        lines << "  Offline mode   #{report.offline ? 'yes' : 'no'}"
        lines.join("\n")
      end

      def status_json(report)
        require "json"

        payload = {
          version: report.version,
          setup: report.resources.map do |r|
            {
              language: r.language,
              resource: r.resource.to_s,
              available: r.available,
              size_bytes: r.size_bytes,
              cached_at: r.cached_at&.iso8601
            }
          end,
          cache: {
            path: report.cache_path,
            size_bytes: report.cache_size_bytes,
            languages: report.languages_setup.size
          },
          semantic: {
            onnxruntime_loaded: report.onnx_loaded,
            active_models: report.languages_with_model
          },
          audit_log: report.audit_log_path && {
            path: report.audit_log_path,
            size_bytes: report.audit_log_size_bytes
          },
          default_language: report.default_language,
          offline: report.offline
        }
        JSON.pretty_generate(payload)
      end

      def read_target(target)
        if target.nil?
          [$stdin.read, "<stdin>"]
        elsif File.exist?(target)
          [File.read(target, encoding: Kotoshu.configuration.encoding), target]
        else
          raise Errors::UsageError, "File not found: #{target}"
        end
      end

      def run_check(text)
        language = resolve_language(text)
        spellchecker = Kotoshu.spellchecker_for(language)
        spellchecker.check(text)
      rescue Kotoshu::DictionaryNotFoundError => e
        raise Errors::ResourceUnavailable, e.message
      end

      def resolve_language(text)
        result = LanguageResolver.new(
          flag_value: options[:language],
          default_language: Kotoshu.configuration.default_language
        ).resolve(text: text)

        $stderr.puts "# #{result.note}" if result.note
        result.language
      end

      def setup_source_options(languages)
        opts = {}
        if options[:aff] || options[:dic]
          raise Errors::UsageError, "--aff and --dic require exactly one language" unless languages.size == 1

          raise Errors::UsageError, "--aff and --dic must both be given" unless options[:aff] && options[:dic]

          opts[:aff] = options[:aff]
          opts[:dic] = options[:dic]
        elsif options[:from]
          opts[:from] = options[:from]
        end
        opts[:frequency] = options[:frequency] if options[:frequency]
        opts
      end

      def describe_setup_result(result)
        spelling = result.spelling || "skipped"
        frequency = result.frequency || "skipped"
        source = result.source
        puts "OK (spelling: #{spelling}, frequency: #{frequency}, source: #{source})"
      end

      def list_setup
        langs = Kotoshu.languages_setup
        if langs.empty?
          puts "No languages set up. Run `kotoshu setup LANG` to add one."
          return
        end

        puts "Set up languages:"
        langs.each { |lang| puts "  #{lang}" }
      end

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

      def format_as_json(result, source)
        require "json"

        output = result.as_json
        output["source"] = source
        JSON.pretty_generate(output)
      end

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

      def source_for_sarif(source)
        source == "<stdin>" ? "stdin" : source
      end

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
