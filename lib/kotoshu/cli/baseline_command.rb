# frozen_string_literal: true

require "thor"

module Kotoshu
  module Cli
    # `kotoshu baseline` — CI baseline management (plan 82, Track B),
    # wired as a subcommand in cli.rb.
    class BaselineCommand < Thor
      namespace :baseline

      class_option :language,
                   type: :string,
                   default: "auto",
                   desc: "Language code (auto, de, en, es, fr, pt, ru)",
                   aliases: ["-l"]

      desc "init FILE [FILE ...]", "Write a baseline of the current findings"
      long_desc <<~DESC
        Checks each FILE (directories and globs expand exactly like
        `kotoshu check` directory mode; inline ignore directives apply)
        and writes the canonical baseline JSON: one entry per (file,
        word) with the misspelling count, stable across reformatting.
        The personal dictionary is NOT consulted - baselines freeze what
        every machine would see, and CI has no personal dictionary.
        Suggestions are skipped: a baseline only needs positions.

        The baseline only covers real errors present right now; new
        errors still fail `kotoshu check --baseline`.

        Examples:

          kotoshu baseline init . # directories and globs expand like check
          kotoshu baseline init src/*.txt --output .kotoshu-baseline.json
      DESC
      method_option :output,
                    type: :string,
                    default: Kotoshu::Baseline::Store::DEFAULT_FILENAME,
                    desc: "Baseline file to write (default: #{Kotoshu::Baseline::Store::DEFAULT_FILENAME})"
      def init(*targets)
        if targets.empty?
          raise Errors::UsageError,
                "Give at least one file: kotoshu baseline init FILE [FILE ...]"
        end

        missing = targets.reject do |target|
          File.directory?(target) || File.file?(target) || !Dir[target].empty?
        end
        unless missing.empty?
          raise Errors::UsageError, "File not found: #{missing.join(' ')}"
        end

        files = targets.flat_map { |t| expand_target(t) }
        if files.empty?
          raise Errors::UsageError,
                "No text files found (known extensions: " \
                "#{Cli::DirectoryWalker::TEXT_EXTENSIONS.join(' ')})"
        end

        checks = {}
        files.sort.each do |file|
          text = File.read(file, encoding: Kotoshu.configuration.encoding).scrub
          checks[file] = [run_check(text), text]
        end

        store = Kotoshu::Baseline::Store.from_checks(checks)
        store.save(options[:output])
        total = store.entries.sum(&:count)
        noun = store.entries.size == 1 ? "entry" : "entries"
        error_noun = total == 1 ? "error" : "errors"
        puts "Wrote #{options[:output]}: #{store.entries.size} #{noun} " \
             "(#{total} #{error_noun} baselined)"
      end

      no_commands do
        # Directories expand through the same walker directory mode uses
        # (gitignore-aware, known text extensions); globs expand via
        # Dir; plain files pass through unchanged.
        def expand_target(target)
          if File.directory?(target)
            DirectoryWalker.new.files(target)
          elsif File.file?(target)
            [target]
          else
            Dir[target].select { |f| File.file?(f) }
          end
        end

        # Baselines must be machine-independent: the personal dictionary
        # of whichever machine runs init must never leak into the frozen
        # set, or CI (which has none) flags words the baseline never
        # recorded. Disabled for the whole init run.
        def run_check(text)
          previous = Kotoshu.configuration.personal_dictionary
          Kotoshu.configuration.personal_dictionary = false
          Kotoshu.reset_spellchecker
          language = resolve_language(text)
          Kotoshu.spellchecker_for(language).check(text, suggestions: false)
        rescue Kotoshu::ResourceNotSetupError => e
          raise Errors::ResourceUnavailable, e.message
        rescue Kotoshu::DictionaryNotFoundError => e
          raise Errors::ResourceUnavailable, e.message
        ensure
          Kotoshu.configuration.personal_dictionary = previous
          Kotoshu.reset_spellchecker
        end

        def resolve_language(text)
          result = LanguageResolver.new(
            flag_value: options[:language],
            default_language: Kotoshu.configuration.default_language
          ).resolve(text: text)
          warn "# #{result.note}" if result.note
          result.language
        end
      end
    end
  end
end
