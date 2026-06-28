# frozen_string_literal: true

# Search - Brute force nearest neighbor search
#
# Performs exhaustive search over all vocabulary entries.
# Uses min-heap for efficient top-k selection (O(n log k) instead of O(n log n)).
#
# @example
#   search = ExactSearch.new(
#     vocabulary: vocab,
#     model: model,
#     similarity_engine: engine
#   )
#   neighbors = search.find_nearest('hello', k: 5)
#
class Search
  # Min-heap for top-k selection
  class MinHeap
    def initialize(max_size)
      @max_size = max_size
      @heap = []
    end

    def push(item)
      @heap << item
      @heap.sort_by! { |i| i[:similarity] }
      @heap.shift if @heap.size > @max_size
    end

    def empty?
      @heap.empty?
    end

    def size
      @heap.size
    end

    def each(&)
      @heap.each(&)
    end

    def to_a
      @heap.dup
    end
  end

  # @return [Vocabulary]
  attr_reader :vocabulary

  # @return [EmbeddingModel]
  attr_reader :model

  # @return [SimilarityEngine]
  attr_reader :similarity_engine

  # @return [Boolean] Whether embeddings are preloaded
  attr_reader :embeddings_loaded

  # Create a new exact search
  #
  # @param vocabulary [Vocabulary] Word vocabulary
  # @param model [EmbeddingModel] Embedding provider
  # @param similarity_engine [SimilarityEngine] Similarity calculator
  # @param pre_normalize [Boolean] Pre-normalize vectors for faster similarity
  #
  def initialize(vocabulary:, model:, similarity_engine:, pre_normalize: false)
    @vocabulary = vocabulary
    @model = model
    @similarity_engine = similarity_engine
    @pre_normalize = pre_normalize

    @embedding_cache = {}
    @embeddings_loaded = false
  end

  # Find k nearest neighbors for a word
  #
  # @param query_word [String] Query word
  # @param k [Integer] Number of neighbors to return
  # @param exclude_self [Boolean] Exclude query word from results
  # @param min_similarity [Float] Minimum similarity threshold
  # @return [Array<Hash>] Array of {word, similarity, index}
  #
  def find_nearest(query_word, k: 10, exclude_self: true, min_similarity: 0.0)
    query_vec = get_embedding_for_word(query_word)
    return [] unless query_vec

    heap = MinHeap.new(k)

    @vocabulary.words.each do |word|
      next if exclude_self && word == query_word

      vec = get_embedding_for_word(word)
      next unless vec

      similarity = @similarity_engine.cosine(query_vec, vec)
      next if similarity < min_similarity

      index = @vocabulary.lookup(word)
      heap.push(word: word, similarity: similarity, index: index)
    end

    # Return sorted by similarity descending
    heap.to_a.sort_by { |r| -r[:similarity] }
  end

  # Find nearest neighbors for multiple words
  #
  # @param query_words [Array<String>] Query words
  # @param k [Integer] Number of neighbors per word
  # @return [Hash<String, Array<Hash>>] Word to results mapping
  #
  def find_nearest_batch(query_words, k: 10)
    query_words.each_with_object({}) do |word, results|
      results[word] = find_nearest(word, k: k)
    end
  end

  # Compute similarity between two words
  #
  # @param word1 [String] First word
  # @param word2 [String] Second word
  # @return [Float, nil] Similarity or nil if either word not found
  #
  def similarity(word1, word2)
    vec1 = get_embedding_for_word(word1)
    vec2 = get_embedding_for_word(word2)
    return nil unless vec1 && vec2

    @similarity_engine.cosine(vec1, vec2)
  end

  # Preload all embeddings into memory
  #
  # @return [self]
  #
  def preload_embeddings!
    all_indices = (0...@vocabulary.size).to_a
    embeddings = @model.get_embeddings(all_indices)

    @vocabulary.words.each_with_index do |word, i|
      @embedding_cache[word] = embeddings[i]
    end

    @embeddings_loaded = true
    self
  end

  # Clear embedding cache
  #
  # @return [self]
  #
  def clear_cache
    @embedding_cache.clear
    @embeddings_loaded = false
    self
  end

  # String representation
  #
  # @return [String]
  #
  def to_s
    "ExactSearch(vocab: #{@vocabulary.size}, loaded: #{@embeddings_loaded})"
  end
  alias inspect to_s

  private

  # Get embedding for a word (with caching)
  #
  # @param word [String] Word
  # @return [Array<Float>, nil]
  #
  def get_embedding_for_word(word)
    # Check cache first
    if @embedding_cache.key?(word)
      return @embedding_cache[word]
    end

    index = @vocabulary.lookup(word)
    return nil unless index

    vec = @model.get_embedding(index)
    return nil unless vec

    # Cache if not preloaded (to avoid repeated lookups)
    @embedding_cache[word] = vec unless @embeddings_loaded

    vec
  end
end
