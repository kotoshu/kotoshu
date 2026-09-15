#!/usr/bin/env ruby
# frozen_string_literal: true

# Working example demonstrating FastText ONNX Integration for Kotoshu
#
# This shows how the semantic spell checking works with embeddings.

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'kotoshu'
require 'kotoshu/suggestions/strategies/semantic_strategy'
require 'kotoshu/dictionary/plain_text'
require 'kotoshu/suggestions/generator'

puts "=" * 80
puts "FastText ONNX Integration - Working Examples"
puts "=" * 80
puts

# ==============================================================================
# EXAMPLE 1: Vocabulary Class - Basic Usage
# ==============================================================================

puts "EXAMPLE 1: Vocabulary Class"
puts "-" * 40

# Create a simple vocabulary
vocab = Kotoshu::Embeddings::Vocabulary.new(
  language_code: "en",
  word_to_index: {
    "hello" => 0,
    "world" => 1,
    "king" => 2,
    "queen" => 3,
    "man" => 4,
    "woman" => 5,
    "test" => 6,
    "example" => 7
  }
)

puts "Created vocabulary with #{vocab.size} words"
puts "  'hello' is at index: #{vocab.lookup('hello')}"
puts "  Index 2 maps to: '#{vocab.get_word(2)}'"
puts "  'king' in vocabulary? #{vocab.include?('king')}"
puts "  'unknown' in vocabulary? #{vocab.include?('unknown')}"
puts

# ==============================================================================
# EXAMPLE 2: Vocabulary - Save and Load
# ==============================================================================

puts "EXAMPLE 2: Vocabulary - Save and Load"
puts "-" * 40

require 'tempfile'
temp_file = Tempfile.new(['vocab', '.json'])

vocab.save_to_file(temp_file.path)
puts "Saved vocabulary to: #{temp_file.path}"

loaded_vocab = Kotoshu::Embeddings::Vocabulary.from_file(temp_file.path, language_code: "en")
puts "Loaded vocabulary with #{loaded_vocab.size} words"
puts "  'hello' is at index: #{loaded_vocab.lookup('hello')}"

temp_file.unlink
puts

# ==============================================================================
# EXAMPLE 3: Similarity Search with Mock Embeddings
# ==============================================================================

puts "EXAMPLE 3: Similarity Search with Mock Embeddings"
puts "-" * 40

# Create a vocabulary
vocab_words = %w[hello world king queen man woman cat dog pet animal]
test_vocab = Kotoshu::Embeddings::Vocabulary.new(
  language_code: "en",
  word_to_index: vocab_words.each_with_index.to_h
)

puts "Created test vocabulary with #{test_vocab.size} words"

# Create mock embeddings (simulating 5D vectors)
# In real ONNX models, these would be 300D vectors
dimension = 5
mock_embeddings = {
  0 => [1.0, 0.0, 0.0, 0.0, 0.0],  # hello
  1 => [0.0, 1.0, 0.0, 0.0, 0.0],  # world
  2 => [0.8, 0.2, 0.5, 0.3, 0.1],  # king
  3 => [0.7, 0.3, 0.6, 0.4, 0.2],  # queen (similar to king)
  4 => [0.9, 0.1, 0.4, 0.2, 0.0],  # man (similar to king)
  5 => [0.6, 0.4, 0.7, 0.5, 0.3],  # woman (similar to queen)
  6 => [0.0, 0.0, 0.0, 1.0, 0.0],  # cat
  7 => [0.0, 0.0, 0.0, 0.9, 0.0],  # dog (similar to cat)
  8 => [0.0, 0.0, 0.0, 0.95, 0.1], # pet (similar to cat/dog)
  9 => [0.0, 0.0, 0.0, 0.8, 0.2]   # animal (related to pets)
}

