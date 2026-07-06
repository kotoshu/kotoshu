# frozen_string_literal: true

module Kotoshu
  module Algorithms
    # Damerau-Levenshtein edit distance.
    #
    # Counts the minimum number of operations (insertion, deletion,
    # substitution, or transposition of adjacent characters) needed
    # to transform one string into another. The transposition
    # extension distinguishes this from plain Levenshtein — a
    # transposition (e.g. "teh" → "the") costs 1 instead of 2.
    #
    # Extracted from EditDistanceStrategy so that the algorithm is
    # reusable independent of the strategy pipeline and testable
    # without send-to-private.
    module EditDistance
      module_function

      # Compute the Damerau-Levenshtein distance between two strings.
      #
      # @param str1 [String] First string
      # @param str2 [String] Second string
      # @return [Integer] Edit distance (0 when str1 == str2)
      def distance(str1, str2)
        return str2.length if str1.empty?
        return str1.length if str2.empty?

        len1 = str1.length
        len2 = str2.length

        d = Array.new(len1 + 1) { Array.new(len2 + 1, 0) }

        (0..len1).each { |i| d[i][0] = i }
        (0..len2).each { |j| d[0][j] = j }

        (1..len1).each do |i|
          (1..len2).each do |j|
            cost = str1[i - 1] == str2[j - 1] ? 0 : 1

            d[i][j] = [
              d[i - 1][j] + 1,      # deletion
              d[i][j - 1] + 1,      # insertion
              d[i - 1][j - 1] + cost # substitution
            ].min

            next unless i > 1 && j > 1 &&
              str1[i - 1] == str2[j - 2] &&
              str1[i - 2] == str2[j - 1]

            d[i][j] = [d[i][j], d[i - 2][j - 2] + 1].min
          end
        end

        d[len1][len2]
      end

      # Compute edit distance with early-exit threshold.
      #
      # Returns nil when the true distance exceeds +threshold+,
      # letting callers prune candidate pairs without paying for
      # the full computation. The current implementation computes
      # the full distance and then thresholds — kept as a seam so
      # a future banded-DP optimization can drop in here.
      #
      # @param str1 [String] First string
      # @param str2 [String] Second string
      # @param threshold [Integer] Maximum distance to report
      # @return [Integer, nil] Distance if ≤ threshold, else nil
      def distance_with_threshold(str1, str2, threshold)
        dist = distance(str1, str2)
        dist <= threshold ? dist : nil
      end
    end
  end
end
