# frozen_string_literal: true

# Registry - Plugin system for embeddings components
#
# Provides a centralized registry for embedding models, similarity engines,
# and vocabularies. Allows registering and retrieving custom implementations.
#
# @example Registering a custom model
#   Registry.register_model(:my_model, MyCustomModel)
#
# @example Creating from registry
#   model = Registry.create_model(:my_model, vectors: my_vectors)
#
# @example Listing available implementations
#   Registry.models.keys  # => [:onnx, :my_model]
#
class EmbeddingRegistry
  class << self
    # @return [Hash{Symbol => Class}] Registered models
    attr_reader :models

    # @return [Hash{Symbol => Class}] Registered engines
    attr_reader :engines

    # @return [Hash{Symbol => Class}] Registered vocabularies
    attr_reader :vocabularies

    # Initialize registry
    #
    def init
      @models ||= {}
      @engines ||= {}
      @vocabularies ||= {}
    end

    # Register an embedding model
    #
    # @param name [Symbol] Model identifier
    # @param klass [Class] Model class (must implement EmbeddingModel protocol)
    #
    def register_model(name, klass)
      init
      @models[name] = klass
      klass
    end

    # Register a similarity engine
    #
    # @param name [Symbol] Engine identifier
    # @param klass [Class] Engine class (must implement SimilarityEngine protocol)
    #
    def register_engine(name, klass)
      init
      @engines[name] = klass
      klass
    end

    # Register a vocabulary
    #
    # @param name [Symbol] Vocabulary identifier
    # @param klass [Class] Vocabulary class (must implement Vocabulary protocol)
    #
    def register_vocabulary(name, klass)
      init
      @vocabularies[name] = klass
      klass
    end

    # Get registered model class
    #
    # @param name [Symbol] Model identifier
    # @return [Class, nil]
    #
    def model(name)
      init
      @models[name]
    end

    # Get registered engine class
    #
    # @param name [Symbol] Engine identifier
    # @return [Class, nil]
    #
    def engine(name)
      init
      @engines[name]
    end

    # Get registered vocabulary class
    #
    # @param name [Symbol] Vocabulary identifier
    # @return [Class, nil]
    #
    def vocabulary(name)
      init
      @vocabularies[name]
    end

    # Create a model instance
    #
    # @param name [Symbol] Model identifier
    # @param kwargs [Hash] Model constructor arguments
    # @return [EmbeddingModel]
    #
    def create_model(name, **kwargs)
      klass = model(name)
      raise ArgumentError, "Unknown model: #{name}" unless klass

      klass.new(**kwargs)
    end

    # Create an engine instance
    #
    # @param name [Symbol] Engine identifier
    # @param kwargs [Hash] Engine constructor arguments
    # @return [SimilarityEngine]
    #
    def create_engine(name, **kwargs)
      klass = engine(name)
      raise ArgumentError, "Unknown engine: #{name}" unless klass

      klass.new(**kwargs)
    end

    # Create a vocabulary instance
    #
    # @param name [Symbol] Vocabulary identifier
    # @param kwargs [Hash] Vocabulary constructor arguments
    # @return [Vocabulary]
    #
    def create_vocabulary(name, **kwargs)
      klass = vocabulary(name)
      raise ArgumentError, "Unknown vocabulary: #{name}" unless klass

      klass.new(**kwargs)
    end

    # List all registered models
    #
    # @return [Array<Symbol>]
    #
    def model_names
      init
      @models.keys
    end

    # List all registered engines
    #
    # @return [Array<Symbol>]
    #
    def engine_names
      init
      @engines.keys
    end

    # List all registered vocabularies
    #
    # @return [Array<Symbol>]
    #
    def vocabulary_names
      init
      @vocabularies.keys
    end

    # Clear all registrations
    #
    def reset!
      @models = {}
      @engines = {}
      @vocabularies = {}
    end
  end
end

# Register built-in implementations
require_relative 'onnx_runtime_model'
require_relative 'similarity_engine'
require_relative 'vocabulary'

EmbeddingRegistry.register_model(:onnx, OnnxRuntimeModel)
EmbeddingRegistry.register_engine(:cosine, SimilarityEngine)
EmbeddingRegistry.register_vocabulary(:json, Vocabulary)
