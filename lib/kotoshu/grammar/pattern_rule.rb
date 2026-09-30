# frozen_string_literal: true

module Kotoshu
  module Grammar
    # A rule defined in the flat YAML pattern DSL (TODO.grammar/1).
    #
    # This is the data-driven rule format shared by the hand-authored
    # rules (lib/kotoshu/grammar/rules/{lang}/*.yml) and converted
    # external rules (LanguageTool loader). The format is pure data —
    # the same YAML loads in the Rust and TS engines.
    #
    #   - id: EN_SV_AGREEMENT_3SG
    #     category: agreement
    #     language: en
    #     matcher: pos_sequence
    #     pattern:
    #       - { pos: PRON_3SG }
    #       - { pos: VERB_BASE }
    #     message: "..."
    #     suggestions:
    #       - template: "{{1}}s"
    #     unless_pattern:            # antipatterns (optional)
    #       - - { word: [can, may] }
    #     examples:
    #       - bad: "He go to school"
    #         good: "He goes to school"
    class PatternRule
      attr_reader :id, :name, :category, :language, :matcher, :pattern,
                  :message, :suggestions, :unless_pattern, :examples,
                  :source, :license, :default

      # @param config [Hash] rule hash from YAML or a converter
      def self.from_yaml(config)
        new(
          id: config["id"], name: config["name"], category: config["category"],
          language: config["language"], matcher: config["matcher"] || "pos_sequence",
          pattern: config["pattern"], message: config["message"],
          suggestions: config["suggestions"] || [], unless_pattern: config["unless_pattern"],
          examples: config["examples"] || [], source: config["source"],
          license: config["license"], default: config["default"]
        )
      end

      def initialize(id:, pattern:, message:, category:, language: "en",
                     name: nil, matcher: "pos_sequence", suggestions: [],
                     unless_pattern: nil, examples: [], source: nil,
                     license: nil, default: nil)
        @id = id
        @name = name
        @category = category
        @language = language
        @matcher = matcher
        @pattern = pattern
        @message = message
        @suggestions = suggestions
        @unless_pattern = unless_pattern
        @examples = examples
        @source = source
        @license = license
        @default = default
      end

      def pattern_data
        @pattern
      end

      def single_match?
        false
      end

      # Interpolate suggestion templates against a matched window.
      # Suggestions are either {"template" => str} or plain strings.
      #
      # @param window [Array<Hash>] matched token hashes
      # @return [Array<String>]
      def suggestions_for(window)
        @suggestions.filter_map do |s|
          text = s.is_a?(Hash) ? s["template"] : s
          next nil if text.nil? || text.empty?

          text.gsub(/\{\{(\d+)\}\}/) { window[Regexp.last_match(1).to_i]&.fetch(:word, "").to_s }
        end
      end

      # Check tokens: run the matcher, suppress antipattern hits.
      #
      # @param tokens [Array<Hash>] token hashes (tagged or raw words)
      # @return [Array<Hash>] error hashes
      def check(tokens)
        errors = PatternMatchers::PosSequenceMatcher.new(nil).match(tokens, self)
        return errors if errors.empty? || @unless_pattern.nil?

        errors.reject { |_error| antipattern_hits?(tokens) }
      end

      def enabled?
        @default != "off"
      end

      private

      def antipattern_hits?(tokens)
        @unless_pattern.any? do |ap_pattern|
          fake = self.class.new(id: "#{@id}_ap", pattern: ap_pattern, message: "", category: @category)
          fake.check(tokens).any?
        end
      end
    end
  end
end
