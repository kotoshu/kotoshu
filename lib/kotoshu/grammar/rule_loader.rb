# frozen_string_literal: true

require 'yaml'
require_relative 'rule'

module Kotoshu
  module Grammar
    # Loads grammar rules from YAML configuration files.
    #
    # This class reads rule definitions from YAML files in the
    # dictionaries/{language}/grammar/ directory.
    class RuleLoader
      def initialize(rules_path)
        @rules_path = rules_path
      end

      # Load all rules from the rules.yaml file.
      #
      # @return [Array<Rule>] Array of rule instances
      def load_rules
        rules_file = File.join(@rules_path, 'rules.yaml')
        return [] unless File.exist?(rules_file)

        config = YAML.load_file(rules_file)
        return [] unless config && config['rules']

        config['rules'].map { |rule_config| Rule.from_yaml(rule_config) }
      end
    end
  end
end
