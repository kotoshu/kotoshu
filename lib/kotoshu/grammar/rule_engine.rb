# frozen_string_literal: true

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

      # Resolve the directory holding <language>/grammar/rules.yaml.
      #
      # Priority:
      #   1. Explicit `dictionaries_path:` constructor arg
      #   2. KOTOSHU_DICTIONARIES_PATH env var
      #   3. Configuration#dictionaries_path (when set)
      #   4. Gem-bundled data/grammar (always available)
      #
      # @param dictionaries_path [String, nil] Caller-supplied override
      # @return [String] Path joined with language + "grammar"
      def default_rules_path(dictionaries_path = nil)
        base = dictionaries_path || resolve_dictionaries_base
        File.join(base, @language, "grammar")
      end

      def resolve_dictionaries_base
        ENV["KOTOSHU_DICTIONARIES_PATH"] ||
          Configuration.instance.dictionaries_path ||
          gem_bundled_data_path
      end

      # Path to the gem's own data/ directory. Always available after
      # `gem install kotoshu`, so grammar rules work without external
      # dependencies or sibling repos checked out.
      def gem_bundled_data_path
        File.expand_path("../../../data", __dir__)
      end
    end
  end
end
