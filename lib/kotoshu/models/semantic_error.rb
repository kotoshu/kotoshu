# frozen_string_literal: true

require_relative 'context'
require_relative 'suggestion'

module Kotoshu
  module Models
    # Unified semantic error (NO artificial spelling/grammar split!).
    #
    # Represents ANY kind of language error detected through semantic analysis.
    # Uses semantic categories instead of traditional "spelling" vs "grammar" labels.
    #
    # Error types (semantic categories):
    # - :word_choice - Wrong word for context (e.g., "desert" vs "dessert")
    # - :verb_agreement - Subject-verb mismatch (e.g., "they is" → "they are")
    # - :tense - Temporal inconsistency (e.g., "Yesterday I will go")
    # - :orthographic - Actual typo/misspelling (e.g., "wrold" → "world")
    # - :preposition - Wrong preposition (e.g., "bored of" → "bored with")
    # - :article - Wrong article (e.g., "a apple" → "an apple")
    # - :morphology - Wrong word form (e.g., "goed" → "went")
    # - :capitalization - Capitalization error (e.g., "i am" → "I am")
    # - :punctuation - Punctuation error (e.g., "its" vs "it's")
    # - :style - Style/usage suggestion
    #
    # @example Creating a semantic error
    #   error = SemanticError.new(
    #     id: "error_1",
    #     location: Location.new(line: 5, column: 12),
    #     original: "desert",
    #     suggestions: [Suggestion.new("dessert", confidence: 0.92)],
    #     error_type: :word_choice,
    #     confidence: 0.92,
    #     context: context
    #   )
    class SemanticError
      # Error type definitions with display names
      ERROR_TYPES = {
        word_choice: 'Word Choice',
        verb_agreement: 'Verb Agreement',
        tense: 'Tense',
        orthographic: 'Spelling',
        preposition: 'Preposition',
        article: 'Article',
        morphology: 'Word Form',
        capitalization: 'Capitalization',
        punctuation: 'Punctuation',
        style: 'Style'
      }.freeze

      attr_reader :id, :location, :original, :suggestions, :error_type, :confidence, :context

      # Create a new semantic error.
      #
      # @param id [String, Symbol] Unique identifier for this error
      # @param location [Object] Location of error in document (line/column holder)
      # @param original [String] The original (incorrect) word/text
      # @param suggestions [Array<Suggestion>] Suggested corrections
      # @param error_type [Symbol] Error type (must be in ERROR_TYPES)
      # @param confidence [Float] Confidence score (0.0 to 1.0)
      # @param context [Context] Context around the error
      # @raise [ArgumentError] if error_type is invalid
      def initialize(id:, location:, original:, suggestions:, error_type:, confidence:, context:)
        raise ArgumentError, "Invalid error type: #{error_type}" unless ERROR_TYPES.key?(error_type)
        raise ArgumentError, "Confidence must be 0-1" unless confidence.between?(0.0, 1.0)
        raise ArgumentError, "Suggestions cannot be empty" if suggestions.nil? || suggestions.empty?

        @id = id.to_s
        @location = location
        @original = original
        @suggestions = suggestions.sort_by(&:confidence).reverse.freeze
        @error_type = error_type
        @confidence = confidence
        @context = context

        freeze
      end

      # Get user-friendly display type name.
      #
      # @return [String] Display type name
      def display_type
        ERROR_TYPES[@error_type] || @error_type.to_s.capitalize
      end

      # Check if this is a high-confidence error.
      #
      # @return [Boolean] True if confidence > 0.8
      def high_confidence?
        @confidence > 0.8
      end

      # Get confidence level category.
      #
      # @return [Symbol] :high, :medium, or :low
      def confidence_level
        return :high if @confidence > 0.8
        return :medium if @confidence > 0.5

        :low
      end

      # Get the recommended (top) suggestion.
      #
      # @return [Suggestion] The highest-confidence suggestion
      def recommended_suggestion
        @suggestions.first
      end

      # Check if this error equals another.
      #
      # @param other [Object] Another object
      # @return [Boolean] True if IDs match
      def ==(other)
        return false unless other.is_a?(SemanticError)

        @id == other.id
      end
      alias_method :eql?, :==

      # Hash code for hash table usage.
      #
      # @return [Integer] Hash code
      def hash
        @id.hash
      end

      # Comparison for sorting (by location, then confidence).
      #
      # Errors are sorted by:
      # 1. Document location (line number, then column)
      # 2. Confidence (highest first)
      #
      # @param other [SemanticError] Another error
      # @return [Integer] Comparison result (-1, 0, 1)
      def <=>(other)
        return 0 unless other.is_a?(SemanticError)

        # First by location (line, then column)
        loc_cmp = @location <=> other.location
        return loc_cmp unless loc_cmp.zero?

        # Then by confidence (highest first)
        other.confidence <=> @confidence
      end

      # String representation.
      #
      # @return [String] Human-readable representation
      def to_s
        "#{@location}: '#{@original}' → #{recommended_suggestion.word} [#{(@confidence * 100).to_i}%]"
      end
      alias_method :inspect, :to_s

      # Create an abbreviated display for lists.
      #
      # @param max_length [Integer] Maximum line length
      # @return [String] Abbreviated representation
      def abbreviated(max_length: 80)
        orig_display = "'#{@original}'"
        sugg_display = "'#{recommended_suggestion.word}'"

        "#{@location}: #{orig_display} → #{sugg_display} [#{(@confidence * 100).to_i}%]"
      end
    end
  end
end
