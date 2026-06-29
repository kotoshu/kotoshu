# frozen_string_literal: true

require "set"

module Kotoshu
  module Embeddings
    # Protocol - Ruby interface/contract system
    #
    # Provides a simple way to define interfaces with required and optional methods.
    module Protocol
      # Set of method names that conforming classes must implement.
      # Populated via +required+ (the writer); read via +required_methods+.
      def required_methods
        @required_methods ||= Set.new
      end

      # Set of method names that conforming classes may optionally implement.
      # Populated via +optional+ (the writer); read via +optional_methods+.
      def optional_methods
        @optional_methods ||= Set.new
      end

      # Declare one or more required methods on this protocol.
      def required(*names)
        names.each { |n| required_methods << n }
      end

      # Declare one or more optional methods on this protocol.
      def optional(*names)
        names.each { |n| optional_methods << n }
      end

      # Returns the subset of +required_methods+ that +klass+ does not
      # implement as an instance method. Empty result means full
      # conformance. +klass+ should be a Class (not an instance); we
      # check +method_defined?+ because protocol-declared methods are
      # mixed in via +include+, becoming instance methods of +klass+.
      def compliance_errors(klass)
        required_methods.reject { |m| klass.method_defined?(m) }
      end

      # Raise ProtocolError unless +klass+ implements every required method.
      def assert_implemented_by!(klass)
        errors = compliance_errors(klass)
        return if errors.empty?

        raise ProtocolError.new(klass, self, errors.to_a)
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

      required :dimension, :language_code, :get_embedding, :get_embeddings
      required :load!, :unload!, :loaded?, :ready?

      optional :get_embeddings_batch, :batch_size, :preload_embeddings!
      optional :supports_batching?, :model_type, :model_info
    end

    # SimilarityEngine Protocol
    module SimilarityEngineProtocol
      extend Protocol

      required :cosine, :dot_product, :euclidean, :manhattan
      required :pre_normalize, :normalize_and_compute

      optional :cosine_batch, :compute_all_pairs
      optional :is_normalized?, :normalization_required?
    end

    # Vocabulary Protocol
    module VocabularyProtocol
      extend Protocol

      required :lookup, :get_word, :include?, :size, :words
      required :valid_index?, :common_words, :to_h

      optional :sample, :sub_vocabulary, :words_starting_with
      optional :save_to_file, :language_code
    end
  end
end
