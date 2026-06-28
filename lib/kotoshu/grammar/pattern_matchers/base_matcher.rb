# frozen_string_literal: true

module Kotoshu
  module Grammar
    module PatternMatchers
      # Base class for pattern matchers.
      #
      # Pattern matchers check token sequences against specific patterns
      # defined in YAML configuration.
      class BaseMatcher
        def initialize(pattern, exceptions = {})
          @pattern = pattern
          @exceptions = exceptions
        end

        # Match tokens against the pattern.
        #
        # @param tokens [Array<Hash>] Array of token hashes
        # @param rule [Rule] The rule being checked
        # @return [Array<Hash>] Array of error hashes
        def match(_tokens, _rule)
          []
        end

        protected

        # Extract target tokens from context specification.
        #
        # @param tokens [Array<Hash>] Array of token hashes
        # @param context_spec [Hash] Context specification from pattern
        # @return [Array<Hash>] Array of matching tokens with their indices
        def extract_tokens_from_context(tokens, context_spec)
          result = []
          context_spec.each do |spec|
            if spec['target_token']
              tokens.each_with_index do |token, idx|
                if token[:token]&.downcase == spec['target_token']
                  result << { token: token, index: idx }
                end
              end
            end
          end
          result
        end
      end
    end
  end
end
