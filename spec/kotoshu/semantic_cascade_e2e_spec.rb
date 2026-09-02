# frozen_string_literal: true

require "kotoshu"

# End-to-end spec for the confidence cascade on the real semantic path
# (TODO.impl/70). Tagged :onnx so it only runs with ONNX_TESTS=1, and
# skips gracefully when onnxruntime or the cached English model is
# unavailable. The decision itself is covered without ONNX in
# spec/kotoshu/suggestions/semantic_cascade_spec.rb — this file proves
# the composite actually skips the real SemanticStrategy.
RSpec.describe "Semantic confidence cascade", :onnx do
  let(:language_code) { "en" }

  # nil (skip the spec) when the cached model cannot be constructed —
  # e.g. an incompatible local cache format.
  let(:semantic) do
    Kotoshu::Suggestions::Strategies::SemanticStrategy.new(
      language_code: language_code,
      preload_embeddings: false
    )
  rescue StandardError
    nil
  end

  let(:dictionary) do
    Kotoshu::Dictionary::PlainText.from_words(
      %w[hello help held hell shell yellow], language_code: language_code
    )
  end

  let(:context) do
    Kotoshu::Suggestions::Context.new(
      word: "helo", dictionary: dictionary, max_results: 10
    )
  end

  def composite(threshold:)
    Kotoshu::Suggestions::Strategies::CompositeStrategy.new(
      name: :cascade_pipeline,
      strategies: [
        Kotoshu::Suggestions::Strategies::EditDistanceStrategy.new,
        semantic
      ],
      semantic_cascade_threshold: threshold
    )
  end

  before do
    skip "onnxruntime not loaded" unless Kotoshu::Models::OnnxModel::ONNX_LOADED
    skip "ONNX model not cached for #{language_code}" if semantic.nil? || !semantic.search
  end

  after { Kotoshu::Metrics.disable }

  it "merges semantic candidates at the default threshold (always rerank)" do
    Kotoshu::Metrics.enable

    result = composite(threshold: 1.0).generate(context)

    expect(result).to be_a(Kotoshu::Suggestions::SuggestionSet)
    # The semantic strategy ran alongside the traditional ones (whether
    # it contributed unique words depends on the embedding space, so
    # assert the run via the skip counter staying at zero).
    expect(Kotoshu::Metrics.stats[:semantic_cascade_skips]).to eq(0)
  end

  it "skips the rerank at threshold 0.0 and counts the skip" do
    Kotoshu::Metrics.enable

    result = composite(threshold: 0.0).generate(context)

    # No semantic-source suggestions made it into the pool...
    expect(result.from_source(:semantic)).to be_empty
    # ...and the traditional candidates are still there.
    expect(result.size).to be_positive
    expect(Kotoshu::Metrics.stats[:semantic_cascade_skips]).to eq(1)
  end

  it "matches the traditional-only result exactly when never reranking" do
    traditional_only = Kotoshu::Suggestions::Strategies::CompositeStrategy.new(
      name: :traditional,
      strategies: [Kotoshu::Suggestions::Strategies::EditDistanceStrategy.new]
    )

    expect(composite(threshold: 0.0).generate(context).to_words)
      .to eq(traditional_only.generate(context).to_words)
  end

  it "skips at a mid threshold when the traditional pool is confident" do
    # "helo" sits at edit distance 1 from several dictionary words, so
    # the traditional pool is confident; a 0.9 threshold must skip.
    confident = composite(threshold: 0.9).generate(context)

    expect(confident.from_source(:semantic)).to be_empty
  end
end
