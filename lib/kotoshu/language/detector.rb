# frozen_string_literal: true

module Kotoshu
  module Language
    # Language detection based on character sets and patterns.
    #
    # Uses Unicode character ranges to identify probable language.
    # Provides confidence scoring for multiple matches.
    #
    # @example Detect language
    #   Language::Detector.detect("Hello world")  # => "en"
    class Detector
      # Character set ranges for language detection
      CHARACTER_SETS = {
        cyrillic: /\p{Cyrillic}/,
        hiragana: /[\u3040-\u309F]/,
        katakana: /[\u30A0-\u30FF]/,
        cjk: /[\u4E00-\u9FFF]/,
        hangul: /[\uAC00-\uD7AF]/,
        latin: /[a-zA-Zà-ÿ]/
      }.freeze

      # Language-specific patterns
      LANGUAGE_PATTERNS = {
        # Russian: Cyrillic
        russian: {
          pattern: /\p{Cyrillic}[а-яА-ЯёЁ]/,
          min_ratio: 0.3,
          scripts: [:cyrillic]
        },

        # Japanese: Mixed script (Hiragana + Katakana + Kanji)
        japanese: {
          pattern: /[\u3040-\u309F]|[\u30A0-\u30FF]|[\u4E00-\u9FFF]/,
          min_ratio: 0.2,
          scripts: %i[hiragana katakana cjk],
          must_have: [:hiragana] # Only require hiragana, not both
        },

        # Portuguese: Latin with specific accents
        portuguese: {
          pattern: /[ãõáàâéêíóôúç]/i,
          min_ratio: 0.05,
          scripts: [:latin]
        },

        # French: Latin with specific accents (NOT German umlauts)
        french: {
          pattern: /[éèêëàâùûüîïôç]/i, # Removed ä, ö (not French)
          min_ratio: 0.02, # Lower threshold
          scripts: [:latin],
          priority: 1 # Higher priority than English
        },

        # Spanish: Latin with inverted punctuation
        spanish: {
          pattern: /[áéíóúüñ¿¡]/i,
          min_ratio: 0.02, # Lower threshold
          scripts: [:latin],
          priority: 1
        },

        # German: Latin with umlauts and eszett
        german: {
          pattern: /[äöüßÄÖÜ]/, # Explicitly include uppercase
          min_ratio: 0.02, # Lower threshold
          scripts: [:latin],
          priority: 1
        },

        # English: Latin with minimal accents
        english: {
          pattern: /[a-zA-Z]/,
          min_ratio: 0.3,
          scripts: [:latin],
          max_accent_ratio: 0.02
        }
      }.freeze

      # Language code mapping
      CODE_MAPPING = {
        russian: "ru",
        japanese: "ja",
        portuguese: "pt",
        french: "fr",
        spanish: "es",
        german: "de",
        english: "en"
      }.freeze

      class << self
        # Detect language from text.
        #
        # Returns the most probable language code based on character analysis.
        #
        # @param text [String] Text to analyze
        # @return [String, nil] Detected language code or nil if uncertain
        def detect(text)
          return nil if text.nil? || text.strip.empty?

          scores = analyze_languages(text)
          return nil if scores.empty?

          # Sort by score, then by priority (higher priority first)
          result = scores.max_by do |code, score|
            config = LANGUAGE_PATTERNS.find { |k, _v| CODE_MAPPING[k] == code }
            priority = config&.last&.dig(:priority) || 0
            [score, priority]
          end

          result&.first
        end

        # Detect with confidence score.
        #
        # @param text [String] Text to analyze
        # @return [Array<String, Float>] Language code and confidence (0-1)
        def detect_with_confidence(text)
          return [nil, 0.0] if text.nil? || text.strip.empty?

          scores = analyze_languages(text)
          return [nil, 0.0] if scores.empty?

          top_language, top_score = scores.max_by { |_, score| score }
          confidence = normalize_confidence(top_score, scores.values)

          [top_language, confidence]
        end

        # Get multiple language candidates.
        #
        # @param text [String] Text to analyze
        # @param limit [Integer] Maximum candidates to return
        # @return [Array<Array<String, Float>>] Array of [code, confidence] pairs
        def detect_candidates(text, limit: 3)
          return [] if text.nil? || text.strip.empty?

          scores = analyze_languages(text)
          return [] if scores.empty?

          total_score = scores.values.sum.to_f
          scores
            .sort_by { |_, score| -score }
            .first(limit)
            .map { |code, score| [code, score / total_score] }
        end

        private

        # Analyze text and score each language.
        #
        # @param text [String] Text to analyze
        # @return [Hash] Hash mapping language codes to scores
        def analyze_languages(text)
          text_length = text.length.to_f
          return {} if text_length.zero?

          scores = {}

          LANGUAGE_PATTERNS.each do |language, config|
            score = score_language(text, language, config, text_length)
            scores[CODE_MAPPING[language]] = score if score > 0
          end

          scores
        end

        # Score a specific language against text.
        #
        # @param text [String] Text to analyze
        # @param language [Symbol] Language key
        # @param config [Hash] Language configuration
        # @param text_length [Float] Length of text
        # @return [Float] Score (0-1)
        def score_language(text, language, config, text_length)
          # Check required scripts
          if config[:must_have] && !config[:must_have].all? do |script|
            text.match?(CHARACTER_SETS[script])
          end
            return 0
          end

          # Check forbidden scripts
          if config[:must_not_have] && config[:must_not_have].any? do |script|
            text.match?(CHARACTER_SETS[script])
          end
            return 0
          end

          # Count matching characters
          matches = text.scan(config[:pattern]).length
          ratio = matches / text_length

          # Check minimum ratio
          return 0 if ratio < config[:min_ratio]

          # Check maximum accent ratio (for English)
          if config[:max_accent_ratio]
            accent_chars = text.scan(/[à-ÿ]/).length
            accent_ratio = accent_chars / text_length
            return 0 if accent_ratio > config[:max_accent_ratio]
          end

          # Bonus for having required scripts
          score = ratio
          if config[:scripts]
            script_bonus = config[:scripts].count do |script|
              text.match?(CHARACTER_SETS[script])
            end
            score *= (1 + (script_bonus * 0.1))
          end

          # Extra bonus for non-Latin specific characters (accents, umlauts, etc.)
          # This helps distinguish languages with special characters from plain English
          if language != :english && matches > 0
            # Calculate what portion of the text is the special characters
            special_char_ratio = matches / text_length
            # Give bonus proportional to special character presence
            score *= (1 + special_char_ratio)
          end

          [score, 1.0].min
        end

        # Normalize confidence score.
        #
        # @param top_score [Float] Highest score
        # @param all_scores [Array<Float>] All scores
        # @return [Float] Normalized confidence (0-1)
        def normalize_confidence(top_score, all_scores)
          return 0.0 if top_score.zero?

          second_best = all_scores.sort.reverse[1] || 0
          return 1.0 if second_best.zero?

          ratio = top_score / (top_score + second_best)
          ((ratio * 0.8) + 0.2).clamp(0.0, 1.0) # Minimum confidence 0.2
        end
      end
    end
  end
end
