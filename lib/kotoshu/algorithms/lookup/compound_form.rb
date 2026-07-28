# frozen_string_literal: true

module Kotoshu
  module Algorithms
    module Lookup
      # CompoundForm is a hypothesis of how some word could be split into
      # several AffixForms (word parts with their own stems and possible affixes).
      #
      # Typically, only first part is allowed to have prefix, and only last
      # part is allowed to have suffix, but there are languages where middle
      # parts can have affixes too, specified by special flags.
      class CompoundForm
        # @return [Array<AffixForm>] Parts of the compound word
        attr_reader :parts

        # Junctions sit between parts, so a compound of N parts has N-1 of
        # them. The list is built front-to-back exactly like parts and holds
        # the CHECKCOMPOUNDPATTERN whose replacement rebuilt each junction,
        # or nil where the parts simply met. A shorter list means the
        # trailing junctions are ordinary.
        #
        # @return [Array<Readers::CompoundPattern, nil>] Pattern per junction
        attr_reader :junction_patterns

        def initialize(parts, junction_patterns = [])
          @parts = parts
          @junction_patterns = junction_patterns
        end

        # The pattern whose replacement rebuilt the junction after part
        # `index`, if any.
        #
        # @param index [Integer] Index of the part left of the junction
        # @return [Readers::CompoundPattern, nil]
        def junction_pattern(index)
          @junction_patterns[index]
        end

        # String representation.
        #
        # @return [String]
        def to_s
          "CompoundForm(#{@parts.map(&:to_s).join(' + ')})"
        end

        alias inspect to_s
      end
    end
  end
end
