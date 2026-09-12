# frozen_string_literal: true

module Kotoshu
  module Typo
    # The hybrid typo-retrieval engine (plan 131): the frozen char
    # bi-encoder retrieves a top-20 vocabulary slate for a
    # misspelling and the fastText full tier rescores it — the layer
    # the models repo measured at +6.3 pp top-5 over frequency
    # ranking on the frozen benchmark.
    #
    # The engine itself lives in the native extension
    # ({Kotoshu::Native::TypoEngine}); this class is the Ruby-side
    # loader: it resolves the artifact pairs through the model cache
    # (the registry resources `kotoshu://models/typo/typo-biencoder`
    # and the language's full tier), constructs the native engine
    # once, and answers {#suggest} as a SuggestionSet the pipeline
    # merges ahead of frequency ranking.
    #
    # The layer is opt-in and native-only: {for} returns nil — never
    # raises — when the extension is absent or the artifacts cannot
    # resolve, the same silent-degrade contract the semantic tier and
    # the LID detector follow.
    class Engine
      # @return [Kotoshu::Native::TypoEngine, nil] the loaded native engine
      attr_reader :native_engine

      # @return [String] the language the tier was loaded for
      attr_reader :language

      # Load the engine for a language. Yielded block receives the
      # cache to use (defaults to the configured model cache) — specs
      # inject a stub cache with local artifact paths.
      #
      # @param language [String] ISO 639-1 code
      # @param configuration [Configuration]
      # @param cache [Cache::ModelCache, nil] explicit cache
      # @return [Engine, nil] nil when anything in the chain is absent
      def self.for(language, configuration: Kotoshu.configuration, cache: nil)
        return nil unless defined?(Kotoshu::Native::TypoModel)
        return nil unless Kotoshu::Native.available?

        cache ||= Cache::ModelCache.new(configuration)
        typo_onnx, typo_vocab = typo_artifacts(cache)
        tier_onnx, tier_vocab = tier_artifacts(language, cache)
        return nil unless typo_onnx && typo_vocab && tier_onnx && tier_vocab

        native = Kotoshu::Native::TypoModel.load(typo_onnx, typo_vocab)
        tier = Kotoshu::Native::TypoTier.load(tier_onnx, tier_vocab)
        new(Kotoshu::Native::TypoEngine.new(native, tier), language: language)
      rescue StandardError
        # The opt-in layer never breaks a check: any load failure
        # (corrupt artifact, engine error) degrades to "absent".
        nil
      end

      # @param native_engine [Kotoshu::Native::TypoEngine]
      # @param language [String]
      def initialize(native_engine, language:)
        @native_engine = native_engine
        @language = language
      end

      # The rescored slate for a word as a SuggestionSet, source
      # :typo_retrieval, cosine confidences clamped to [0, 1]. Empty
      # for a word outside the tier vocabulary (the hybrid's honest
      # in-vocab rule — there is nothing the layer can say).
      #
      # @param word [String]
      # @param max_suggestions [Integer, nil]
      # @return [Suggestions::SuggestionSet]
      def suggest(word, max_suggestions: nil)
        limit = max_suggestions || DEFAULT_SLATE
        rows = @native_engine.typo_suggest(word)
        suggestions = rows.first(limit).map do |row|
          Suggestions::Suggestion.new(
            word: row["word"],
            distance: 0,
            confidence: row["score"].clamp(0.0, 1.0),
            source: :typo_retrieval
          )
        end
        Suggestions::SuggestionSet.new(suggestions, max_size: limit, ranked: true)
      end

      DEFAULT_SLATE = 20

      # The typo bi-encoder artifact pair (registry paths, cache
      # resolved). Returns [onnx_path, vocab_path].
      def self.typo_artifacts(cache)
        onnx = cache.get("kotoshu://models/typo/typo-biencoder")
        vocab = cache.get("kotoshu://models/typo/typo-biencoder/vocab")
        [onnx, vocab].map { |p| p.respond_to?(:path) ? p.path : p }
      end

      # The language's full tier pair — the rescore is fp32-exact by
      # contract, so the FULL tier is the only valid tier here.
      def self.tier_artifacts(language, cache)
        onnx = cache.get("kotoshu://models/#{language}/full")
        vocab = cache.get("kotoshu://models/#{language}/full/vocab")
        [onnx, vocab].map { |p| p.respond_to?(:path) ? p.path : p }
      end
    end
  end
end
