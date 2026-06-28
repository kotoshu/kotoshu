# frozen_string_literal: true

require "kotoshu"

RSpec.describe Kotoshu::Embeddings::SimilarityEngine do
  describe "#initialize" do
    it "defaults to non-pre-normalized, norm-caching mode" do
      engine = described_class.new
      expect(engine).not_to be_pre_normalize
      expect(engine.normalization_required?).to be true
      expect(engine.cache_stats[:cache_size]).to eq(0)
    end

    it "honors pre_normalize: true" do
      engine = described_class.new(pre_normalize: true)
      expect(engine).to be_pre_normalize
      expect(engine.normalization_required?).to be false
    end

    it "honors cache_norms: false" do
      engine = described_class.new(cache_norms: false)
      expect(engine.cache_stats[:cache_size]).to eq(0)
    end
  end

  describe "#cosine" do
    let(:engine) { described_class.new }

    it "returns 1.0 for identical non-zero vectors" do
      v = [1.0, 2.0, 3.0]
      expect(engine.cosine(v, v)).to be_within(1e-9).of(1.0)
    end

    it "returns 1.0 for parallel vectors regardless of magnitude" do
      expect(engine.cosine([1.0, 0.0], [5.0, 0.0])).to be_within(1e-9).of(1.0)
    end

    it "returns 0.0 for orthogonal vectors" do
      expect(engine.cosine([1.0, 0.0], [0.0, 1.0])).to be_within(1e-9).of(0.0)
    end

    it "returns -1.0 for opposite vectors" do
      expect(engine.cosine([1.0, 0.0], [-1.0, 0.0])).to be_within(1e-9).of(-1.0)
    end

    it "returns 0.0 for a zero-magnitude vector" do
      expect(engine.cosine([0.0, 0.0], [1.0, 0.0])).to eq(0.0)
      expect(engine.cosine([1.0, 0.0], [0.0, 0.0])).to eq(0.0)
    end

    it "returns 0.0 for nil or empty inputs" do
      expect(engine.cosine(nil, [1.0])).to eq(0.0)
      expect(engine.cosine([1.0], nil)).to eq(0.0)
      expect(engine.cosine([], [1.0])).to eq(0.0)
      expect(engine.cosine([1.0], [])).to eq(0.0)
    end

    it "computes cosine for a 3D example" do
      # Known: cos([1,0,1], [0,1,1]) = 1 / (sqrt(2) * sqrt(2)) = 0.5
      result = engine.cosine([1.0, 0.0, 1.0], [0.0, 1.0, 1.0])
      expect(result).to be_within(1e-9).of(0.5)
    end

    it "is symmetric in its arguments" do
      v1 = [1.0, 2.0, 3.0]
      v2 = [4.0, 5.0, 6.0]
      expect(engine.cosine(v1, v2)).to be_within(1e-12).of(engine.cosine(v2, v1))
    end
  end

  describe "dimension mismatch" do
    let(:engine) { described_class.new }

    it "raises ArgumentError from cosine" do
      expect { engine.cosine([1.0, 0.0, 0.0], [1.0, 1.0]) }
        .to raise_error(ArgumentError, /dimension mismatch/)
    end

    it "raises ArgumentError from dot_product" do
      expect { engine.dot_product([1.0, 0.0, 0.0], [1.0, 1.0]) }
        .to raise_error(ArgumentError, /dimension mismatch/)
    end

    it "raises ArgumentError from euclidean" do
      expect { engine.euclidean([1.0, 0.0, 0.0], [1.0, 1.0]) }
        .to raise_error(ArgumentError, /dimension mismatch/)
    end

    it "raises ArgumentError from manhattan" do
      expect { engine.manhattan([1.0, 0.0, 0.0], [1.0, 1.0]) }
        .to raise_error(ArgumentError, /dimension mismatch/)
    end

    it "does not raise when one operand is empty (early-return path)" do
      expect(engine.cosine([], [1.0])).to eq(0.0)
      expect(engine.cosine([1.0], [])).to eq(0.0)
    end
  end

  describe "#dot_product" do
    let(:engine) { described_class.new }

    it "computes the dot product" do
      expect(engine.dot_product([1.0, 2.0, 3.0], [4.0, 5.0, 6.0])).to eq(32.0)
    end

    it "returns 0.0 for empty or nil input" do
      expect(engine.dot_product([], [1.0])).to eq(0.0)
      expect(engine.dot_product(nil, [1.0])).to eq(0.0)
    end
  end

  describe "#euclidean" do
    let(:engine) { described_class.new }

    it "returns 0.0 for identical vectors" do
      v = [1.0, 2.0, 3.0]
      expect(engine.euclidean(v, v)).to eq(0.0)
    end

    it "computes the Euclidean distance" do
      expect(engine.euclidean([0.0, 0.0], [3.0, 4.0])).to eq(5.0)
    end

    it "returns 0.0 for empty input" do
      expect(engine.euclidean([], [1.0])).to eq(0.0)
    end
  end

  describe "#manhattan" do
    let(:engine) { described_class.new }

    it "computes the Manhattan (L1) distance" do
      expect(engine.manhattan([0.0, 0.0], [3.0, 4.0])).to eq(7.0)
    end

    it "returns 0.0 for empty input" do
      expect(engine.manhattan([], [1.0])).to eq(0.0)
    end
  end

  describe "#pre_normalize" do
    let(:engine) { described_class.new }

    it "scales a vector to unit length" do
      normalized = engine.pre_normalize([3.0, 4.0])
      expect(normalized.first).to be_within(1e-9).of(0.6)
      expect(normalized.last).to be_within(1e-9).of(0.8)
    end

    it "returns a copy of an empty/nil input unchanged" do
      expect(engine.pre_normalize([])).to eq([])
      expect(engine.pre_normalize(nil)).to eq(nil)
    end

    it "returns a copy of a zero-magnitude vector unchanged" do
      expect(engine.pre_normalize([0.0, 0.0])).to eq([0.0, 0.0])
    end

    it "returns a new array (does not mutate input)" do
      input = [3.0, 4.0]
      original = input.dup
      engine.pre_normalize(input)
      expect(input).to eq(original)
    end
  end

  describe "#is_normalized?" do
    let(:engine) { described_class.new }

    it "returns true for a unit-length vector" do
      expect(engine.is_normalized?([1.0, 0.0, 0.0])).to be true
    end

    it "returns false for a non-unit vector" do
      expect(engine.is_normalized?([2.0, 0.0])).to be false
    end

    it "returns true for empty or nil input" do
      expect(engine.is_normalized?([])).to be true
      expect(engine.is_normalized?(nil)).to be true
    end
  end

  describe "#normalize_and_compute" do
    it "uses dot product when pre_normalize is on (fast path)" do
      engine = described_class.new(pre_normalize: true)
      # Pre-normalized vectors: cosine == dot product
      v1 = [1.0, 0.0]
      v2 = [1.0, 0.0]
      expect(engine.normalize_and_compute(v1, v2)).to be_within(1e-9).of(1.0)
    end

    it "delegates to cosine when pre_normalize is off" do
      engine = described_class.new(pre_normalize: false)
      v1 = [2.0, 0.0] # not normalized
      v2 = [2.0, 0.0]
      expect(engine.normalize_and_compute(v1, v2)).to be_within(1e-9).of(1.0)
    end

    it "returns 0.0 for empty input" do
      engine = described_class.new
      expect(engine.normalize_and_compute([], [1.0])).to eq(0.0)
    end
  end

  describe "#cosine_batch" do
    it "computes cosine for each pair" do
      engine = described_class.new
      pairs = [
        [[1.0, 0.0], [1.0, 0.0]],   # 1.0
        [[1.0, 0.0], [0.0, 1.0]],   # 0.0
        [[1.0, 0.0], [-1.0, 0.0]]   # -1.0
      ]
      results = engine.cosine_batch(pairs)
      expect(results.size).to eq(3)
      expect(results[0]).to be_within(1e-9).of(1.0)
      expect(results[1]).to be_within(1e-9).of(0.0)
      expect(results[2]).to be_within(1e-9).of(-1.0)
    end
  end

  describe "#compute_all_pairs" do
    it "produces a symmetric similarity matrix with 1.0 on the diagonal" do
      engine = described_class.new
      vectors = [
        [1.0, 0.0],
        [0.0, 1.0],
        [1.0, 1.0]
      ]
      matrix = engine.compute_all_pairs(vectors)
      expect(matrix.length).to eq(3)
      matrix.each_with_index do |row, i|
        expect(row.length).to eq(3)
        expect(row[i]).to be_within(1e-9).of(1.0)
      end
      # Symmetry
      (0...3).each do |i|
        (0...3).each do |j|
          expect(matrix[i][j]).to be_within(1e-12).of(matrix[j][i])
        end
      end
    end
  end

  describe "norm cache" do
    it "records a miss on first computation and a hit on repeat" do
      engine = described_class.new(cache_norms: true)
      v1 = [1.0, 2.0, 3.0]
      v2 = [4.0, 5.0, 6.0] # distinct object from v1 so the second
      # get_norm call within one cosine() also misses
      engine.cosine(v1, v2) # 2 misses, 0 hits
      misses_after_first = engine.cache_stats[:misses]
      hits_after_first = engine.cache_stats[:hits]
      expect(misses_after_first).to eq(2)
      expect(hits_after_first).to eq(0)

      engine.cosine(v1, v2) # 2 cache hits
      expect(engine.cache_stats[:hits]).to eq(2)
      expect(engine.cache_stats[:misses]).to eq(misses_after_first)
    end

    it "is disabled when cache_norms: false" do
      engine = described_class.new(cache_norms: false)
      v = [1.0, 2.0, 3.0]
      engine.cosine(v, v)
      engine.cosine(v, v)
      expect(engine.cache_stats[:cache_size]).to eq(0)
      expect(engine.cache_stats[:hits]).to eq(0)
      expect(engine.cache_stats[:misses]).to eq(0)
    end

    it "tracks hit_rate as hits / (hits + misses)" do
      engine = described_class.new(cache_norms: true)
      v = [1.0, 0.0]
      engine.cosine(v, v)
      engine.cosine(v, v)
      stats = engine.cache_stats
      total = stats[:hits] + stats[:misses]
      expect(stats[:hit_rate]).to be_within(1e-9).of(stats[:hits].to_f / total)
    end
  end

  describe "#clear_cache" do
    it "resets hit/miss counters and empties the cache" do
      engine = described_class.new(cache_norms: true)
      v = [1.0, 2.0, 3.0]
      engine.cosine(v, v)
      expect(engine.cache_stats[:cache_size]).to be > 0

      engine.clear_cache
      stats = engine.cache_stats
      expect(stats[:hits]).to eq(0)
      expect(stats[:misses]).to eq(0)
      expect(stats[:cache_size]).to eq(0)
    end

    it "returns self for chaining" do
      engine = described_class.new
      expect(engine.clear_cache).to be(engine)
    end
  end

  describe "#cache_stats" do
    it "includes hits, misses, hit_rate, and cache_size keys" do
      stats = described_class.new.cache_stats
      expect(stats).to include(:hits, :misses, :hit_rate, :cache_size)
    end

    it "reports 0.0 hit_rate when nothing has been computed" do
      expect(described_class.new.cache_stats[:hit_rate]).to eq(0.0)
    end
  end
end