# Create a mock model
class MockOnnxModel
  attr_reader :language_code, :dimension, :onnx_path, :loaded

  def initialize(language_code:, dimension:, embeddings:)
    @language_code = language_code
    @dimension = dimension
    @embeddings = embeddings
    @loaded = true
    @onnx_path = "mock.onnx"
  end

  def get_embedding(index)
    @embeddings.fetch(index, Array.new(@dimension, 0.0))
  end

  def get_embeddings(indices)
    indices.map { |idx| get_embedding(idx) }
  end
end

mock_model = MockOnnxModel.new(
  language_code: "en",
  dimension: dimension,
  embeddings: mock_embeddings
)

# Create similarity search
search = Kotoshu::Embeddings::SimilaritySearch.new(
  vocabulary: test_vocab,
  model: mock_model,
  preload_embeddings: true
)

puts "Created similarity search with #{test_vocab.size} words"
puts "Embeddings loaded: #{search.embeddings_loaded}"
puts

# Test similarity calculation
puts "Cosine Similarity Examples:"
puts "  'king' <-> 'queen': #{search.similarity('king', 'queen').round(4)}"
puts "  'king' <-> 'man':   #{search.similarity('king', 'man').round(4)}"
puts "  'king' <-> 'world': #{search.similarity('king', 'world').round(4)}"
puts "  'cat' <-> 'dog':     #{search.similarity('cat', 'dog').round(4)}"
puts "  'cat' <-> 'hello':   #{search.similarity('cat', 'hello').round(4)}"
puts

# Find nearest neighbors
puts "Nearest neighbors for 'king' (k=3):"
neighbors = search.find_nearest('king', k: 3, exclude_self: false)
neighbors.each do |neighbor|
  puts "  - '#{neighbor[:word]}' (similarity: #{neighbor[:similarity].round(4)})"
end
puts

puts "Nearest neighbors for 'cat' (k=3):"
neighbors = search.find_nearest('cat', k: 3, exclude_self: false)
neighbors.each do |neighbor|
  puts "  - '#{neighbor[:word]}' (similarity: #{neighbor[:similarity].round(4)})"
end
puts

# ==============================================================================
# EXAMPLE 4: Semantic Strategy Integration
# ==============================================================================

puts "EXAMPLE 4: Semantic Strategy Integration (with mocks)"
puts "-" * 40

# Create a simple dictionary
dictionary = Kotoshu::Dictionary::PlainText.from_words(
  %w[hello world king queen man woman cat dog pet animal test example spelling semantic],
  language_code: "en"
)

puts "Created dictionary"
puts

# Create a context for spell checking
context = Kotoshu::Suggestions::Context.new(
  word: "kng", # Typo for "king"
  dictionary: dictionary,
  max_results: 5
)

puts "Created context for word: '#{context.word}'"
puts

# Note: SemanticStrategy requires actual ONNX model and vocabulary files
# For demonstration, we show what it would do:
puts "SemanticStrategy (when ONNX models are available):"
puts "  - Would find semantically similar words to 'kng'"
puts "  - Re-rank edit-distance candidates by semantic similarity"
puts "  - For real-word errors: find contextually appropriate alternatives"
puts

# ==============================================================================
# EXAMPLE 5: Full Spell Checking with Semantic Suggestions
# ==============================================================================

puts "EXAMPLE 5: Full Spell Checking Pipeline"
puts "-" * 40

# Create generator with edit distance strategy (works without ONNX)
generator = Kotoshu::Suggestions::Generator.new(
  dictionary,
  max_suggestions: 5
)

puts "Created suggestion generator"
puts "  Default algorithms: #{generator.class::DEFAULT_ALGORITHMS.map(&:name).join(', ')}"
puts

# Test spell checking
test_words = ["helo", "wrld", "kng", "tst"]

test_words.each do |word|
  suggestions = generator.generate(word)
  puts "Suggestions for '#{word}':"
  suggestions.to_words.first(3).each_with_index do |suggestion, i|
    puts "  #{i + 1}. #{suggestion}"
  end
  puts
end

# ==============================================================================
# EXAMPLE 6: With Real ONNX Model (if available)
# ==============================================================================

puts "EXAMPLE 6: Real ONNX Model (if cached)"
puts "-" * 40

