# frozen_string_literal: true

module Kotoshu
  module Grammar
    # Base class for grammar rules.
    #
    # All grammar rules inherit from this class and implement
    # the #check method to validate tokens.
    class Rule
      attr_reader :id, :name, :category, :severity, :description,
                  :exceptions, :message, :suggestion

      def initialize(id:, name:, category:, severity:, description:,
                     patterns:, exceptions: {}, message:, suggestion:)
        @id = id
        @name = name
        @category = category
        @severity = severity
        @description = description
        @patterns = patterns
        @exceptions = exceptions
        @message = message
        @suggestion = suggestion
      end

      # Factory method to create Rule from YAML configuration.
      #
      # @param config [Hash] YAML configuration hash
      # @return [Rule] A new rule instance
      def self.from_yaml(config)
        new(
          id: config['id'],
          name: config['name'],
          category: config['category'],
          severity: config['severity'],
          description: config['description'],
          patterns: config['patterns'],
          exceptions: config['exceptions'] || {},
          message: config['message'],
          suggestion: config['suggestion']
        )
      end

      # Check tokens against this rule.
      #
      # @param tokens [Array<Hash>] Array of token hashes
      # @return [Array<Hash>] Array of error hashes
      def check(tokens)
        errors = []
        @patterns.each do |pattern|
          pattern_errors = check_pattern(tokens, pattern)
          errors.concat(pattern_errors)
        end
        errors
      end

      private

      # Check a single pattern against tokens.
      #
      # @param tokens [Array<Hash>] Array of token hashes
      # @param pattern [Hash] Pattern configuration hash
      # @return [Array<Hash>] Array of error hashes
      def check_pattern(tokens, pattern)
        matcher = create_matcher(pattern)
        matcher.match(tokens, self)
      end

      # Create appropriate pattern matcher based on pattern type.
      #
      # @param pattern [Hash] Pattern configuration hash
      # @return [PatternMatchers::BaseMatcher] A pattern matcher instance
      def create_matcher(pattern)
        conditions = pattern['conditions'] || []
        return PatternMatchers::BaseMatcher.new(pattern) if conditions.empty?

        condition_types = conditions.map { |c| c['type'] }

        if condition_types.include?('vowel_check')
          require_relative 'pattern_matchers/vowel_sound_matcher'
          PatternMatchers::VowelSoundMatcher.new(pattern, exceptions)
        elsif condition_types.include?('context_check')
          require_relative 'pattern_matchers/possessive_context_matcher'
          PatternMatchers::PossessiveContextMatcher.new(pattern, exceptions)
        elsif condition_types.include?('distance_check')
          require_relative 'pattern_matchers/double_negative_matcher'
          PatternMatchers::DoubleNegativeMatcher.new(pattern, exceptions)
        else
          require_relative 'pattern_matchers/base_matcher'
          PatternMatchers::BaseMatcher.new(pattern)
        end
      end
    end
  end
end
