# frozen_string_literal: true

# Kotoshu Embeddings Architecture v2 - Implementation Plan
#
# This document outlines the architecture improvements for the FastText ONNX
# embeddings integration, focusing on performance, usability, and extensibility.

## Executive Summary

The current implementation has critical performance issues (O(n) nearest neighbor
search, no batch inference) and architectural limitations (tight coupling, no
abstractions). This plan addresses these issues while maintaining backward
compatibility and avoiding technical debt.

## Goals

1. **Performance**: 10-100x speedup for nearest neighbor queries
2. **Usability**: Single-line initialization, clear error messages
3. **Extensibility**: Plugin system for models and similarity engines
4. **Correctness**: No technical debt, well-tested
5. **Efficiency**: Memory and compute optimizations

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Public API (Simple)                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│  EmbeddingPipeline.from_cache(language: 'en')  # One line to get started   │
│  EmbeddingPipeline.new(                        # Full configuration          │
│    vocabulary: vocab,                                                │
│    model: model,                                                     │
│    similarity_engine: engine,                                         │
│    index_strategy: :exact | :ann  # exact=brute, ann=FAISS/HNSW     │
│  )                                                                   │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Abstraction Layer                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│  EmbeddingModel Protocol          SimilarityEngine Protocol                 │
│  ┌─────────────────────┐        ┌─────────────────────┐                  │
│  │ get_embedding(idx)  │◄───────│ cosine(vec1, vec2) │                  │
│  │ get_embeddings(idxs) │        │ dot(vec1, vec2)    │                  │
│  │ dimension            │        │ euclidean(vec1, v2) │                  │
│  │ language_code        │        │ pre_normalize(v)    │                  │
│  └─────────────────────┘        └─────────────────────┘                  │
│           │                               │                                 │
│           │                               │                                 │
│           ▼                               ▼                                 │
│  ┌─────────────────────┐        ┌─────────────────────┐                  │
│  │ OnnxRuntimeModel    │        │ CosineSimilarity    │                  │
│  │ FaissIndexModel     │        │ DotProductSimilarity │                  │
│  │ InMemoryModel       │        │ EuclideanSimilarity │                  │
│  └─────────────────────┘        └─────────────────────┘                  │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      Search Optimization Layer                              │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐              │
│  │ ExactSearch     │  │ AnnSearch       │  │ HybridSearch    │              │
│  │ O(n) brute force│  │ O(log n) FAISS │  │ Exact + ANN     │              │
│  │ + Pre-normalized│  │ + HNSW fallback │  │ + Caching       │              │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘              │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Vocabulary Layer                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│  Vocabulary Protocol                                                       │
│  ┌─────────────────────┐        ┌─────────────────────┐                    │
│  │ lookup(word)        │        │ include?(word)      │                    │
│  │ get_word(index)     │        │ size                │                    │
│  │ words (enumerator)  │        │ each(&block)        │                    │
│  └─────────────────────┘        └─────────────────────┘                    │
│                                                                             │
│  Implementations: JsonVocabulary, CachedVocabulary, ShardedVocabulary       │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Phase 1: Core Abstractions (Week 1)

### 1.1 Define Protocols (Interfaces)

Create protocol modules that define contracts:

```ruby
# lib/kotoshu/embeddings/protocols/embedding_model.rb
module Kotoshu::Embeddings::Protocols
  module EmbeddingModel
    extend Protocol

    required_methods :get_embedding, :get_embeddings, :dimension, :language_code, :loaded?
    required_methods :load!, :unload!, :ready?

    # Optional: batch support
    optional_methods :get_embeddings_batch, :batch_size
  end
end

# lib/kotoshu/embeddings/protocols/similarity_engine.rb
module Kotoshu::Embeddings::Protocols
  module SimilarityEngine
    extend Protocol

    required_methods :cosine, :dot_product, :euclidean
    required_methods :pre_normalize, :normalize_and_compute
  end
end

# lib/kotoshu/embeddings/protocols/vocabulary.rb
module Kotoshu::Embeddings::Protocols
  module Vocabulary
    extend Protocol

    required_methods :lookup, :get_word, :include?, :size, :words
    required_methods :valid_index?, :common_words, :to_h
  end
end
```

### 1.2 Refactor Existing Classes

Update classes to explicitly implement protocols:

```ruby
# lib/kotoshu/embeddings/onnx_runtime_model.rb
class OnnxRuntimeModel
  include Kotoshu::Embeddings::Protocols::EmbeddingModel

  def self.from_cache(language_code, cache: nil)
    cache ||= Cache::ModelCache.default
    path = cache.find_model(language_code, :onnx)
    from_file(path, language_code: language_code) if path
  end
end

# lib/kotoshu/embeddings/vocabulary.rb
class Vocabulary
  include Kotoshu::Embeddings::Protocols::Vocabulary

  def self.from_file(path, language_code: nil)
    # ... existing implementation
  end
end
```

