# frozen_string_literal: true

require "set"

module Kotoshu
  module Embeddings
    # Protocol - Ruby interface/contract system
    #
    # Provides a simple way to define interfaces with required and optional methods.
    module Protocol
      # Store required method names
      def required_methods
        @required_methods ||= Set.new
      end

      # Store optional method names
      def optional_methods
        @optional_methods ||= Set.new
      end

      # Define required methods
      def required_methods(*names)
        names.each { |n| required_methods << n }
      end

      # Define optional methods
      def optional_methods(*names)
        names.each { |n| optional_methods << n }
      end

      # Check compliance
      def compliance_errors(klass)
        required_methods.select { |m| !klass.respond_to?(m) }
      end

      # Assert compliance
      def assert_implemented_by!(klass)
        errors = compliance_errors(klass)
        raise "Missing methods: #{errors.join(', ')}" unless errors.empty?
      end
    end

    # Protocol error
    class ProtocolError < StandardError
      attr_reader :klass, :protocol, :missing_methods

      def initialize(klass, protocol, missing_methods)
        @klass = klass
        @protocol = protocol
        @missing_methods = missing_methods
        super("#{klass} missing: #{missing_methods.join(', ')}")
      end
    end

    # EmbeddingModel Protocol
    module EmbeddingModelProtocol
      extend Protocol

      required_methods :dimension, :language_code, :get_embedding, :get_embeddings
      required_methods :load!, :unload!, :loaded?, :ready?

      optional_methods :get_embeddings_batch, :batch_size, :preload_embeddings!
      optional_methods :supports_batching?, :model_type, :model_info
    end

    # SimilarityEngine Protocol
    module SimilarityEngineProtocol
      extend Protocol

      required_methods :cosine, :dot_product, :euclidean, :manhattan
      required_methods :pre_normalize, :normalize_and_compute

      optional_methods :cosine_batch, :compute_all_pairs
      optional_methods :is_normalized?, :normalization_required?
    end

    # Vocabulary Protocol
    module VocabularyProtocol
      extend Protocol

      required_methods :lookup, :get_word, :include?, :size, :words
      required_methods :valid_index?, :common_words, :to_h

      optional_methods :sample, :sub_vocabulary, :words_starting_with
      optional_methods :save_to_file, :language_code
    end
  end
end
