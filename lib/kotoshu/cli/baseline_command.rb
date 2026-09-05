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
        Checks each FILE with the normal check pipeline (inline ignore
        directives apply) and writes the canonical baseline JSON: one
        entry per (file, word) with the misspelling count, stable across
        reformatting.

        The baseline only covers real errors present right now; new
        errors still fail `kotoshu check --baseline`.

        Examples:

          kotoshu baseline init README.md docs/*.adoc
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

        checks = {}
        targets.each do |target|
          raise Errors::UsageError, "File not found: #{target}" unless File.exist?(target)

          text = File.read(target, encoding: Kotoshu.configuration.encoding)
          checks[target] = [run_check(text), text]
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
        def run_check(text)
          language = resolve_language(text)
          Kotoshu.spellchecker_for(language).check(text)
        rescue Kotoshu::ResourceNotSetupError => e
          raise Errors::ResourceUnavailable, e.message
        rescue Kotoshu::DictionaryNotFoundError => e
          raise Errors::ResourceUnavailable, e.message
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
