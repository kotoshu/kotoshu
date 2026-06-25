# frozen_string_literal: true

require_relative 'rule_loader'
require_relative '../configuration'

module Kotoshu
  module Grammar
    # Engine for loading and executing grammar rules from YAML configuration.
    #
    # This implements configuration-driven design where all linguistic data
    # (rules, patterns, exceptions) is stored in YAML files, not hardcoded.
    #
    # @example Loading rules for English
    #   engine = RuleEngine.new(language: 'en')
    #   errors = engine.check(tokens)
    #
    class RuleEngine
      attr_reader :language, :rules

      # Create a new rule engine for a language.
      #
      # @param language [String] Language code (e.g., 'en', 'de', 'fr')
      # @param rules_path [String, nil] Optional custom path to grammar rules
      # @param dictionaries_path [String, nil] Optional custom path to dictionaries directory
      def initialize(language:, rules_path: nil, dictionaries_path: nil)
        @language = language
        @rules_path = rules_path || default_rules_path(dictionaries_path)
        @loader = RuleLoader.new(@rules_path)
        @rules = @loader.load_rules
      end

      # Check tokens against all loaded rules.
      #
      # @param tokens [Array<Hash>] Array of token hashes with :token, :pos_tag, :position keys
      # @return [Array<Hash>] Array of error hashes
      def check(tokens)
        errors = []
        @rules.each do |rule|
          rule_errors = rule.check(tokens)
          errors.concat(rule_errors)
        end
        errors
      end

      # Get list of rule IDs.
      #
      # @return [Array<String>] Array of rule IDs
      def rule_names
        @rules.map(&:id)
      end

      # Get a specific rule by ID.
      #
      # @param id [String] Rule ID
      # @return [Rule, nil] The rule if found, nil otherwise
      def get_rule(id)
        @rules.find { |r| r.id == id }
      end

      # Check if a rule exists.
      #
      # @param id [String] Rule ID
      # @return [Boolean] True if rule exists
      def rule_exists?(id)
        @rules.any? { |r| r.id == id }
      end

      private

      # Get default path to grammar rules for a language.
      #
      # @param dictionaries_path [String, nil] Optional custom dictionaries path
      # @return [String] Path to grammar rules directory
      def default_rules_path(dictionaries_path = nil)
        base_path = dictionaries_path || default_dictionaries_path
        File.join(base_path, @language, 'grammar')
      end

      # Get default dictionaries path.
      #
      # Checks in order:
      # 1. Environment variable KOTOSHU_DICTIONARIES_PATH
      # 2. Configuration.dictionaries_path
      # 3. Default: dictionaries/ adjacent to gem root
      #
      # @return [String] Path to dictionaries directory
      def default_dictionaries_path
        # Check for environment variable first
        if ENV['KOTOSHU_DICTIONARIES_PATH']
          return ENV['KOTOSHU_DICTIONARIES_PATH']
        end

        # Check for configuration setting
        config = Configuration.instance
        if config.respond_to?(:dictionaries_path) && config.dictionaries_path
          return config.dictionaries_path
        end

        # Default: dictionaries/ directory at project root
        # The kotoshu gem is at src/kotoshu/kotoshu/, so dictionaries is at src/kotoshu/dictionaries
        # From lib/kotoshu/grammar/:
        #   - grammar/ -> kotoshu/lib/kotoshu/ (1)
        #   - kotoshu/lib/kotoshu/ -> lib/kotoshu/ (2)
        #   - lib/kotoshu/ -> kotoshu/ (3)
        #   - kotoshu/ -> src/kotoshu/ (4)
        #   - Then add dictionaries/
        __dir__ + '/../../../../dictionaries'
      end
    end
  end
end