### 1.3 Add Result Objects for Error Handling

```ruby
# lib/kotoshu/embeddings/results/embedding_result.rb
module Kotoshu::Embeddings::Results
  class EmbeddingResult
    attr_reader :vector, :word, :index, :error

    def self.success(vector, word: nil, index: nil)
      new(vector: vector, word: word, index: index, error: nil)
    end

    def self.failure(message, word: nil)
      new(vector: nil, word: word, error: message)
    end

    def success?
      @error.nil?
    end

    def failure?
      !@error.nil?
    end
  end

  class SimilarityResult
    attr_reader :word, :similarity, :rank

    def initialize(word:, similarity:, rank:)
      @word = word
      @similarity = similarity
      @rank = rank
    end
  end
end
```

## Phase 2: Performance Optimizations (Week 2)

### 2.1 Implement True LRU Cache

```ruby
# lib/kotoshu/embeddings/caching/lru_cache.rb
module Kotoshu::Embeddings::Caching
  class LruCache
    attr_reader :max_size, :hits, :misses

    def initialize(max_size: 1000)
      @cache = {}  # word -> vector
      @order = ::Hash.new  # word -> timestamp (using keys' insertion order)
      @max_size = max_size
      @hits = 0
      @misses = 0
    end

    def fetch(key)
      if @cache.key?(key)
        @hits += 1
        # Move to end (most recently used)
        @order.delete(key)
        @order[key] = Time.now
        @cache[key]
      else
        @misses += 1
        nil
      end
    end

    def []=(key, value)
      # Evict LRU item if at capacity
      if @cache.size >= @max_size && !@cache.key?(key)
        lru_key = @order.min_by { |k, v| v }.first
        @cache.delete(lru_key)
        @order.delete(lru_key)
      end

      @cache[key] = value
      @order[key] = Time.now
      value
    end

    def clear
      @cache.clear
      @order.clear
      self
    end

    def size
      @cache.size
    end
  end
end
```

### 2.2 Batch Inference Support

```ruby
# lib/kotoshu/embeddings/onnx_runtime_model.rb (updated)
class OnnxRuntimeModel
  BATCH_SIZE = 32

  def get_embeddings_batch(indices)
    return [] if indices.empty?

    # Process in batches for memory efficiency
    results = indices.each_slice(BATCH_SIZE).flat_map do |batch|
      run_batch_inference(batch)
    end

    results
  end

  private

  def run_batch_inference(indices)
    # ONNX Runtime supports batch inference
    # Input shape: [batch_size, 1]
    # Output shape: [batch_size, dimension]
    inputs = indices.map { |idx| [idx] }
    input_tensor = create_input_tensor(inputs)

    outputs = @session.run(
      [@output_name],
      { @input_name => input_tensor }
    )

    # Extract and return each embedding
    output_tensor = outputs.first
    (0...indices.length).map { |i| output_tensor[i, true].to_a }
  end
end
```

### 2.3 Pre-normalized Vectors with Caching

```ruby
# lib/kotoshu/embeddings/similarity_engine.rb
module Kotoshu::Embeddings
  class SimilarityEngine
    attr_reader :normalize_cache

    def initialize(pre_normalize: true)
      @normalize_cache = {}
      @pre_normalize = pre_normalize
    end

    def cosine(vec1, vec2)
      return 0.0 if vec1.nil? || vec2.nil?

      norm1 = get_norm(vec1)
      norm2 = get_norm(vec2)

      return 0.0 if norm1.zero? || norm2.zero?

      dot = vec1.zip(vec2).sum { |a, b| a * b }
      dot / (norm1 * norm2)
    end

    def normalized_cosine(vec1, vec2)
      return 0.0 if vec1.nil? || vec2.nil?

      # Already normalized: just compute dot product
      vec1.zip(vec2).sum { |a, b| a * b }
    end

    private

    def get_norm(vec)
      if @normalize_cache.key?(vec.object_id)
        @normalize_cache[vec.object_id]
      elsif @pre_normalize
        norm = Math.sqrt(vec.sum { |x| x * x })
        @normalize_cache[vec.object_id] = norm
        norm
      else
        Math.sqrt(vec.sum { |x| x * x })
      end
    end
  end
end
```

### 2.4 Efficient Nearest Neighbor (Heap-based Selection)

