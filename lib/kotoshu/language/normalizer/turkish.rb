# frozen_string_literal: true

module Kotoshu
  module Language
    module Normalizer
      # Turkish-aware normalizer.
      #
      # Turkish case folding is not the Unicode default: dotted and
      # dotless i form a separate pair. A plain downcase maps I to i,
      # which turns DİŞARIIDA into disarida — a word no Turkish
      # dictionary contains. Ruby's :turkic case mapping gets the pair
      # right: I -> ı and İ -> i, so İZMİR folds to izmir and
      # ISTANBUL folds to ıstanbul.
      class Turkish < Base
        # Normalize text with Turkish case folding.
        #
        # @param text [String] Text to normalize
        # @param options [Hash] Normalization options
        # @return [String] Normalized text
        def normalize(text, options = {})
          downcase = options.fetch(:downcase, true)
          result = super(text, options.merge(downcase: false))
          downcase ? turkish_downcase(result) : result
        end

        private

        # Fold case with the Turkish i pair.
        #
        # @param text [String] Text to fold
        # @return [String] Folded text
        def turkish_downcase(text)
          text.downcase(:turkic)
        end
      end
    end
  end
end
