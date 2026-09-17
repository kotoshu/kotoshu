# frozen_string_literal: true

module Kotoshu
  module Checks
    # Check #1: spelling (non-word detection + suggestions). Wraps the
    # existing Spellchecker#check flow byte-identically - the framework
    # types WHO found it (check_kind :spelling), the spellchecker owns
    # WHAT it found.
    class SpellingCheck < Base
      class << self
        def check_kind
          :spelling
        end

        def default_on?
          true
        end

        def available?(_language)
          true
        end
      end

      def run(text)
        result = context.fetch(:spellchecker).check(text)
        result.errors.map { |error| Finding.new(self.class.check_kind, error) }
      end
    end
  end
end