```ruby
# lib/kotoshu/embeddings/search/exact_search.rb
module Kotoshu::Embeddings::Search
  class ExactSearch
    def initialize(vocabulary:, embedding_provider:, similarity_engine:, pre_normalize: true)
      @vocabulary = vocabulary
      @provider = embedding_provider
      @engine = similarity_engine
      @pre_normalize = pre_normalize
    end

    def find_nearest(query_word, k: 10, exclude_self: true, min_similarity: 0.0)
      query_vec = @provider.get_embedding_for_word(query_word)
      return [] unless query_vec

      # Use a min-heap to track top-k results efficiently
      heap = MinHeap.new(k)

      @vocabulary.words.each do |word|
        next if exclude_self && word == query_word

        vec = @provider.get_embedding_for_word(word)
        next unless vec

        similarity = @engine.cosine(query_vec, vec)
        next if similarity < min_similarity

        heap.push({ word: word, similarity: similarity })
      end

      # Sort by similarity descending
      heap.to_a.sort_by { |r| -r[:similarity] }
    end

    private

    # Simple min-heap implementation for top-k selection
    class MinHeap
      def initialize(max_size)
        @heap = []
        @max_size = max_size
      end

      def push(item)
        @heap << item
        @heap.sort_by! { |i| i[:similarity] }
        @heap.shift if @heap.size > @max_size
      end

      def to_a
        @heap
      end
    end
  end
end
```

## Phase 3: Approximate Nearest Neighbor (ANN) (Week 3)

### 3.1 FAISS Index Wrapper

```ruby
# lib/kotoshu/embeddings/index/faiss_index.rb
module Kotoshu::Embeddings::Index
  class FaissIndex
    def initialize(dimension:, metric: :cosine)
      require 'faiss'  # Optional dependency

      @dimension = dimension
      @metric = metric == :cosine ? faiss.METRIC_INNER_PRODUCT : faiss.METRIC_L2

      # Create index
      quantizer = faiss.IndexFlatIP.new(@dimension) if metric == :cosine
      quantizer = faiss.IndexFlatL2.new(@dimension) if metric == :euclidean

      @index = faiss.IndexIDMap.new(quantizer)
      @id_to_word = {}
      @word_to_id = {}
    end

    def add_word(word, vector)
      id = next_id
      @index.add_with_ids([vector], [id])
      @id_to_word[id] = word
      @word_to_id[word] = id
    end

    def build!
      @index.nprobe = 16  # Optimization parameter
      self
    end

    def search(query_vector, k: 10)
      distances, ids = @index.search([query_vector], k)

      results = []
      (0...k).each do |i|
        id = ids[0][i]
        break if id == -1  # No more results

        distance = distances[0][i]
        # Convert inner product to cosine similarity (0-1 range)
        similarity = @metric == faiss.METRIC_INNER_PRODUCT ?
          (distance + 1) / 2 : # Normalize to 0-1
          1.0 / (1.0 + distance)  # Convert L2 to similarity-like

        results << {
          word: @id_to_word[id],
          similarity: similarity,
          distance: distance
        }
      end

      results
    end
  end
end
```

### 3.2 HNSWlib Alternative (Pure Ruby Fallback)

```ruby
# lib/kotoshu/embeddings/index/hnsw_index.rb
module Kotoshu::Embeddings::Index
  # Pure Ruby HNSW implementation for when FAISS is unavailable
  class HnswIndex
    def initialize(dimension:, m: 16, ef_construction: 200, metric: :cosine)
      @dimension = dimension
      @m = m
      @ef_construction = ef_construction
      @metric = metric

      # Graph structure
      @graph = []  # Array of arrays (neighbors)
      @vectors = []
      @labels = []

      # Entry point
      @entry_point = nil
    end

    def add_word(word, vector)
      @vectors << vector
      @labels << word
      @graph[@vectors.length - 1] = []
    end

    def search(query, k: 10, ef: 10)
      # Hierarchical search implementation
      # ... (complex but pure Ruby)
    end
  end
end
```

### 3.3 ANN Search Orchestrator

```ruby
# lib/kotoshu/embeddings/search/ann_search.rb
module Kotoshu::Embeddings::Search
  class AnnSearch
    STRATEGIES = {
      exact: ExactSearch,
      faiss: ->(opts) { FaissIndex.new(**opts) },
      hnsw: ->(opts) { HnswIndex.new(**opts) },
      hybrid: ->(opts) { HybridSearch.new(**opts) }
    }

    def self.create(strategy: :auto, **options)
      strategy = choose_strategy(strategy, **options)
      STRATEGIES[strategy].new(**options)
    end

    def self.choose_strategy(strategy, vocabulary_size: nil, **)
      return strategy if strategy != :auto

      # Auto-select based on vocabulary size
      return :exact if vocabulary_size && vocabulary_size < 10_000
      return :faiss if faiss_available? && vocabulary_size >= 10_000
      return :hnsw if hnsw_available?
      :exact
    end

    def self.faiss_available?
      defined?(Faiss)
    end

    def self.hnsw_available?
      defined?(HnswIndex)
    end
  end
end
```

