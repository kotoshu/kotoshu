# frozen_string_literal: true

require "yaml"

module Kotoshu
  module Grammar
    # Loads grammar rules from YAML configuration files.
    #
    # Two formats load from the rules directory:
    #
    # - rules.yaml — the envelope format ({"rules" => [...]}) consumed
    #   by the legacy Rule (conditions-based matchers)
    # - *.yml — flat arrays of pattern-DSL rules (TODO.grammar/1),
    #   loaded as PatternRule; this is the format of the hand-authored
    #   rules and of LanguageTool-converted packs
    class RuleLoader
      def initialize(rules_path)
        @rules_path = rules_path
      end

      # Load every rule from the rules directory.
      #
      # @return [Array<Rule, PatternRule>] rule instances
      def load_rules
        load_envelope_rules + load_pattern_rules
      end

      private

      def load_envelope_rules
        rules_file = File.join(@rules_path, "rules.yaml")
        return [] unless File.exist?(rules_file)

        config = YAML.load_file(rules_file)
        return [] unless config && config["rules"]

        config["rules"].map { |rule_config| Rule.from_yaml(rule_config) }
      end

      def load_pattern_rules
        Dir.glob(File.join(@rules_path, "*.yml")).each_with_object([]) do |file, rules|
          entries = YAML.load_file(file)
          next unless entries.is_a?(Array)

          entries.each do |entry|
            rules << PatternRule.from_yaml(entry) if entry.is_a?(Hash) && entry["pattern"]
          end
        end
      end
    end
  end
end
