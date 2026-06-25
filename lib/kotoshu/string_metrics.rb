# frozen_string_literal: true

module Kotoshu
  # String similarity metrics for spell checking.
  #
  # Ported from Spylls (Python) string_metrics.py
  #
  # These metrics are used for:
  # - Computing word similarity
  # - Ranking suggestions
  # - N-gram based scoring
  module StringMetrics
    # Number of occurrences of the exactly same characters in exactly same position.
    #
    # @param s1 [String] First string
    # @param s2 [String] Second string
    # @return [Integer] Count of matching characters at same positions
    #
    # @example
    #   Kotoshu::StringMetrics.commoncharacters("hello", "hallo")  # => 4 ('h', 'l', 'l', 'o' match)
    def self.commoncharacters(s1, s2)
      return 0 if s1.nil? || s2.nil?

      # Zip strings and count matching character pairs
      [s1.length, s2.length].min.times.count do |i|
        s1[i] == s2[i]
      end
    end

    # Size of the common start of two strings.
    #
    # @param s1 [String] First string
    # @param s2 [String] Second string
    # @return [Integer] Length of common prefix
    #
    # @example
    #   Kotoshu::StringMetrics.leftcommonsubstring("foo", "bar")       # => 0
    #   Kotoshu::StringMetrics.leftcommonsubstring("built", "build")   # => 4
    #   Kotoshu::StringMetrics.leftcommonsubstring("cat", "cats")      # => 3
    def self.leftcommonsubstring(s1, s2)
      return 0 if s1.nil? || s2.nil?

      # Find first position where characters differ
      s1.chars.zip(s2.chars).each_with_index do |(c1, c2), i|
        return i if c1 != c2
      end

      # All characters matched up to shorter string length
      [s1.length, s2.length].min
    end

    # Calculate n-gram similarity between two strings.
    #
    # Calculates how many n-grams of s1 are contained in s2 (the more the number,
    # the more words are similar).
    #
    # @param max_ngram_size [Integer] Maximum n-gram size to check
    # @param s1 [String] String to compare
    # @param s2 [String] String to compare
    # @param weighted [Boolean] Subtract from result for ngrams NOT contained
    # @param any_mismatch [Boolean] Add penalty for any string length difference
    # @param longer_worse [Boolean] Add penalty when second string is longer
    # @return [Integer] N-gram similarity score (higher is more similar)
    #
    # @example
    #   Kotoshu::StringMetrics.ngram(4, "hello", "help")                 # => 6
    #   Kotoshu::StringMetrics.ngram(4, "teachings", "teaching")       # => higher score
    def self.ngram(max_ngram_size, s1, s2, weighted: false, any_mismatch: false, longer_worse: false)
      l2 = s2.length
      return 0 if l2.zero?

      l1 = s1.length
      nscore = 0

      # For all sizes of ngram up to desired...
      (1..max_ngram_size).each do |ngram_size|
        ns = 0

        # Check every position in the first string
        (0..(l1 - ngram_size)).each do |pos|
          ngram = s1[pos, ngram_size]

          # If the ngram is present in ANY place in second string, increase score
          if s2.include?(ngram)
            ns += 1
          elsif weighted
            # For "weighted" ngrams, decrease score if ngram is not found
            ns -= 1
            # Decrease once more if it was the beginning or end of first string
            ns -= 1 if pos.zero? || pos + ngram_size == l1
          end
        end

        nscore += ns

        # There is no need to check for 4-gram if there were only one 3-gram
        break if ns < 2 && !weighted
      end

      # Calculate penalty based on settings
      penalty = if longer_worse
                  # Add penalty when second string is longer
                  (l2 - l1) - 2
                elsif any_mismatch
                  # Add penalty for any string length difference
                  (l2 - l1).abs - 2
                else
                  0
                end

      # Apply penalty if positive
      penalty > 0 ? nscore - penalty : nscore
    end

    # Calculate LCS (Longest Common Subsequence) length.
    #
    # Classic dynamic programming algorithm. This is different from
    # longest common substring - subsequence doesn't require contiguity.
    #
    # @param s1 [String] First string
    # @param s2 [String] Second string
    # @return [Integer] Length of longest common subsequence
    #
    # @example
    #   Kotoshu::StringMetrics.lcslen("AGGTAB", "GXTXAYB")  # => 4 ("GTAB")
    def self.lcslen(s1, s2)
      return 0 if s1.nil? || s2.nil? || s1.empty? || s2.empty?

      m = s1.length
      n = s2.length

      # Create DP table
      # Using a 2D array for clarity, though we could optimize space
      c = Array.new(m + 1) { Array.new(n + 1, 0) }

      (0...m).each do |i|
        (0...n).each do |j|
          if s1[i] == s2[j]
            # Characters match - extend diagonal
            c[i + 1][j + 1] = c[i][j] + 1
          elsif c[i][j + 1] >= c[i + 1][j]
            # Take max from top or left
            c[i + 1][j + 1] = c[i][j + 1]
          else
            c[i + 1][j + 1] = c[i + 1][j]
          end
        end
      end

      c[m][n]
    end
  end
end
