# frozen_string_literal: true

require_relative "../../../suggestions/suggestion_set"

module Kotoshu
  module Models
    module Result
      # Result object for checking a single word.
      #
      # This is a value object that represents the result of checking
      # a single word for spelling errors, including any suggestions.
      #
      # @note This class is immutable and frozen on initialization.
      #
      # @example Creating a correct word result
      #   result = WordResult.new("hello", correct: true)
      #   result.correct?     # => true
      #   result.word         # => "hello"
      #   result.suggestions  # => SuggestionSet.empty
      #
      # @example Creating an incorrect word result with suggestions
      #   suggestions = SuggestionSet.from_words(%w[hello help], source: :test)
      #   result = WordResult.new("helo", correct: false, suggestions: suggestions)
      #   result.correct?     # => false
      #   result.has_suggestions?  # => true
      class WordResult
        # @return [String] The word that was checked
        attr_reader :word

        # @return [Boolean] Whether the word is spelled correctly
        attr_reader :correct

        # @return [Suggestions::SuggestionSet] Suggestions for correction
        attr_reader :suggestions

        # @return [Integer] The position of the word in the source text (optional)
        attr_reader :position

        # @return [Hash] Additional metadata
        attr_reader :metadata

        # Create a new WordResult.
        #
        # @param word [String] The word that was checked
        # @param correct [Boolean] Whether the word is correct
        # @param suggestions [Suggestions::SuggestionSet] Suggestions (optional)
        # @param position [Integer] Position in source text (optional)
        # @param metadata [Hash] Additional metadata (optional)
        def initialize(word, correct:, suggestions: nil, position: nil, metadata: {})
          word = "" if word.nil?

          @word = word.dup.freeze
          @correct = correct
          @suggestions = suggestions || Suggestions::SuggestionSet.empty
          @position = position
          @metadata = metadata.dup.freeze

          freeze
        end

        # Check if the word is correct.
        #
        # @return [Boolean] True if the word is spelled correctly
        def correct?
          @correct
        end

        # Check if the word is incorrect.
        #
        # @return [Boolean] True if the word is misspelled
        def incorrect?
          !@correct
        end

        # Check if there are suggestions.
        #
        # @return [Boolean] True if suggestions are available
        def has_suggestions?
          !@suggestions.empty?
        end

        # Get the number of suggestions.
        #
        # @return [Integer] Number of suggestions
        def suggestion_count
          @suggestions.size
        end

        # Get the top N suggestions.
        #
        # @param n [Integer] Number of suggestions to return
        # @return [Array<String>] Top N suggestion words
        def top_suggestions(n = 3)
          @suggestions.top(n).map(&:word)
        end

        # Get the first (best) suggestion.
        #
        # @return [String, nil] The best suggestion or nil
        def first_suggestion
          @suggestions.first&.word
        end

        # Convert to hash.
        #
        # @return [Hash] Hash representation
        def to_h
          {
            word: @word,
            correct: @correct,
            position: @position,
            suggestion_count: suggestion_count,
            suggestions: top_suggestions(10),
            metadata: @metadata
          }
        end

        # Convert to JSON-compatible hash.
        #
        # @return [Hash] JSON-compatible hash
        def as_json
          {
            "word" => @word,
            "correct" => @correct,
            "position" => @position,
            "suggestionCount" => suggestion_count,
            "suggestions" => top_suggestions(10),
            "metadata" => @metadata
          }
        end

        # Check equality based on word and correctness.
        #
        # @param other [WordResult] The other result
        # @return [Boolean] True if equal
        def ==(other)
          return false unless other.is_a?(WordResult)
          @word == other.word && @correct == other.correct
        end
        alias eql? ==

        # Hash based on word and correctness.
        #
        # @return [Integer] Hash code
        def hash
          [@word, @correct].hash
        end

        # String representation.
        #
        # @return [String] String representation
        def to_s
          if @correct
            @word
          elsif has_suggestions?
            "#{@word} (did you mean #{top_suggestions(3).join(', ')}?)"
          else
            "#{@word} (no suggestions)"
          end
        end
        alias inspect to_s

        # Create a correct word result.
        #
        # @param word [String] The word
        # @param position [Integer] Position in source (optional)
        # @return [WordResult] New result indicating correct spelling
        #
        # @example
        #   WordResult.correct("hello")
        def self.correct(word, position: nil)
          new(word, correct: true, position: position)
        end

        # Create an incorrect word result with suggestions.
        #
        # @param word [String] The misspelled word
        # @param suggestions [Suggestions::SuggestionSet, Array<String>] Suggestions
        # @param position [Integer] Position in source (optional)
        # @return [WordResult] New result indicating incorrect spelling
        #
        # @example With SuggestionSet
        #   suggestions = SuggestionSet.from_words(%w[hello help], source: :test)
        #   WordResult.incorrect("helo", suggestions: suggestions)
        #
        # @example With array of words
        #   WordResult.incorrect("helo", suggestions: %w[hello help])
        def self.incorrect(word, suggestions: nil, position: nil)
          suggestions_set = if suggestions.is_a?(Suggestions::SuggestionSet)
                             suggestions
                           elsif suggestions.is_a?(Array)
                             Suggestions::SuggestionSet.from_words(suggestions, source: :default)
                           else
                             Suggestions::SuggestionSet.empty
                           end

          new(word, correct: false, suggestions: suggestions_set, position: position)
        end
      end
    end
  end
end
