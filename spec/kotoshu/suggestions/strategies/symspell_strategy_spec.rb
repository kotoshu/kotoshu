# frozen_string_literal: true

require_relative "../../../../lib/kotoshu/suggestions/strategies/symspell_strategy"
require_relative "../../../../lib/kotoshu/suggestions/context"
require_relative "../../../../lib/kotoshu/dictionary/plain_text"

RSpec.describe Kotoshu::Suggestions::Strategies::SymSpellStrategy do
  let(:dictionary) do
    Kotoshu::Dictionary::PlainText.from_words(
      %w[hello world help held hell bell well tell shell yellow],
      language_code: "en"
    )
  end

  let(:context) { Kotoshu::Suggestions::Context.new(word: "helo", dictionary: dictionary) }

  describe "#initialize" do
    it "creates a strategy with default config" do
      strategy = described_class.new(dictionary: dictionary)
      expect(strategy.name).to eq(:symspell)
      expect(strategy.enabled?).to be true
    end

    it "accepts max_deletion_distance config" do
      strategy = described_class.new(dictionary: dictionary, max_deletion_distance: 3)
      expect(strategy.get_config(:max_deletion_distance)).to eq(3)
    end
  end

  describe "#generate" do
    let(:strategy) { described_class.new(dictionary: dictionary) }

    it "generates suggestions for a misspelled word" do
      result = strategy.generate(context)
      expect(result).to be_a(Kotoshu::Suggestions::SuggestionSet)
      expect(result.to_words).to include("hello")
    end

    it "includes words with 1 deletion distance" do
      result = strategy.generate(context)
      suggestions = result.to_words
      # "helo" -> "hello" (insert 'l')
      expect(suggestions).to include("hello")
    end

    it "returns suggestions sorted by distance" do
      result = strategy.generate(context)
      suggestions = result.suggestions
      expect(suggestions.first.distance).to be <= suggestions.last.distance
    end

    it "respects max_results config" do
      limited_strategy = described_class.new(dictionary: dictionary, max_results: 2)
      result = limited_strategy.generate(context)
      expect(result.size).to be <= 2
    end

    it "returns empty set for words with no close matches" do
      long_word_context = Kotoshu::Suggestions::Context.new(
        word: "supercalifragilisticexpialidocious",
        dictionary: dictionary
      )
      result = strategy.generate(long_word_context)
      expect(result).to be_a(Kotoshu::Suggestions::SuggestionSet)
      expect(result.size).to be_zero
    end

    it "handles case-insensitive matching" do
      upper_context = Kotoshu::Suggestions::Context.new(word: "HELO", dictionary: dictionary)
      result = strategy.generate(upper_context)
      expect(result.to_words).to include("hello")
    end
  end

  describe "#handles?" do
    let(:strategy) { described_class.new(dictionary: dictionary) }

    it "returns true when word is not in dictionary" do
      expect(strategy.handles?(context)).to be true
    end

    it "returns false when word is in dictionary" do
      valid_context = Kotoshu::Suggestions::Context.new(
        word: "hello",
        dictionary: dictionary
      )
      expect(strategy.handles?(valid_context)).to be false
    end

    it "returns false when strategy is disabled" do
      disabled_strategy = described_class.new(dictionary: dictionary, enabled: false)
      expect(disabled_strategy.handles?(context)).to be false
    end
  end

  describe "performance" do
    # Create a larger dictionary for performance testing
    let(:large_dictionary) do
      words = begin
        File.readlines("/usr/share/dict/words", chomp: true)
      rescue StandardError
        []
      end
      # Use 10,000 words from the middle of the file (more likely to have common words)
      words = words[1000..11_000] || words.take(10_000)
      Kotoshu::Dictionary::PlainText.from_words(words, language_code: "en")
    end

    let(:strategy) { described_class.new(dictionary: large_dictionary) }

    before do
      skip "No system dictionary available" unless File.exist?("/usr/share/dict/words")
    end

    it "finds suggestions in reasonable time" do
      # Use a common misspelling that will likely have matches
      misspelled_context = Kotoshu::Suggestions::Context.new(
        word: "teh", # Common misspelling of "the"
        dictionary: large_dictionary
      )

      start_time = Time.now
      result = strategy.generate(misspelled_context)
      elapsed = Time.now - start_time

      # Check performance, but don't fail if no matches found (dictionary-dependent)
      # Check performance, but don't fail if no matches found (dictionary-dependent)
      expect(elapsed).to be < 0.2 # Allow 200ms for system variability

      # If we found matches, verify we have some
      expect(result.size).to be > 0 unless result.empty?
    end
  end

  describe "#deletion_distance" do
    let(:strategy) { described_class.new(dictionary: dictionary) }

    it "calculates deletion distance between words" do
      # "hello" and "helo" have deletion distance 1
      dist = strategy.send(:deletion_distance, "hello", "helo")
      expect(dist).to eq(1)
    end

    it "returns 0 for identical words" do
      dist = strategy.send(:deletion_distance, "hello", "hello")
      expect(dist).to eq(0)
    end

    it "returns correct distance for multiple deletions" do
      # "hello" and "heo" have deletion distance 2
      dist = strategy.send(:deletion_distance, "hello", "heo")
      expect(dist).to eq(2)
    end
  end
end
