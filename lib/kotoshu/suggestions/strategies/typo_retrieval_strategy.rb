# frozen_string_literal: true

module Kotoshu
  module Suggestions
    module Strategies
      # The hybrid typo-retrieval strategy (plan 131): a frozen char
      # bi-encoder retrieves dictionary candidates a frequency-ranked
      # sweep misses, the fastText full tier rescores them, and the
      # rows join the suggestion pipeline AHEAD of frequency ranking
      # — the layer measured at +6.3 pp top-5 on the frozen
      # benchmark. Opt-in and native-only; the engine is injected so
      # the strategy itself stays pure orchestration.
      class TypoRetrievalStrategy < BaseStrategy
        # @return [#suggest] the typo engine ({Typo::Engine} in
        #   production; anything answering #suggest(word) in specs)
        attr_reader :engine

        # @param engine [#suggest] the typo engine
        # @param config [Hash] additional configuration
        def initialize(engine:, **config)
          super(name: :typo_retrieval, **config)
          @engine = engine
        end

        # Generate the typo-retrieval slate for the context's word.
        #
        # @param context [Context] the suggestion context
        # @return [SuggestionSet]
        def generate(context)
          return SuggestionSet.empty unless enabled? && @engine

          @engine.suggest(context.word, max_suggestions: max_results)
        end

        # This strategy is a candidate generator for misspellings; it
        # has no real-word-error story, which the semantic strategy
        # owns.
        #
        # @param context [Context]
        # @return [Boolean]
        def handles?(context)
          enabled? && @engine && !context.word.empty?
        end

        # The strategy's rows already carry their own order (the
        # rescored ranking); do not let a confident base set skip it.
        #
        # @return [Boolean]
        def skip_when_confident?
          false
        end
      end
    end
  end
end
