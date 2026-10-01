# frozen_string_literal: true

module Kotoshu
  module Grammar
    # English morphology shared by PatternRule suggestions and the
    # neural tagger's deterministic fix generation.
    module Morphology
      class << self
        # Third-person singular inflection: irregular table first, then
        # the s/sh/ch/x/z → es, consonant+y → ies, else +s rules.
        def inflect_3sg(word)
          base = word.to_s.downcase
          if PosTagger::IRREGULAR_VERBS.key?(base)
            return PosTagger::IRREGULAR_VERBS[base][0]
          end

          return "#{base}es" if base.match?(/(?:s|sh|ch|x|z)\z/)
          return "#{base[0..-2]}ies" if base.match?(/[^aeiou]y\z/)

          "#{base}s"
        end

        # Inverse of inflect_3sg for the words it can invert safely.
        def uninflect_3sg(word)
          base = word.to_s.downcase
          PosTagger::IRREGULAR_VERBS.each do |stem, forms|
            return stem if forms[0] == base
          end
          return "#{base[0..-4]}y" if base.match?(/[^aeiou]ies\z/)
          return base[0..-3] if base.match?(/(?:ch|sh|x|z|o)es\z/)
          return base[0..-2] if base.match?(/[^s]s\z/) && base.length >= 4

          word.to_s
        end
      end
    end
  end
end
