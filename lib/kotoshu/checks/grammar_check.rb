# frozen_string_literal: true

module Kotoshu
  module Checks
    # Check #2: grammar (rule-based). Wraps the Grammar::RuleEngine -
    # infrastructure that already ships for en. OPT-IN by default:
    # its calibration (which rules fire, at what false-positive rate)
    # has not passed a frozen-data budget, so it never runs in the
    # plain check flow (plan 148's contract).
    class GrammarCheck < Base
      class << self
        def check_kind
          :grammar
        end

        def available?(language)
          # The rule engine currently ships rules for en; other
          # languages degrade to check-absent.
          language.to_s.downcase.start_with?("en")
        end
      end

      def run(text)
        engine = Grammar::RuleEngine.new(language: context.fetch(:language, "en"))
        tokens = tokenize(text)
        engine.check(tokens).map { |error| Finding.new(self.class.check_kind, error) }
      end

      private

      # The rule engine's token contract is {token:, pos_tag:, position:}
      # hashes. v1 tokenizes without part-of-speech tags: rules that
      # require a pos_tag simply do not fire (disclosed in the plan).
      def tokenize(text)
        tokens = []
        text.to_s.scan(/\S+/) do |match|
          tokens << { token: match, pos_tag: nil, position: Regexp.last_match.begin(0) }
        end
        tokens
      end
    end
  end
end
