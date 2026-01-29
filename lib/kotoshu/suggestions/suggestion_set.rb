# frozen_string_literal: true

require_relative "suggestion"

module Kotoshu
  module Suggestions
    # A collection of suggestions with rich query methods.
    # This is MORE OOP than Spylls which returns plain iterators of strings.
    class SuggestionSet
      include Enumerable

      attr_reader :suggestions, :max_size

      # @param suggestions [Array<Suggestion>] Initial suggestions
      # @param max_size [Integer] Maximum number of suggestions to keep
      def initialize(suggestions = [], max_size: 10)
        @suggestions = suggestions
        @max_size = max_size
        sort_and_limit!
      end

      # Add a suggestion to the set.
      #
      # @param suggestion [Suggestion] The suggestion to add
      # @return [SuggestionSet] Self for chaining
      def add(suggestion)
        @suggestions << suggestion
        sort_and_limit!
        self
      end
      alias << add

      # Add multiple suggestions.
      #
      # @param new_suggestions [Array<Suggestion>] Suggestions to add
      # @return [SuggestionSet] Self for chaining
      def concat(new_suggestions)
        @suggestions.concat(new_suggestions)
        sort_and_limit!
        self
      end

      # Merge another suggestion set into this one.
      #
      # @param other [SuggestionSet] The other set
      # @return [SuggestionSet] Self for chaining
      def merge!(other)
        concat(other.suggestions)
        self
      end

      # Get suggestions by source.
      #
      # @param source [String, Symbol] The source to filter by
      # @return [SuggestionSet] New set with filtered suggestions
      def from_source(source)
        SuggestionSet.new(@suggestions.select { |s| s.from_source?(source) }, max_size: @max_size)
      end

      # Get high-confidence suggestions.
      #
      # @return [SuggestionSet] New set with high-confidence suggestions
      def high_confidence
        SuggestionSet.new(@suggestions.select(&:high_confidence?), max_size: @max_size)
      end

      # Get low-confidence suggestions.
      #
      # @return [SuggestionSet] New set with low-confidence suggestions
      def low_confidence
        SuggestionSet.new(@suggestions.select(&:low_confidence?), max_size: @max_size)
      end

      # Get suggestions within a distance range.
      #
      # @param min_distance [Integer] Minimum distance
      # @param max_distance [Integer] Maximum distance
      # @return [SuggestionSet] New set with filtered suggestions
      def within_distance(min_distance: 0, max_distance: 2)
        filtered = @suggestions.select do |s|
          s.distance >= min_distance && s.distance <= max_distance
        end
        SuggestionSet.new(filtered, max_size: @max_size)
      end

      # Check if set contains a specific word.
      #
      # @param word [String] The word to check
      # @return [Boolean] True if word is in suggestions
      def include?(word)
        @suggestions.any? { |s| s.same_word?(word) }
      end
      alias has_word? include?

      # Find a suggestion by word.
      #
      # @param word [String] The word to find
      # @return [Suggestion, nil] The suggestion or nil
      def find_word(word)
        @suggestions.find { |s| s.same_word?(word) }
      end

      # Get the top N suggestions.
      #
      # @param n [Integer] Number of suggestions to get
      # @return [Array<Suggestion>] Top N suggestions
      def top(n)
        @suggestions.first(n)
      end

      # Get the first (best) suggestion.
      #
      # @return [Suggestion, nil] The best suggestion or nil
      def first
        @suggestions.first
      end

      # Get the last suggestion.
      #
      # @return [Suggestion, nil] The last suggestion or nil
      def last
        @suggestions.last
      end

      # Check if the set is empty.
      #
      # @return [Boolean] True if no suggestions
      def empty?
        @suggestions.empty?
      end

      # Get the number of suggestions.
      #
      # @return [Integer] Number of suggestions
      def size
        @suggestions.size
      end
      alias count size
      alias length size

      # Iterate over suggestions.
      #
      # @yield [suggestion] Each suggestion
      # @return [Enumerator] Enumerator if no block given
      def each(&block)
        return enum_for(:each) unless block_given?
        @suggestions.each(&block)
      end

      # Get unique suggestions (by word, case-insensitive).
      #
      # @return [SuggestionSet] New set with unique suggestions
      def unique
        seen = {}
        unique_suggestions = @suggestions.select do |s|
          word = s.word.downcase
          if seen[word]
            false
          else
            seen[word] = true
            true
          end
        end
        SuggestionSet.new(unique_suggestions, max_size: @max_size)
      end

      # Convert to array of words.
      #
      # @return [Array<String>] Array of suggestion words
      def to_words
        @suggestions.map(&:word)
      end
      alias words to_words

      # Convert to array of hashes.
      #
      # @return [Array<Hash>] Array of suggestion hashes
      def to_a
        @suggestions.map(&:to_h)
      end

      # Convert to JSON-compatible array.
      #
      # @return [Array<Hash>] JSON-compatible array
      def as_json(*)
        to_a
      end

      # String representation.
      #
      # @return [String] String representation
      def to_s
        "SuggestionSet(size: #{size}, max_size: #{@max_size})"
      end

      # Inspect the suggestion set.
      #
      # @return [String] Inspection string
      def inspect
        if @suggestions.empty?
          to_s
        else
          "#{to_s} [#{@suggestions.map(&:word).join(', ')}]"
        end
      end

      # Create an empty suggestion set.
      #
      # @param max_size [Integer] Maximum size
      # @return [SuggestionSet] Empty set
      def self.empty(max_size: 10)
        new([], max_size: max_size)
      end

      # Create a suggestion set from an array of words.
      #
      # @param words [Array<String>] Array of words
      # @param source [String, Symbol] The source
      # @param max_size [Integer] Maximum size
      # @return [SuggestionSet] New set
      def self.from_words(words, source: :unknown, max_size: 10)
        suggestions = words.map { |w| Suggestion.from_word(w, source: source) }
        new(suggestions, max_size: max_size)
      end

      private

      # Sort suggestions by combined score and limit to max_size.
      #
      def sort_and_limit!
        @suggestions.sort!
        @suggestions.uniq! { |s| s.word.downcase }
        @suggestions = @suggestions.first(@max_size)
      end
    end
  end
end
