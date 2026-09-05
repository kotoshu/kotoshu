# frozen_string_literal: true

module Kotoshu
  module Documents
    module Suppressions
      # One inline ignore directive, resolved to the 1-based source
      # lines it covers. A plain value object — never serialized.
      #
      # Kinds:
      # - +:line+ — `kotoshu:disable-line`, covers its own line
      # - +:next_line+ — `kotoshu:disable-next-line [WORDS]`, covers
      #   the following line (only the listed words when a word list
      #   is present)
      # - +:file+ — a `kotoshu:disable-file` / `kotoshu:enable-file`
      #   block, covers the whole span (to EOF when never re-enabled)
      #
      # The directive line itself is always suppressed for every
      # word: the directive text is an instruction, not prose to
      # check.
      class Suppression
        KINDS = %i[line next_line file].freeze

        attr_reader :kind, :words, :directive_line, :start_line, :end_line

        # @param kind [Symbol] one of KINDS
        # @param directive_line [Integer] 1-based line the directive is on
        # @param start_line [Integer] first covered line (inclusive)
        # @param end_line [Integer] last covered line (inclusive)
        # @param words [Array<String>, nil] word list (downcased);
        #   empty means "every word"
        def initialize(kind:, directive_line:, start_line:, end_line:, words: [])
          raise ArgumentError, "unknown kind: #{kind.inspect}" unless KINDS.include?(kind)
          raise ArgumentError, "directive_line must be >= 1" if directive_line < 1
          raise ArgumentError, "start_line must be >= 1" if start_line < 1
          raise ArgumentError, "end_line must cover start_line" if end_line < start_line

          @kind = kind
          @directive_line = directive_line
          @start_line = start_line
          @end_line = end_line
          @words = Array(words).map { |w| w.to_s.downcase }.reject(&:empty?).freeze
          freeze
        end

        # A `kotoshu:disable-file` block.
        def file_block?
          kind == :file
        end

        # True when this suppression covers +line+ at all (word scope
        # not considered).
        def covers_line?(line)
          line >= start_line && line <= end_line
        end

        # True when only specifically listed words are suppressed.
        def word_scoped?
          !words.empty?
        end

        # True when +word+ reported on 1-based +line+ is suppressed.
        # Passing +word: nil+ asks "could any word on this line be
        # suppressed?" — true when the line is the directive line or
        # the suppression is not word-scoped.
        def applies_to?(line, word: nil)
          return true if line == directive_line
          return false unless covers_line?(line)
          return true if words.empty?

          word.nil? || words.include?(word.to_s.downcase)
        end
      end
    end
  end
end
