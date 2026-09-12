# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Spellchecker typo-retrieval integration" do
  let(:dictionary) do
    Kotoshu::Dictionary::PlainText.from_words(
      %w[hello hell help held well tell], language_code: "en"
    )
  end

  let(:config) { Kotoshu::Configuration.new }

  let(:spellchecker) { Kotoshu::Spellchecker.new(dictionary: dictionary, config: config) }

  it "is a passthrough when the layer is not opted in (the default)" do
    expect(config.typo_retrieval).to be(false)

    base = spellchecker.generator.generate("helo", max_suggestions: 5)
    via_suggest = spellchecker.suggest("helo", max_suggestions: 5)

    expect(via_suggest.map(&:word)).to eq(base.map(&:word))
    expect(via_suggest.map(&:confidence)).to eq(base.map(&:confidence))
    expect(via_suggest.map(&:source)).to eq(base.map(&:source))
  end

  it "degrades to the passthrough when the engine cannot resolve" do
    config.typo_retrieval = true
    # No native extension or artifacts in this environment: the
    # resolver answers nil, the merge returns the base set verbatim.
    base = spellchecker.generator.generate("helo", max_suggestions: 5)
    via_suggest = spellchecker.suggest("helo", max_suggestions: 5)
    expect(via_suggest.map(&:word)).to eq(base.map(&:word))
  end
end