## Phase 4: Unified API (Week 4)

### 4.1 EmbeddingPipeline Facade

```ruby
# lib/kotoshu/embeddings/embedding_pipeline.rb
module Kotoshu::Embeddings
  class EmbeddingPipeline
    attr_reader :vocabulary, :model, :search, :similarity_engine

    # Simple one-line initialization
    def self.from_cache(language:, cache: nil, preload: false, index: :auto)
      cache ||= Cache::ModelCache.default

      vocab_path = cache.find_vocab(language)
      model_path = cache.find_model(language, :onnx)

      raise "No cached model for language: #{language}" unless vocab_path && model_path

      from_files(
        vocab_path: vocab_path,
        model_path: model_path,
        language: language,
        preload: preload,
        index: index
      )
    end

    # Full configuration initialization
    def self.from_files(vocab_path:, model_path:, language:, preload: false, index: :auto)
      vocab = Vocabulary.from_file(vocab_path, language_code: language)
      model = OnnxRuntimeModel.from_file(model_path, language_code: language)
      model.load! if preload

      new(
        vocabulary: vocab,
        model: model,
        preload: preload,
        index: index
      )
    end

    def initialize(vocabulary:, model:, preload: false, index: :auto)
      @vocabulary = vocabulary
      @model = model
      @similarity_engine = SimilarityEngine.new

      # Choose search strategy
      search_strategy = Search::AnnSearch.create(
        strategy: index,
        vocabulary: vocabulary,
        embedding_provider: self,
        similarity_engine: @similarity_engine,
        vocabulary_size: vocabulary.size
      )

      @search = search_strategy

      preload_embeddings! if preload
    end

    def find_nearest(word, k: 10, exclude_self: true)
      @search.find_nearest(word, k: k, exclude_self: exclude_self)
    end

    def similarity(word1, word2)
      vec1 = get_embedding_for_word(word1)
      vec2 = get_embedding_for_word(word2)
      return nil unless vec1 && vec2

      @similarity_engine.cosine(vec1, vec2)
    end

    def preload_embeddings!
      @model.preload_embeddings! if @model.respond_to?(:preload_embeddings!)
      self
    end

    def unload!
      @model.unload!
      self
    end

    private

    def get_embedding_for_word(word)
      return nil unless @vocabulary.include?(word)

      index = @vocabulary.lookup(word)
      @model.get_embedding(index)
    end
  end
end
```

### 4.2 Simple Usage Examples

```ruby
# Example 1: Simple usage (one line)
pipeline = Kotoshu::Embeddings::EmbeddingPipeline.from_cache(language: 'en')

# Example 2: Full configuration
pipeline = Kotoshu::Embeddings::EmbeddingPipeline.new(
  vocabulary: vocab,
  model: model,
  preload: true,
  index: :faiss  # Use FAISS for large vocabularies
)

# Example 3: Finding similar words
neighbors = pipeline.find_nearest('semantic', k: 5)
neighbors.each do |result|
  puts "#{result[:word]}: #{result[:similarity].round(4)}"
end

# Example 4: Computing similarity
sim = pipeline.similarity('king', 'queen')
puts "Similarity: #{sim.round(4)}"
```

## Phase 5: Registry and Extensibility (Week 5)

### 5.1 Model Registry

```ruby
# lib/kotoshu/embeddings/registry.rb
module Kotoshu::Embeddings
  class Registry
    @models = {}
    @engines = {}
    @vocabularies = {}

    class << self
      attr_reader :models, :engines, :vocabularies

      def register_model(name, klass)
        @models[name] = klass
        klass.extend(Protocols::EmbeddingModel)
      end

      def register_engine(name, klass)
        @engines[name] = klass
      end

      def register_vocabulary(name, klass)
        @vocabularies[name] = klass
        klass.extend(Protocols::Vocabulary)
      end

      def model(name)
        @models[name]
      end

      def engine(name)
        @engines[name]
      end

      def vocabulary(name)
        @vocabularies[name]
      end
    end
  end

  # Register built-in implementations
  Registry.register_model(:onnx, OnnxRuntimeModel)
  Registry.register_model(:memory, InMemoryModel)
  Registry.register_model(:faiss, FaissIndexModel)

  Registry.register_engine(:cosine, SimilarityEngine)
  Registry.register_engine(:dot, DotProductEngine)

  Registry.register_vocabulary(:json, Vocabulary)
  Registry.register_vocabulary(:cached, CachedVocabulary)
end
```

