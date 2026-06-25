# frozen_string_literal: true

# Load all components
require_relative 'embeddings/protocol'
require_relative 'embeddings/lru_cache'
require_relative 'embeddings/vocabulary'
require_relative 'embeddings/onnx_runtime_model'
require_relative 'embeddings/similarity_engine'
require_relative 'embeddings/search'
require_relative 'embeddings/embedding_pipeline'
require_relative 'embeddings/registry'

# Embeddings module for FastText ONNX integration.
#
# Provides semantic spell checking using FastText word embeddings.
# Supports 157 languages through pre-converted ONNX models.
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
    # Constants
    DEFAULT_DIMENSION = 300
    MAX_VOCABULARY_SIZE = 100_000
    VERSION = '2.0.0'

    # Expose classes
    Vocabulary = ::Vocabulary
    OnnxRuntimeModel = ::OnnxRuntimeModel
    SimilarityEngine = ::SimilarityEngine
    Search = ::Search
    EmbeddingPipeline = ::EmbeddingPipeline
    LruCache = ::LruCache
    Registry = ::EmbeddingRegistry

    # Protocols namespace
    module Protocols
      EmbeddingModel = ::EmbeddingModelProtocol
      SimilarityEngine = ::SimilarityEngineProtocol
      Vocabulary = ::VocabularyProtocol
    end

    # Create an EmbeddingPipeline from cache
    #
    # @param language [String] ISO 639-1 language code
    # @param preload [Boolean] Preload embeddings into memory
    # @return [EmbeddingPipeline]
    #
    def self.from_cache(language:, preload: false, index: :exact)
      EmbeddingPipeline.from_cache(language: language, preload: preload, index: index)
    end

    # Check if a language is supported
    #
    # @param language [String] ISO 639-1 language code
    # @return [Boolean]
    #
    def self.language_supported?(language)
      require_relative '../cache/model_cache'
      cache = Cache::ModelCache.new
      cache.available_models_for(language.to_sym).include?(:onnx)
    end

    # List all supported languages
    #
    # @return [Array<String>]
    #
    def self.supported_languages
      require_relative '../cache/model_cache'
      cache = Cache::ModelCache.new
      cache.all_available_models[:onnx].keys.map(&:to_s)
    end

    # Create a custom embedding pipeline
    #
    # @param vocabulary [Vocabulary] Vocabulary instance
    # @param model [EmbeddingModel] Model instance
    # @param preload [Boolean] Preload embeddings
    # @return [EmbeddingPipeline]
    #
    def self.create_pipeline(vocabulary:, model:, preload: false, pre_normalize: false)
      EmbeddingPipeline.new(
        vocabulary: vocabulary,
        model: model,
        preload: preload,
        pre_normalize: pre_normalize
      )
    end
  end
end
