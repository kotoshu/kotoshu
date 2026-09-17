# frozen_string_literal: true

module Kotoshu
  module Checks
    # Composes the registered quality checks for a language. Data
    # driven: the server/CLI can enumerate or select checks without
    # code changes; composition degrades to check-absent when a
    # check's dependencies are missing, never engine-absent.
    class Registry
      # The registered checks, in composition order. Spelling is the
      # only default-on check (plan 148's byte-identical contract);
      # each further check ships opt-in until its own frozen-data
      # false-positive budget passes.
      DEFAULT_CHECKS = [SpellingCheck, GrammarCheck].freeze

      # @param checks [Array<Class>] the registered check classes
      # @param context [Hash] per-language dependencies injected into
      #   every check instance (e.g. +:spellchecker+, +:language+)
      def initialize(checks: DEFAULT_CHECKS, context: {})
        @checks = checks
        @context = context
        @language = context[:language]
      end

      # Default-on checks that are available for the language: the
      # plain `check` flow runs exactly these.
      def enabled
        @checks.select do |check|
          check.applies_to?(@language) && check.available?(@language) && check.default_on?
        end
      end

      # Every check available for the language, default-on or opt-in.
      def available
        @checks.select { |check| check.applies_to?(@language) && check.available?(@language) }
      end

      # Opt-in checks registered but not enabled by default.
      def opt_in
        available - enabled
      end

      # Run the given (default: enabled) checks over text.
      #
      # @return [Hash{Symbol => Array<Finding>}] findings keyed by
      #   check_kind
      def run(text, checks: enabled)
        checks.each_with_object({}) do |check, findings|
          findings[check.check_kind] = check.new(@context).run(text)
        end
      end

      # Run every available check, including opt-in ones.
      def run_all(text)
        run(text, checks: available)
      end
    end
  end
end
