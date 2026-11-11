# frozen_string_literal: true

module Kotoshu
  module Suggestions
    # Shared single-edit typo-pattern predicates (the corpus's dominant
    # error classes). Used by the composite merge to prioritize
    # candidates regardless of which strategy produced them, by the
    # SymSpell slate sort as a channel prior, and by
    # EditDistanceStrategy's scoring.
    module Patterns
      # True when +suggestion+ fixes +original+ by removing or adding
      # exactly one doubled letter ("helo"->"hello", "ommitted"->"omitted").
      def self.double_letter_fix?(original, suggestion)
        os = original.chars
        ss = suggestion.chars
        return false unless (os.length - ss.length).abs == 1

        longer, shorter = os.length > ss.length ? [os, ss] : [ss, os]
        longer.each_cons(2).with_index do |pair, i|
          next unless pair[0] == pair[1]

          # drop ONE of the doubled pair (index i+1): the longer side
          # with the duplicate removed must equal the shorter side
          reconstructed = longer[0...(i + 1)] + longer[(i + 2)..]
          return true if reconstructed == shorter
        end
        false
      end

      # Channel prior for a single-edit pair: how typical is this typo
      # of +suggestion+? Lower = more common error class.
      #   1 transposition (the most common typing error)
      #   2 length-changing edit (missing / extra keystroke)
      #   3 substitution of one letter
      # Dist-2+ pairs return 4.
      def self.single_edit_op(original, suggestion)
        os = original.chars
        ss = suggestion.chars
        return 4 unless (os.length - ss.length).abs <= 2

        if os.length == ss.length
          diff = (0...os.length).select { |i| os[i] != ss[i] }
          case diff.size
          when 0 then 1
          when 1 then 3
          when 2
            i, j = diff
            os[i] == ss[j] && os[j] == ss[i] ? 1 : 4
          else 4
          end
        elsif (os.length - ss.length).abs == 1
          2
        elsif subsequence_exactly_two?(os, ss)
          # both ops are the same kind of keystroke miss (two dropped
          # or two doubled letters: "containg"->"containing") — the
          # double-keystroke class
          2
        else
          4
        end
      end

      # True when the longer char array reduces to the shorter by
      # deleting exactly two characters (greedy subsequence match; the
      # length guard makes success mean exactly two skips).
      def self.subsequence_exactly_two?(a, b)
        longer, shorter = a.length >= b.length ? [a, b] : [b, a]
        return false unless (longer.length - shorter.length) == 2

        li = 0
        shorter.each do |c|
          li += 1 while li < longer.length && longer[li] != c
          return false if li >= longer.length

          li += 1
        end
        true
      end
    end
  end
end
