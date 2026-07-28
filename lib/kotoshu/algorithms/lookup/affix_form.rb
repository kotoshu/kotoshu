# frozen_string_literal: true

module Kotoshu
  module Algorithms
    module Lookup
      # AffixForm is a hypothesis of how some word might be split into
      # stem, suffixes and prefixes.
      #
      # It always has full text and stem, and may have up to two suffixes
      # and up to two prefixes.
      #
      # The following is always true (considering absent affixes as empty):
      #   prefix + prefix2 + stem + suffix2 + suffix = text
      #
      # prefix2/suffix2 are "secondary", so if the word has only one suffix,
      # it is stored in suffix and suffix2 is nil.
      class AffixForm
        # @return [String] Full word text
        attr_reader :text

        # @return [String] Stem (word without affixes)
        attr_reader :stem

        # @return [Hash, nil] Prefix affix data
        attr_reader :prefix

        # @return [Hash, nil] Suffix affix data
        attr_reader :suffix

        # @return [Hash, nil] Secondary prefix affix data
        attr_reader :prefix2

        # @return [Hash, nil] Secondary suffix affix data
        attr_reader :suffix2

        # @return [Hash, nil] Dictionary entry for stem
        attr_reader :in_dictionary

        def initialize(text, stem,
                       prefix: nil, suffix: nil,
                       prefix2: nil, suffix2: nil,
                       in_dictionary: nil)
          @text = text
          @stem = stem
          @prefix = prefix
          @suffix = suffix
          @prefix2 = prefix2
          @suffix2 = suffix2
          @in_dictionary = in_dictionary
        end

        # Create a copy with changes.
        #
        # @param changes [Hash] Changes to apply
        # @return [AffixForm] New affix form with changes applied
        def replace(**changes)
          self.class.new(
            changes.fetch(:text, @text),
            changes.fetch(:stem, @stem),
            prefix: changes.fetch(:prefix, @prefix),
            suffix: changes.fetch(:suffix, @suffix),
            prefix2: changes.fetch(:prefix2, @prefix2),
            suffix2: changes.fetch(:suffix2, @suffix2),
            in_dictionary: changes.fetch(:in_dictionary, @in_dictionary)
          )
        end

        # Check if this form has any affixes.
        #
        # @return [Boolean]
        def has_affixes?
          !@suffix.nil? || !@prefix.nil?
        end

        # Check if this is a base form (no affixes).
        #
        # @return [Boolean]
        def is_base?
          !has_affixes?
        end

        # Suffixes applied to this form, outermost first.
        #
        # @return [Array<Hash>] Suffix affix data
        def suffixes
          [@suffix, @suffix2].compact
        end

        # Flags the form carries: the dictionary entry's, plus those of the
        # outermost prefix and suffix.
        #
        # Secondary affixes are deliberately excluded, matching Spylls. A
        # secondary affix sits between the stem and the affix that was
        # stripped last; its flags gate that stripping (see #desuffix's
        # required_flags) rather than describing the finished word.
        #
        # @return [Set<String>] Combined flags
        def flags
          flags = @in_dictionary ? Set.new(@in_dictionary[:flags] || []) : Set.new
          flags.merge(@prefix[:flags] || []) if @prefix
          flags.merge(@suffix[:flags] || []) if @suffix
          flags
        end

        # Get all affixes (excluding nils).
        #
        # @return [Array<Hash>] List of affix data
        def all_affixes
          [@prefix2, @prefix, @suffix, @suffix2].compact
        end

        # String representation.
        #
        # @return [String]
        def to_s
          return @text if is_base?

          parts = []
          parts << @prefix.inspect if @prefix
          parts << @prefix2.inspect if @prefix2
          parts << @stem
          parts << @suffix2.inspect if @suffix2
          parts << @suffix.inspect if @suffix

          "AffixForm(#{@text} = #{parts.join(' + ')})"
        end

        alias inspect to_s
      end
    end
  end
end
