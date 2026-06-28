# frozen_string_literal: true

module Kotoshu
  module Models
    # FastText embedding model implementation.
    #
    # Loads FastText pre-trained word vectors from .vec files.
    # Supports Common Crawl and Wikipedia trained vectors.
    #
    # @example Loading from file
    #   model = FastTextModel.from_file('cc.en.300.vec')
    #   model.embedding_for('hello')
    #
    # @example Loading from GitHub
    #   model = FastTextModel.from_github('en')
    #   model.nearest_neighbors('hello', k: 10)
    #
    # @see https://fasttext.cc/docs/en/crawl-vectors.html FastText crawl vectors
    # @see https://fasttext.cc/docs/en/english-vectors.html FastText English vectors
    class FastTextModel < EmbeddingModel
      # Standard FastText dimension for crawl vectors
      DEFAULT_DIMENSION = 300

      # Number of vectors to load when reading from file
      # FastText .vec files contain up to 2M words; we load a subset by default
      DEFAULT_MAX_VECTORS = 1_000_000

      attr_reader :embeddings, :max_vectors

      # Create a new FastText model.
      #
      # @param language_code [String] ISO 639-1 language code
      # @param dimension [Integer] Vector dimension (default: 300)
      # @param embeddings [Hash<String, WordEmbedding>] Pre-loaded embeddings
      # @param max_vectors [Integer] Maximum vectors to load from file
      def initialize(language_code:, dimension: DEFAULT_DIMENSION, embeddings: {}, max_vectors: DEFAULT_MAX_VECTORS)
        super(language_code: language_code, dimension: dimension)
        @embeddings = embeddings.freeze
        @max_vectors = max_vectors
        @vocabulary_size = @embeddings.size
      end

      # Load FastText model from a .vec file.
      #
      # @param file_path [String] Path to FastText .vec file
      # @param max_vectors [Integer] Maximum vectors to load (default: 1M)
      # @param language_code [String] Language code (auto-detected from filename)
      # @return [FastTextModel] Loaded model
      # @raise [ArgumentError] if file doesn't exist
      def self.from_file(file_path, max_vectors: DEFAULT_MAX_VECTORS, language_code: nil)
        raise ArgumentError, "File not found: #{file_path}" unless File.exist?(file_path)

        # Detect language from filename if not provided
        language_code ||= detect_language_from_path(file_path)

        # Parse the .vec file
        embeddings = {}
        dimension = nil
        count = 0

        File.open(file_path, 'r', encoding: 'UTF-8') do |file|
          # First line: vocab_size dimension
          first_line = file.getline
          metadata = first_line.split
          _vocab_size = metadata[0].to_i
          dimension = metadata[1].to_i

          # Read vectors
          file.each_line do |line|
            break if count >= max_vectors

            parts = line.split
            word = parts[0]
            vector = parts[1..-1].map(&:to_f)

            next unless vector.size == dimension

            embeddings[word] = WordEmbedding.new(word, vector, language_code, dimension: dimension)
            count += 1
          end
        end

        new(language_code: language_code, dimension: dimension, embeddings: embeddings, max_vectors: max_vectors)
      end

      # Load FastText model from GitHub (via ModelCache).
      #
      # Downloads the .vec file from kotoshu/dictionaries repository.
      #
      # @param language_code [String] ISO 639-1 language code (de, en, es, fr, pt, ru)
      # @param max_vectors [Integer] Maximum vectors to load (default: 500K for GitHub)
      # @param cache [ModelCache, nil] Optional cache instance
      # @return [FastTextModel] Loaded model
      # @raise [ArgumentError] if language not supported
      def self.from_github(language_code, max_vectors: 500_000, cache: nil)
        cache ||= Cache::ModelCache.new

        # Get the .vec file path from cache
        vec_file = cache.get_fasttext_model(language_code)

        from_file(vec_file, max_vectors: max_vectors, language_code: language_code)
      end

      # Get embedding vector for a word.
      #
      # @param word [String] The word to lookup
      # @return [WordEmbedding, nil] Embedding vector or nil if not found
      def embedding_for(word)
        return nil if word.nil? || word.empty?

        # Direct lookup
        @embeddings[word]
      end

      # Get the vocabulary (all words in the model).
      #
      # @return [Array<String>] Vocabulary words
      def vocabulary
        @embeddings.keys
      end

      # Check if model is loaded.
      #
      # @return [Boolean] True if embeddings are loaded
      def loaded?
        @embeddings&.any?
      end

      # Find k nearest neighbors for a word (optimized version).
      #
      # Overrides the base implementation for better performance using
      # pre-loaded embeddings instead of repeated lookups.
      #
      # @param word [String] The query word
      # @param k [Integer] Number of neighbors to return
      # @return [Array<NearestNeighbor>] Nearest neighbors sorted by similarity
      def nearest_neighbors(word, k: 10)
        embedding = embedding_for(word)
        return [] unless embedding

        # Calculate similarity with all words in vocabulary
        neighbors = @embeddings.map do |vocab_word, vocab_embedding|
          next if vocab_word == word

          sim = embedding.similarity(vocab_embedding)
          NearestNeighbor.new(
            word: vocab_word,
            similarity: sim,
            embedding: vocab_embedding
          )
        end.compact

        # Sort by similarity (descending) and take top k
        neighbors.sort.reverse.first(k)
      end

      # Find k nearest neighbors for an embedding vector (optimized version).
      #
      # @param embedding [WordEmbedding] The query embedding
      # @param k [Integer] Number of neighbors to return
      # @return [Array<NearestNeighbor>] Nearest neighbors sorted by similarity
      def nearest_neighbors_for_embedding(embedding, k: 10)
        return [] unless embedding

        # Calculate similarity with all words in vocabulary
        neighbors = @embeddings.map do |vocab_word, vocab_embedding|
          sim = embedding.similarity(vocab_embedding)
          NearestNeighbor.new(
            word: vocab_word,
            similarity: sim,
            embedding: vocab_embedding
          )
        end.compact

        # Sort by similarity (descending) and take top k
        neighbors.sort.reverse.first(k)
      end

      # Get batch embeddings for multiple words.
      #
      # @param words [Array<String>] Words to lookup
      # @return [Hash<String, WordEmbedding>] Mapping of word to embedding
      def batch_embeddings(words)
        words.each_with_object({}) do |word, hash|
          emb = embedding_for(word)
          hash[word] = emb if emb
        end
      end

      # Get batch similarities for word pairs.
      #
      # @param pairs [Array<Array<String, String>>] Word pairs
      # @return [Array<Float>] Similarity scores
      def batch_similarities(pairs)
        pairs.map { |word1, word2| similarity(word1, word2) }
      end

      # Detect language code from file path.
      #
      # @param path [String] File path
      # @return [String] Detected language code
      def self.detect_language_from_path(path)
        # Extract from path like "cc.en.300.vec" or "wiki.de.vec"
        if path =~ /\.([a-z]{2})\./i
          Regexp.last_match(1).downcase
        else
          'en' # Default to English
        end
      end
    end
  end
end