### 5.2 Custom Model Example

```ruby
# User can create custom models easily
class MyCustomModel
  include Kotoshu::Embeddings::Protocols::EmbeddingModel

  def initialize(vectors:)
    @vectors = vectors
  end

  def get_embedding(index)
    @vectors[index]
  end

  def get_embeddings(indices)
    indices.map { |i| @vectors[i] }
  end

  def dimension
    @vectors.first.length
  end

  def language_code
    'custom'
  end

  def loaded?
    true
  end

  def load!
    self
  end

  def unload!
    self
  end

  def ready?
    true
  end
end

# Register and use
Kotoshu::Embeddings::Registry.register_model(:my_custom, MyCustomModel)

model = Kotoshu::Embeddings::Registry.model(:my_custom).new(vectors: my_vectors)
```

## Phase 6: Testing Strategy

### 6.1 Test Coverage Requirements

| Component | Unit Tests | Integration Tests | Performance Tests |
|-----------|------------|-------------------|------------------|
| Protocols | Contract tests | - | - |
| Vocabulary | 100% | Cache integration | Large vocab load |
| Models | 100% | ONNX inference | Batch throughput |
| Similarity | 100% | Numerical accuracy | Precision benchmarks |
| Search | 100% | FAISS/HNSW integration | Recall/speed benchmarks |
| Pipeline | 90% | Full pipeline E2E | Latency under load |

### 6.2 Performance Benchmarks

```ruby
# spec/kotoshu/embeddings/performance_spec.rb
RSpec.describe "Performance benchmarks" do
  let(:pipeline) { EmbeddingPipeline.from_cache(language: 'en', preload: true) }

  it "finds nearest neighbor in under 10ms for 10K vocab" do
    allow(pipeline.vocabulary).to receive(:size).and_return(10_000)

    measure {
      pipeline.find_nearest('test', k: 5)
    }.should be < 0.01  # 10ms
  end

  it "computes similarity in under 1ms" do
    measure {
      pipeline.similarity('hello', 'world')
    }.should be < 0.001  # 1ms
  end

  it "handles 1000 concurrent queries" do
    Benchmark.bm(10) do |x|
      x.report("sequential") { 1000.times { pipeline.find_nearest('test', k: 3) } }
    end
  end
end
```

## Implementation Order

| Phase | Priority | Changes | Estimated Effort |
|-------|----------|---------|------------------|
| 1 | Critical | Protocols & abstractions | 2 days |
| 2 | High | LRU cache, batch inference | 2 days |
| 3 | High | ANN indexing (FAISS/HNSW) | 3 days |
| 4 | Medium | Unified API (EmbeddingPipeline) | 1 day |
| 5 | Low | Registry & extensibility | 1 day |
| 6 | Medium | Performance tests | 1 day |

## Backward Compatibility

All changes maintain backward compatibility:
- Existing `Vocabulary` class still works
- Existing `OnnxRuntimeModel` still works
- `SimilaritySearch` becomes a thin wrapper around new architecture
- Add deprecation warnings for old APIs

## Files to Create

```
lib/kotoshu/embeddings/
├── protocol.rb                    # Base protocol module
├── protocols/
│   ├── embedding_model.rb
│   ├── similarity_engine.rb
│   └── vocabulary.rb
├── caching/
│   └── lru_cache.rb
├── similarity_engine.rb           # Renamed from cosine_similarity.rb
├── results/
│   ├── embedding_result.rb
│   └── similarity_result.rb
├── index/
│   ├── base_index.rb
│   ├── faiss_index.rb
│   └── hnsw_index.rb
├── search/
│   ├── base_search.rb
│   ├── exact_search.rb
│   ├── ann_search.rb
│   └── hybrid_search.rb
├── embedding_pipeline.rb          # NEW: Unified API facade
└── registry.rb                     # NEW: Plugin system
```

## Files to Modify

```
lib/kotoshu/embeddings/
├── vocabulary.rb          # Implement Vocabulary protocol
├── onnx_runtime_model.rb  # Implement EmbeddingModel protocol, add batch support
└── similarity_search.rb   # Refactor to use new architecture
```

## Summary

This architecture provides:
- **10-100x speedup** via ANN indexing for large vocabularies
- **Clean API** via EmbeddingPipeline facade
- **Extensibility** via registry and protocols
- **Reliability** via proper error handling and caching
- **Performance** via batch inference and optimized similarity
