# frozen_string_literal: true

require "set" if RUBY_VERSION < "3.0"

module Kotoshu
  module Suggestions
    module Strategies
      # Exact and case-insensitive word lookup over a dictionary word
      # list, built once per suggestion sweep.
      #
      # {KeyboardProximityStrategy} matches one keyboard variant at a
      # time, and its two-round variant set reaches tens of thousands
      # of lookups per word — each of which used to scan the whole
      # dictionary (with a +downcase+ per candidate on the
      # case-insensitive branch). The index answers the same lookups in
      # constant time.
      #
      # Lookup semantics are KeyboardProximityStrategy's historical
      # +find_word+ exactly:
      #
      # - the exact-match branch answers "is the lowercased input a
      #   word of the list as-is?" and returns the INPUT string when it
      #   is (the variant as typed, not the dictionary entry);
      # - otherwise the first word in list order whose lowercase form
      #   equals the lowercased input wins (first-in-list-order on
      #   collisions);
      # - nil/empty input finds nothing.
      #
      # This mirrors WordIndex in kotoshu-rs (kotoshu/src/suggest/mod.rs).
      class WordIndex
        # @return [Set<String>] The words exactly as listed
        attr_reader :exact

        # @return [Hash<String, String>] Lowercase form => first listed word
        attr_reader :lowered

        # Build an index over a word list.
        #
        # @param words [Array<String>] Dictionary words in list order
        # @return [WordIndex] The built index
        def self.build(words)
          exact = Set.new
          lowered = {}
          words.each do |word|
            exact.add(word)
            key = word.downcase
            lowered[key] = word unless lowered.key?(key)
          end
          new(exact, lowered)
        end

        # Create a word index from prebuilt structures.
        #
        # @param exact [Set<String>] Words exactly as listed
        # @param lowered [Hash<String, String>] Lowercase form => first listed word
        def initialize(exact, lowered)
          @exact = exact
          @lowered = lowered
        end

        # Find a word in the indexed list.
        #
        # @param word [String, nil] The word to find
        # @return [String, nil] The input string on an exact (lowercase)
        #   match, else the first listed word with the same lowercase
        #   form, else nil
        def find(word)
          return nil if word.nil? || word.empty?

          word_lower = word.downcase
          return word if @exact.include?(word_lower)

          @lowered[word_lower]
        end
      end
    end
  end
end
