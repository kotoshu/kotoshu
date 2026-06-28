# frozen_string_literal: true

# Embeddings module for FastText ONNX integration.
#
# Provides semantic spell checking using FastText word embeddings converted
# to ONNX format. Loading this file is cheap — every class below is
# autoloaded on first reference.
#
# @example Simple usage (recommended)
#   pipeline = Kotoshu::Embeddings.from_cache(language: 'en')
#   neighbors = pipeline.find_nearest('semantic', k: 5)
#
# @example Advanced usage
#   vocab = Kotoshu::Embeddings::Vocabulary.from_file('vocab.json')
#   model = Kotoshu::Embeddings::OnnxRuntimeModel.from_file('model.onnx')
#   engine = Kotoshu::Embeddings::SimilarityEngine.new(pre_normalize: true)
#
module Kotoshu
  module Embeddings
    DEFAULT_DIMENSION = 300
    MAX_VOCABULARY_SIZE = 100_000
    VERSION = '2.0.0'

    autoload :Protocol,              "kotoshu/embeddings/protocol"
    autoload :ProtocolError,         "kotoshu/embeddings/protocol"
    autoload :EmbeddingModelProtocol, "kotoshu/embeddings/protocol"
    autoload :SimilarityEngineProtocol, "kotoshu/embeddings/protocol"
    autoload :VocabularyProtocol,    "kotoshu/embeddings/protocol"
    autoload :LruCache,             "kotoshu/embeddings/lru_cache"
    autoload :Vocabulary,           "kotoshu/embeddings/vocabulary"
    autoload :OnnxRuntimeModel,     "kotoshu/embeddings/onnx_runtime_model"
    autoload :SimilarityEngine,     "kotoshu/embeddings/similarity_engine"
    autoload :Search,               "kotoshu/embeddings/search"
    autoload :SimilaritySearch,     "kotoshu/embeddings/similarity_search"
    autoload :EmbeddingPipeline,    "kotoshu/embeddings/embedding_pipeline"
    autoload :Registry,             "kotoshu/embeddings/registry"

    # Create an EmbeddingPipeline from cache
    #
    # @param language [String] ISO 639-1 language code
    # @param preload [Boolean] Preload embeddings into memory
    # @param index [:exact, :auto] Search index type
    # @return [EmbeddingPipeline]
    #
    def self.from_cache(language:, preload: false, index: :exact)
      EmbeddingPipeline.from_cache(language: language, preload: preload,
                                   index: index)
    end

    # Check if a language is supported
    #
    # @param language [String] ISO 639-1 language code
    # @return [Boolean]
    #
    def self.language_supported?(language)
      cache = Kotoshu::Cache::ModelCache.new
      cache.available_models_for(language.to_sym).include?(:onnx)
    end

    # List all supported languages
    #
    # @return [Array<String>]
    #
    def self.supported_languages
      cache = Kotoshu::Cache::ModelCache.new
      cache.all_available_models[:onnx].keys.map(&:to_s)
    end

    # Create a custom embedding pipeline
    #
    # @param vocabulary [Vocabulary] Vocabulary instance
    # @param model [EmbeddingModel] Model instance
    # @param preload [Boolean] Preload embeddings
    # @param pre_normalize [Boolean] Pre-normalize vectors
    # @return [EmbeddingPipeline]
    #
    def self.create_pipeline(vocabulary:, model:, preload: false,
                             pre_normalize: false)
      EmbeddingPipeline.new(
        vocabulary: vocabulary,
        model: model,
        preload: preload,
        pre_normalize: pre_normalize,
      )
    end
  end
end