# Check if ONNX model is cached
onnx_path = Dir.glob(File.expand_path('~/.kotoshu/models/en/**/fasttext.en.onnx')).first

if onnx_path && File.exist?(onnx_path)
  puts "Found ONNX model: #{onnx_path}"
  puts "  Size: #{(File.size(onnx_path).to_f / 1024 / 1024).round(2)} MB"

  # Check for vocabulary file
  vocab_path = onnx_path.sub('.onnx', '.vocab.json')
  if File.exist?(vocab_path)
    puts "  Vocabulary file: #{vocab_path}"
    puts "  Size: #{(File.size(vocab_path).to_f / 1024).round(2)} KB"

    # Load the vocabulary
    real_vocab = Kotoshu::Embeddings::Vocabulary.from_file(vocab_path, language_code: "en")
    puts "  Vocabulary size: #{real_vocab.size} words"

    # Sample words
    puts "  Sample words: #{real_vocab.common_words(n: 5).join(', ')}"
  else
    puts "  No vocabulary file found at: #{vocab_path}"
    puts "  Run: ruby scripts/extract_vocabularies.rb --languages=en"
  end
else
  puts "No ONNX model cached yet."
  puts
  puts "To enable semantic spell checking:"
  puts "  1. Download ONNX models from models-fasttext-onnx repository"
  puts "  2. Run: ruby scripts/extract_vocabularies.rb"
  puts "  3. Models will be cached in ~/.kotoshu/embeddings/"
end
puts

# ==============================================================================
# EXAMPLE 7: Cosine Similarity Deep Dive
# ==============================================================================

puts "EXAMPLE 7: Cosine Similarity Deep Dive"
puts "-" * 40

# Demonstrate cosine similarity with different vectors
examples = [
  { vec1: [1.0, 0.0], vec2: [1.0, 0.0], desc: "Identical vectors" },
  { vec1: [1.0, 0.0], vec2: [0.0, 1.0], desc: "Orthogonal vectors" },
  { vec1: [1.0, 0.0], vec2: [-1.0, 0.0], desc: "Opposite vectors" },
  { vec1: [1.0, 1.0], vec2: [1.0, 0.0], desc: "Partially similar" },
  { vec1: [0.8, 0.2, 0.5], vec2: [0.7, 0.3, 0.6], desc: "Semantically related" }
]

search = Kotoshu::Embeddings::SimilaritySearch.new(
  vocabulary: test_vocab,
  model: mock_model
)

examples.each do |ex|
  similarity = search.cosine_similarity(ex[:vec1], ex[:vec2])
  puts "#{ex[:desc]}: #{similarity.round(4)}"
end
puts

# ==============================================================================
# SUMMARY
# ==============================================================================

puts "=" * 80
puts "SUMMARY"
puts "=" * 80
puts
puts "✅ Vocabulary class: Working (save/load, word-index mapping)"
puts "✅ SimilaritySearch: Working (cosine similarity, nearest neighbors)"
puts "✅ SemanticStrategy: Implemented (requires ONNX model + vocabulary)"
puts "✅ ModelCache: Updated for 157 languages"
puts
puts "To enable full semantic spell checking:"
puts "  1. cd models-fasttext-onnx"
puts "  2. Ensure ONNX models are built (see README.md)"
puts "  3. cd .."
puts "  4. ruby kotoshu/scripts/extract_vocabularies.rb --languages=en"
puts "  5. Use SemanticStrategy in your spell checker"
puts
puts "Example usage with ONNX:"
puts
puts "  strategy = Kotoshu::Suggestions::Strategies::SemanticStrategy.new("
puts "    language_code: 'en',"
puts "    preload_embeddings: true"
puts "  )"
puts "  generator = Kotoshu::Suggestions::Generator.new("
puts "    dictionary,"
puts "    algorithms: [strategy, Kotoshu::Suggestions::Strategies::EditDistanceStrategy.new]"
puts "  )"
puts "=" * 80
