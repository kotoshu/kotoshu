# frozen_string_literal: true

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
    # Raised by {SemanticError.initialize} when +suggestions+ is empty
    # and +allow_empty_suggestions:+ is false. The analyzer rescues
    # this so words with no close matches are silently dropped rather
    # than producing noise.
    class EmptySuggestionsError < ArgumentError
    end

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

      attr_reader :id, :source_range, :location, :original, :suggestions,
                  :error_type, :confidence, :context

      # Create a new semantic error.
      #
      # @param id [String, Symbol] Unique identifier for this error
      # @param source_range [Kotoshu::Documents::SourceRange, nil]
      #   Where the offending text lives in the original markup-bearing
      #   source. Carried verbatim so editors/plugins can highlight the
      #   actual range the user wrote.
      # @param location [Object, nil] Legacy location holder (line/column
      #   object). Kept for backward compat with old callers; new code
      #   should pass +source_range+ instead.
      # @param original [String] The original (incorrect) word/text
      # @param suggestions [Array<Suggestion>] Suggested corrections
      # @param error_type [Symbol] Error type (must be in ERROR_TYPES)
      # @param confidence [Float] Confidence score (0.0 to 1.0)
      # @param context [Context, nil] Context around the error
      # @param allow_empty_suggestions [Boolean] When false (default),
      #   raises {EmptySuggestionsError} instead of building an error
      #   with zero suggestions.
      # @raise [ArgumentError] if error_type is invalid
      # @raise [ArgumentError] if confidence is outside [0, 1]
      # @raise [EmptySuggestionsError] if suggestions is empty and
      #   allow_empty_suggestions is false
      def initialize(id:, original:, suggestions:, error_type:, confidence:, source_range: nil, location: nil, context: nil,
                     allow_empty_suggestions: false)
        raise ArgumentError, "Invalid error type: #{error_type}" unless ERROR_TYPES.key?(error_type)
        raise ArgumentError, "Confidence must be 0-1" unless confidence.between?(0.0, 1.0)

        if (suggestions.nil? || suggestions.empty?) && !allow_empty_suggestions
          raise EmptySuggestionsError,
                "Suggestions cannot be empty (pass allow_empty_suggestions: true to override)"
        end

        @id = id.to_s
        @source_range = source_range
        @location = location || source_range&.start
        @original = original
        @suggestions = (suggestions || []).sort_by(&:confidence).reverse.freeze
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

      # Comparison for sorting (by source position, then confidence).
      #
      # Errors are sorted by:
      # 1. Source position (source_range.start when present; falls back
      #    to legacy +location+ when source_range is nil)
      # 2. Confidence (highest first)
      #
      # @param other [SemanticError] Another error
      # @return [Integer] Comparison result (-1, 0, 1)
      def <=>(other)
        return 0 unless other.is_a?(SemanticError)

        a_pos = sort_position
        b_pos = other.sort_position
        pos_cmp = a_pos <=> b_pos
        return pos_cmp unless pos_cmp.zero?

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

      protected

      # The position used for sorting. Prefers source_range.start
      # (the new contract); falls back to legacy +location+ for
      # errors built without a document.
      #
      # Visible to other SemanticError instances (protected, not private)
      # because <=> reads `other.sort_position` when comparing.
      def sort_position
        return @source_range.start if @source_range

        @location
      end
    end
  end
end
