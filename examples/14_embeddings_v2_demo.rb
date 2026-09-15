#!/usr/bin/env ruby
# frozen_string_literal: true

# Demonstration of the new Kotoshu Embeddings API v2.0
#
# This shows the clean, unified API for embedding-based similarity search.

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'kotoshu'

puts "=" * 80
puts "Kotoshu Embeddings API v2.0 - Clean Architecture Demo"
puts "=" * 80
puts

# ==============================================================================
# EXAMPLE 1: Simple One-Line Usage
# ==============================================================================

puts "EXAMPLE 1: Simple One-Line Usage"
puts "-" * 40
puts
puts "Code:"
puts "  pipeline = Kotoshu::Embeddings.from_cache(language: 'en')"
puts
puts "Note: Requires cached model. Run extract_vocabularies.rb first."
puts

# ==============================================================================
# EXAMPLE 2: Creating Components
# ==============================================================================

puts "EXAMPLE 2: Creating Components Manually"
puts "-" * 40
puts

# Create a vocabulary
vocab = Kotoshu::Embeddings::Vocabulary.from_words(
  %w[hello world king queen man woman semantic test example],
  language_code: "en"
)

puts "Created vocabulary with #{vocab.size} words"
puts "  Sample words: #{vocab.common_words(n: 5).join(', ')}"
puts

# Create a similarity engine
engine = Kotoshu::Embeddings::SimilarityEngine.new(pre_normalize: true)

puts "Created SimilarityEngine"
puts "  Cache stats: #{engine.cache_stats}"
puts

# Test similarity with mock vectors
vec1 = [1.0, 0.0, 0.0, 0.0, 0.0]
vec2 = [0.8, 0.2, 0.0, 0.0, 0.0]
similarity = engine.cosine(vec1, vec2)
puts "  Cosine similarity: #{similarity.round(4)}"
puts

# ==============================================================================
# EXAMPLE 3: LRU Cache
# ==============================================================================

puts "EXAMPLE 3: LRU Cache"
puts "-" * 40
puts

cache = Kotoshu::Embeddings::LruCache.new(max_size: 5)

# Add items
cache["a"] = 1
cache["b"] = 2
cache["c"] = 3
puts "Added 3 items to cache (max_size: 5)"

# Access items (a becomes most recently used)
cache["a"]
puts "Accessed 'a' (now most recently used)"

# Add more items (should evict least recently used)
cache["d"] = 4
cache["e"] = 5
cache["f"] = 6 # This should evict 'b' (LRU)

puts "Added 3 more items (evicts LRU)"
puts "  Cache size: #{cache.size}"
puts "  Keys (MRU to LRU): #{cache.keys.join(', ')}"
puts "  Stats: #{cache.stats}"
puts

# ==============================================================================
# EXAMPLE 4: Registry (Extensibility)
# ==============================================================================

puts "EXAMPLE 4: Registry (Extensibility)"
puts "-" * 40
puts

puts "Available models: #{Kotoshu::Embeddings::Registry.model_names.join(', ')}"
puts "Available engines: #{Kotoshu::Embeddings::Registry.engine_names.join(', ')}"
puts "Available vocabularies: #{Kotoshu::Embeddings::Registry.vocabulary_names.join(', ')}"
puts

# ==============================================================================
# EXAMPLE 5: Protocols (Interface Contracts)
# ==============================================================================

puts "EXAMPLE 5: Protocols (Interface Contracts)"
puts "-" * 40
puts

# Check that Vocabulary implements VocabularyProtocol
errors = Kotoshu::Embeddings::VocabularyProtocol.compliance_errors(Kotoshu::Embeddings::Vocabulary)
if errors.empty?
  puts "Vocabulary implements VocabularyProtocol ✓"
else
  puts "Vocabulary missing: #{errors.join(', ')}"
end

# Check that SimilarityEngine implements SimilarityEngineProtocol
errors = Kotoshu::Embeddings::SimilarityEngineProtocol.compliance_errors(Kotoshu::Embeddings::SimilarityEngine)
if errors.empty?
  puts "SimilarityEngine implements SimilarityEngineProtocol ✓"
else
  puts "SimilarityEngine missing: #{errors.join(', ')}"
end
puts

# ==============================================================================
# EXAMPLE 6: Pipeline Stats
# ==============================================================================

puts "EXAMPLE 6: Pipeline Statistics"
puts "-" * 40
puts

puts "Module version: #{Kotoshu::Embeddings::VERSION}"
puts "Default dimension: #{Kotoshu::Embeddings::DEFAULT_DIMENSION}"
puts "Max vocabulary size: #{Kotoshu::Embeddings::MAX_VOCABULARY_SIZE}"
puts

# ==============================================================================
# SUMMARY
# ==============================================================================

puts "=" * 80
puts "SUMMARY"
puts "=" * 80
puts
puts "✅ Clean API: Kotoshu::Embeddings.from_cache(language: 'en')"
puts "✅ Protocols: Interface contracts for components"
puts "✅ Registry: Plugin system for extensibility"
puts "✅ LRU Cache: Efficient caching with TTL support"
puts "✅ SimilarityEngine: Multiple similarity metrics"
puts "✅ No backward compatibility: Clean, fresh architecture"
puts
puts "Architecture v2.0 - Ready for production use!"
puts "=" * 80
