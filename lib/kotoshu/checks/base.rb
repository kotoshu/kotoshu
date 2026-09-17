# frozen_string_literal: true

module Kotoshu
  module Checks
    # The one contract every quality check implements (plan 148).
    #
    # Class-level methods are the REGISTRATION surface (what the
    # registry and the API surfaces need without instantiating);
    # instances carry the check's per-language dependencies and do the
    # work. A check whose dependencies are missing reports itself
    # unavailable and degrades to check-absent - never engine-absent
    # (the typo layer's pattern, generalized).
    class Base
      class << self
        # The finding kind this check emits (e.g. :spelling, :grammar).
        def check_kind
          raise NotImplementedError, "#{name} must declare check_kind"
        end

        # Whether the check applies to a language code (BCP-47).
        def applies_to?(_language)
          true
        end

        # Whether the check's model/dictionary dependencies are
        # satisfiable for a language. Unavailable checks are skipped
        # by the registry, not errors.
        def available?(_language)
          true
        end

        # Default-on checks run in the plain `check` flow. Checks
        # whose calibration has not passed their frozen-data false
        # positive budget ship opt-in only (plan 148's contract).
        def default_on?
          false
        end
      end

      # @param context [Hash] per-language dependencies the registry
      #   injects (e.g. +:spellchecker+, +:language+)
      def initialize(context = {})
        @context = context
      end

      # @return [Array<Checks::Finding>] findings typed by check_kind
      def run(_text)
        raise NotImplementedError, "#{self.class.name} must implement run"
      end

      private

      attr_reader :context
    end
  end
end
