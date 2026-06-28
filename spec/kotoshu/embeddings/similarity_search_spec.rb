# frozen_string_literal: true

require "kotoshu"

# Test model that returns simple embeddings without ONNX Runtime
class TestOnnxRuntimeModel
  attr_reader :language_code, :dimension, :onnx_path

  def initialize(embeddings:, language_code: "en", dimension: 5)
    @embeddings = embeddings
    @language_code = language_code
    @dimension = dimension
    @onnx_path = "test.onnx"
    @loaded = true
  end

  def loaded?
    @loaded
  end

  def ready?
    @loaded
  end

  def get_embedding(word_index)
    @embeddings.fetch(word_index, Array.new(@dimension, 0.0))
  end

  def get_embeddings(indices)
    indices.map { |idx| get_embedding(idx) }
  end
end

RSpec.describe Kotoshu::Embeddings::SimilaritySearch do
  let(:word_to_index) do
    {
      "hello" => 0,
      "world" => 1,
      "test" => 2,
      "king" => 3,
      "queen" => 4,
      "man" => 5,
      "woman" => 6
    }
  end

  let(:vocabulary) do
    Kotoshu::Embeddings::Vocabulary.new(
      language_code: "en",
      word_to_index: word_to_index
    )
  end

  let(:dimension) { 5 }

  let(:embeddings) do
    {
      0 => [1.0, 0.0, 0.0, 0.0, 0.0], # hello
      1 => [0.0, 1.0, 0.0, 0.0, 0.0], # world
      2 => [0.0, 0.0, 1.0, 0.0, 0.0], # test
      3 => [0.8, 0.2, 0.0, 0.5, 0.3], # king
      4 => [0.7, 0.3, 0.0, 0.6, 0.4], # queen (similar to king)
      5 => [0.9, 0.1, 0.0, 0.4, 0.2], # man (similar to king)
      6 => [0.6, 0.4, 0.0, 0.7, 0.5]  # woman (similar to queen)
    }
  end

  let(:model) do
    TestOnnxRuntimeModel.new(
      embeddings: embeddings,
      language_code: "en",
      dimension: dimension
    )
  end

  describe "#initialize" do
    it "creates similarity search with vocabulary and model" do
      search = described_class.new(vocabulary: vocabulary, model: model)
      expect(search.vocabulary).to eq(vocabulary)
      expect(search.model).to eq(model)
    end

    it "does not preload embeddings by default" do
      search = described_class.new(vocabulary: vocabulary, model: model)
      expect(search.embeddings_loaded).to be false
    end

    it "preloads embeddings when requested" do
      search = described_class.new(
        vocabulary: vocabulary,
        model: model,
        preload_embeddings: true
      )
      expect(search.embeddings_loaded).to be true
    end
  end

  describe "#cosine_similarity" do
    let(:search) { described_class.new(vocabulary: vocabulary, model: model) }

    it "computes similarity between two vectors" do
      vec1 = [1.0, 0.0, 0.0, 0.0, 0.0]
      vec2 = [1.0, 0.0, 0.0, 0.0, 0.0]
      expect(search.cosine_similarity(vec1, vec2)).to eq(1.0)
    end

    it "computes similarity for orthogonal vectors" do
      vec1 = [1.0, 0.0, 0.0, 0.0, 0.0]
      vec2 = [0.0, 1.0, 0.0, 0.0, 0.0]
      expect(search.cosine_similarity(vec1, vec2)).to eq(0.0)
    end

    it "computes similarity for opposite vectors" do
      vec1 = [1.0, 0.0, 0.0, 0.0, 0.0]
      vec2 = [-1.0, 0.0, 0.0, 0.0, 0.0]
      expect(search.cosine_similarity(vec1, vec2)).to eq(-1.0)
    end

    it "computes partial similarity" do
      vec1 = [1.0, 1.0, 0.0, 0.0, 0.0]
      vec2 = [1.0, 0.0, 0.0, 0.0, 0.0]
      expect(search.cosine_similarity(vec1, vec2)).to be_within(0.001).of(0.7071)
    end

    it "handles nil vectors" do
      # cosine_similarity returns 0.0 for nil, not nil
      expect(search.cosine_similarity(nil, [1.0, 0.0])).to eq(0.0)
      expect(search.cosine_similarity([1.0, 0.0], nil)).to eq(0.0)
    end
  end

  describe "#similarity" do
    let(:search) { described_class.new(vocabulary: vocabulary, model: model) }

    it "computes similarity between two words" do
      # King and queen should be similar (both royalty, similar embeddings)
      expect(search.similarity("king", "queen")).to be_within(0.01).of(0.98)
    end

    it "returns nil for unknown word" do
      expect(search.similarity("king", "unknownword")).to be_nil
    end

    it "returns 1.0 for identical words" do
      expect(search.similarity("king", "king")).to eq(1.0)
    end
  end

  describe "#find_nearest" do
    let(:search) { described_class.new(vocabulary: vocabulary, model: model) }

    it "finds nearest neighbors for a word" do
      neighbors = search.find_nearest("king", k: 3, exclude_self: false)
      expect(neighbors.length).to eq(3)
      expect(neighbors.first[:word]).to eq("king")
      expect(neighbors.first[:similarity]).to eq(1.0)
    end

    it "excludes the query word when exclude_self is true" do
      neighbors = search.find_nearest("king", k: 3, exclude_self: true)
      expect(neighbors.length).to eq(3)
      expect(neighbors.map { |n| n[:word] }).not_to include("king")
    end

    it "includes the query word when exclude_self is false" do
      neighbors = search.find_nearest("king", k: 4, exclude_self: false)
      expect(neighbors.map { |n| n[:word] }).to include("king")
    end

    it "filters by minimum similarity" do
      neighbors = search.find_nearest("king", k: 10, min_similarity: 0.95)
      expect(neighbors.all? { |n| n[:similarity] >= 0.95 }).to be true
    end

    it "returns empty array for unknown word" do
      neighbors = search.find_nearest("unknownword", k: 5)
      expect(neighbors).to be_empty
    end

    it "returns hashes with word and similarity keys" do
      neighbors = search.find_nearest("king", k: 1)
      expect(neighbors.first).to have_key(:word)
      expect(neighbors.first).to have_key(:similarity)
    end
  end

  describe "#find_nearest_batch" do
    let(:search) { described_class.new(vocabulary: vocabulary, model: model) }

    it "finds neighbors for multiple words" do
      results = search.find_nearest_batch(["king", "man"], k: 2)
      expect(results.keys).to contain_exactly("king", "man")
      expect(results["king"].length).to eq(2)
      expect(results["man"].length).to eq(2)
    end

    it "returns array of neighbors for each word" do
      results = search.find_nearest_batch(["king"], k: 3)
      expect(results["king"]).to be_an(Array)
      expect(results["king"].length).to eq(3)
    end
  end

  describe "#preload_embeddings!" do
    it "preloads all embeddings" do
      search = described_class.new(vocabulary: vocabulary, model: model)
      expect(search.embeddings_loaded).to be false

      result = search.preload_embeddings!

      expect(result).to be true
      expect(search.embeddings_loaded).to be true
      # Embeddings are stored in @embedding_matrix, indexed by word index
      matrix = search.instance_variable_get(:@embedding_matrix)
      expect(matrix).not_to be_nil
      expect(matrix.length).to eq(7)
    end
  end

  describe "#clear_cache" do
    it "clears the embedding cache" do
      search = described_class.new(vocabulary: vocabulary, model: model)
      search.preload_embeddings!

      expect(search.embeddings_loaded).to be true

      search.clear_cache

      expect(search.embeddings_loaded).to be false
      expect(search.instance_variable_get(:@embeddings_cache)).to be_nil
    end
  end

  describe "#to_s" do
    it "returns informative string representation" do
      search = described_class.new(vocabulary: vocabulary, model: model)
      str = search.to_s
      expect(str).to include("SimilaritySearch")
      expect(str).to include("7") # vocab_size
      expect(str).to include("false") # loaded status
    end
  end

  context "with preloaded embeddings" do
    let(:search) do
      described_class.new(
        vocabulary: vocabulary,
        model: model,
        preload_embeddings: true
      )
    end

    it "uses preloaded embeddings for search" do
      neighbors = search.find_nearest("king", k: 3)
      # "queen" should be most similar to "king"
      expect(neighbors.first[:word]).to eq("queen")
    end
  end
end
