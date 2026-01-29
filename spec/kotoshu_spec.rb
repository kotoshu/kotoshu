# frozen_string_literal: true

RSpec.describe Kotoshu do
  it "has a version number" do
    expect(Kotoshu::VERSION).not_to be nil
  end

  it "does something useful (spellchecking)" do
    spellchecker = Kotoshu::Spellchecker.new(
      dictionary_path: "spec/fixtures/words.txt",
      dictionary_type: :plain_text,
      language: "en-US"
    )

    expect(spellchecker.correct?("hello")).to be true
    expect(spellchecker.correct?("helo")).to be false
  end
end
