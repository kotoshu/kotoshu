# frozen_string_literal: true

module Kotoshu
  module Models
    # ONNX embedding model implementation.
    #
    # Loads FastText models converted to ONNX format for faster inference.
    # Uses ONNX Runtime for efficient embedding lookup.
    #
    # @example Loading from file
    #   model = OnnxModel.from_file('fasttext.en.onnx')
    #   embedding = model.embedding_for('hello')
    #
    # @example Loading from GitHub (via ModelCache)
    #   model = OnnxModel.from_github('en')
    #   neighbors = model.nearest_neighbors('hello', k: 10)
    class OnnxModel < EmbeddingModel
      # Soft-load onnxruntime. The gem is intentionally NOT a hard runtime
      # dependency — it fails to build on some platforms and would block
      # install for users who only want traditional spell-checking. Semantic
      # features light up automatically when the gem is present.
      #
      # KOTOSHU_NO_ONNX=1 forces semantic analysis off even when the gem is
      # installed (useful for benchmarks / CI determinism).
      ONNX_LOADED = begin
        if ENV["KOTOSHU_NO_ONNX"] == "1"
          false
        else
          require "onnxruntime"
          true
        end
      rescue LoadError
        false
      end

      # Error raised when semantic features are requested but onnxruntime
      # is unavailable. Caller-friendly message points at the fix.
      class OnnxUnavailable < Kotoshu::Error
        def initialize(detail = nil)
          message = "onnxruntime gem not loaded"
          message += " (#{detail})" if detail
          message += ". Install with: gem install onnxruntime"
          message += ". Or set KOTOSHU_NO_ONNX=1 to silence this in code paths that opt out."
          super(message)
        end
      end

      # Default dimension for FastText models
      DEFAULT_DIMENSION = 300

      attr_reader :onnx_path, :vocabulary, :embedding_matrix

      # Create a new ONNX model.
      #
      # @param language_code [String] ISO 639-1 language code
      # @param dimension [Integer] Vector dimension
      # @param onnx_path [String] Path to .onnx file
      # @param vocabulary [Hash<String, Integer>] Word-to-index mapping
      # @param embedding_matrix [Numo::SFloat] Pre-loaded embeddings (optional)
      def initialize(language_code:, onnx_path:, vocabulary:, dimension: DEFAULT_DIMENSION, embedding_matrix: nil)
        super(language_code: language_code, dimension: dimension)
        @onnx_path = onnx_path
        @vocabulary = vocabulary.freeze
        @vocabulary_size = @vocabulary.size

        # Pre-load embedding matrix if provided (for faster nearest neighbor search)
        @embedding_matrix = embedding_matrix

        # Lazy load session
        @session = nil
        @loaded = false
      end

      # Load ONNX model from a file.
      #
      # @param onnx_path [String] Path to .onnx file
      # @param language_code [String] Language code (auto-detected from filename)
      # @return [OnnxModel] Loaded model
      # @raise [ArgumentError] if file doesn't exist
      def self.from_file(onnx_path, language_code: nil)
        raise ArgumentError, "File not found: #{onnx_path}" unless File.exist?(onnx_path)

        # Detect language from filename if not provided
        language_code ||= detect_language_from_path(onnx_path)

        # Load vocabulary from .vocab.json file
        vocab_path = onnx_path.sub('.onnx', '.vocab.json')
        unless File.exist?(vocab_path)
          raise ArgumentError, "Vocabulary file not found: #{vocab_path}"
        end

        require 'json'
        vocabulary = JSON.parse(File.read(vocab_path))

        # Load metadata
        metadata_path = onnx_path.sub('.onnx', '.metadata.json')
        dimension = DEFAULT_DIMENSION

        if File.exist?(metadata_path)
          metadata = JSON.parse(File.read(metadata_path))
          dimension = metadata['dimension']
        end

        new(
          language_code: language_code,
          dimension: dimension,
          onnx_path: onnx_path,
          vocabulary: vocabulary
        )
      end

      # Load ONNX model from GitHub (via ModelCache).
      #
      # Downloads the .onnx file from kotoshu/dictionaries repository.
      #
      # @param language_code [String] ISO 639-1 language code (de, en, es, fr, pt, ru)
      # @param cache [ModelCache, nil] Optional cache instance
      # @return [OnnxModel] Loaded model
      # @raise [ArgumentError] if language not supported
      def self.from_github(language_code, cache: nil)
        cache ||= Cache::ModelCache.new

        # Get the .onnx file path from cache
        onnx_file = cache.get_onnx_model(language_code)

        from_file(onnx_file, language_code: language_code)
      end

      # Get embedding vector for a word.
      #
      # @param word [String] The word to lookup
      # @return [WordEmbedding, nil] Embedding vector or nil if not found
      def embedding_for(word)
        return nil if word.nil? || word.empty?

        index = @vocabulary[word]
        return nil unless index

        # Get embedding from ONNX model
        vector = get_embedding_vector(index)

        WordEmbedding.new(word, vector, @language_code, dimension: @dimension)
      end

      # Get the vocabulary (all words in the model).
      #
      # @return [Array<String>] Vocabulary words
      def vocabulary
        @vocabulary.keys
      end

      # Check if model is loaded.
      #
      # @return [Boolean] True if ONNX session is loaded
      def loaded?
        @loaded
      end

      # Find k nearest neighbors for a word.
      #
      # @param word [String] The query word
      # @param k [Integer] Number of neighbors to return
      # @return [Array<NearestNeighbor>] Nearest neighbors sorted by similarity
      def nearest_neighbors(word, k: 10)
        ensure_session_loaded

        # Get query embedding
        query = embedding_for(word)
        return [] unless query

        # If embedding matrix is pre-loaded, use it for faster search
        if @embedding_matrix
          nearest_neighbors_from_matrix(query, k)
        else
          super
        end
      end

      # Batch lookup of embeddings for multiple words.
      #
      # More efficient than individual lookups when using ONNX.
      #
      # @param words [Array<String>] Words to lookup
      # @return [Hash<String, WordEmbedding>] Word to embedding mapping
      def batch_embeddings(words)
        ensure_session_loaded

        indices = words.map { |w| @vocabulary[w] }
        vectors = batch_get_embeddings(indices)

        words.zip(indices, vectors).each_with_object({}) do |(word, idx, vec)|
          next unless idx && vec

          [word, WordEmbedding.new(word, vec, @language_code, dimension: @dimension)]
        end
      end

      # Preload the embedding matrix into memory for faster nearest neighbor search.
      #
      # Useful when doing many nearest neighbor queries.
      #
      # @return [Boolean] True if loaded successfully
      def preload_embedding_matrix
        ensure_session_loaded

        # Get all embeddings at once
        all_indices = (0...@vocabulary_size).to_a
        vectors = batch_get_embeddings(all_indices)

        # Convert to matrix (using Numo::SFloat for efficiency)
        require 'numo/narray'
        @embedding_matrix = Numo::Sfloat.cast(vectors).reshape(@vocabulary_size, @dimension)

        true
      rescue StandardError => e
        warn "Failed to preload embedding matrix: #{e.message}"
        false
      end

      private

      # Get embedding vector from ONNX model.
      #
      # @param index [Integer] Word index
      # @return [Array<Float>] Embedding vector
      def get_embedding_vector(index)
        ensure_session_loaded

        result = @session.run(
          ['embeddings'],
          { word_indices: [index].pack('q<') } # Pack int64 as little-endian
        )

        # Unpack float32 array
        result.first.unpack('e*')
      end

      # Get embeddings for multiple indices.
      #
      # @param indices [Array<Integer>] Word indices
      # @return [Array<Array<Float>>] Embedding vectors
      def batch_get_embeddings(indices)
        ensure_session_loaded

        valid_indices = indices.compact

        return [] if valid_indices.empty?

        # Pack indices as int64 array
        input_data = valid_indices.pack('q<*')

        result = @session.run(
          ['embeddings'],
          { word_indices: input_data }
        )

        # Unpack float32 matrix
        vectors = result.first.unpack('e*')
        chunk_size = @dimension

        vectors.each_slice(chunk_size).to_a
      end

      # Find nearest neighbors using pre-loaded embedding matrix.
      #
      # @param query [WordEmbedding] Query embedding
      # @param k [Integer] Number of neighbors
      # @return [Array<NearestNeighbor>] Nearest neighbors
      def nearest_neighbors_from_matrix(query, k)
        return [] unless @embedding_matrix

        # Compute cosine similarity with all words
        query_vec = Numo::Sfloat.cast(query.vector)
        similarities = []

        @vocabulary.each_with_index do |(word, idx)|
          vec = @embedding_matrix[idx, true]
          sim = cosine_similarity(query_vec, vec)
          similarities << [word, sim]
        end

        # Sort by similarity and take top k
        similarities.sort_by { |_, s| -s }.first(k).map do |word, sim|
          NearestNeighbor.new(
            word: word,
            similarity: sim,
            embedding: embedding_for(word)
          )
        end
      end

      # Calculate cosine similarity between two vectors.
      #
      # @param vec1 [Numo::SFloat] First vector
      # @param vec2 [Numo::SFloat] Second vector
      # @return [Float] Cosine similarity
      def cosine_similarity(vec1, vec2)
        dot = (vec1 * vec2).sum
        norm1 = Math.sqrt((vec1**2).sum)
        norm2 = Math.sqrt((vec2**2).sum)

        return 0.0 if norm1.zero? || norm2.zero?

        dot / (norm1 * norm2)
      end

      # Ensure ONNX session is loaded.
      def ensure_session_loaded
        return if @loaded

        raise OnnxUnavailable unless ONNX_LOADED

        @session = OnnxRuntime::Session.new(@onnx_path)
        @loaded = true
      end

      # Detect language code from file path.
      #
      # @param path [String] File path
      # @return [String] Detected language code
      def self.detect_language_from_path(path)
        # Extract from path like "fasttext.en.onnx"
        if path =~ /\.([a-z]{2})\./i
          Regexp.last_match(1).downcase
        else
          'en' # Default to English
        end
      end
    end
  end
end
