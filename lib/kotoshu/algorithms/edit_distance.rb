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
      # Returns nil when the true distance exceeds +threshold+. Uses
      # the row-minimum early-termination technique: after each DP
      # row is computed, if every cell in the row exceeds threshold,
      # the final distance must exceed threshold (the last-row cell
      # is bounded below by the row minimum) — so we bail without
      # computing the rest.
      #
      # Combined with the length pre-filter (|len1-len2| > threshold
      # implies distance > threshold), this prunes clearly-different
      # pairs in O(threshold * min(len1, len2)) instead of the full
      # O(len1 * len2) Damerau-Levenshtein DP.
      #
      # Note: the full matrix is kept (not 2-row DP) because the
      # Damerau transposition step needs d[i-1][j-1] which a 2-row
      # implementation doesn't retain. The early termination is the
      # primary win, not memory reduction.
      #
      # @param str1 [String] First string
      # @param str2 [String] Second string
      # @param threshold [Integer] Maximum distance to report
      # @return [Integer, nil] Distance if ≤ threshold, else nil
      def distance_with_threshold(str1, str2, threshold)
        return 0 if str1 == str2
        return str2.length if str1.empty?
        return str1.length if str2.empty?
        return nil if (str1.length - str2.length).abs > threshold

        len1 = str1.length
        len2 = str2.length

        d = Array.new(len1 + 1) { Array.new(len2 + 1, 0) }
        (0..len1).each { |i| d[i][0] = i }
        (0..len2).each { |j| d[0][j] = j }

        (1..len1).each do |i|
          row_min = Float::INFINITY

          (1..len2).each do |j|
            cost = str1[i - 1] == str2[j - 1] ? 0 : 1

            d[i][j] = [
              d[i - 1][j] + 1,      # deletion
              d[i][j - 1] + 1,      # insertion
              d[i - 1][j - 1] + cost # substitution
            ].min

            # Damerau transposition (needs d[i-2][j-2] which is why
            # we keep the full matrix).
            if i > 1 && j > 1 &&
                str1[i - 1] == str2[j - 2] &&
                str1[i - 2] == str2[j - 1]
              d[i][j] = [d[i][j], d[i - 2][j - 2] + 1].min
            end

            row_min = d[i][j] if d[i][j] < row_min
          end

          # Row minimum > threshold ⇒ final answer > threshold.
          return nil if row_min > threshold
        end

        result = d[len1][len2]
        result <= threshold ? result : nil
      end
    end
  end
end
