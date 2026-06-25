# frozen_string_literal: true

module Kotoshu
  module Components
    # Base class for word form synthesizers.
    #
    # Synthesizers generate inflected forms from a lemma (base form).
    # This is the inverse of lemmatization:
    # - Lemmatization: "runs" → "run"
    # - Synthesis: "run" → ["run", "runs", "running", "ran"]
    #
    # Different languages use different synthesis strategies:
    # - Latin scripts: Hunspell affix rules
    # - CJK: Not applicable (no inflection)
    # - German: Compound word + affix synthesis
    # - Finnish: Complex agglutinative patterns
    #
    # @abstract Subclasses must implement #synthesize
    #
    # @example Synthesizing English verb forms
    #   synthesizer = EnglishSynthesizer.new(aff_path: "en_US.aff", dic_path: "en_US.dic")
    #   forms = synthesizer.synthesize("run", "VERB")
    #   # => ["run", "runs", "running", "ran"]
    #
    # @example Synthesizing with POS constraint
    #   forms = synthesizer.synthesize("happy", "ADJ")
    #   # => ["happy", "happier", "happiest"]
    class Synthesizer
      # Generate inflected forms of a word.
      #
      # Given a lemma (base form) and a POS tag, returns all possible
      # inflected forms of that word.
      #
      # @abstract Subclasses must implement
      # @param lemma [String] The base form (lemma)
      # @param pos_tag [String] The POS tag to constrain generation
      # @return [Array<String>] Array of inflected forms
      # @raise [NotImplementedError] if not implemented by subclass
      def synthesize(lemma, pos_tag)
        raise NotImplementedError, "#{self.class} must implement #synthesize"
      end

      # Generate all inflected forms (all POS tags).
      #
      # Convenience method that generates forms for all possible POS tags.
      #
      # @param lemma [String] The base form (lemma)
      # @return [Hash] Hash mapping POS tags to arrays of forms
      def synthesize_all(lemma)
        # Default implementation - subclasses can optimize
        {
          'NOUN' => synthesize(lemma, 'NOUN'),
          'VERB' => synthesize(lemma, 'VERB'),
          'ADJ' => synthesize(lemma, 'ADJ'),
          'ADV' => synthesize(lemma, 'ADV')
        }
      end
    end
  end
end
