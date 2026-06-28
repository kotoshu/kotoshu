# frozen_string_literal: true

require "kotoshu"

# Direct spec for Suggestions::Strategies::KeyboardProximityStrategy.
#
# The strategy generates keyboard-neighbor substitutions for the input
# word, then matches them against the dictionary. It filters by an
# edit-distance cap (default 2) and a typo-similarity floor (default
# 0.70). The hardcoded layout is US QWERTY; per-language layout
# selection lives elsewhere (Keyboard::Registry).
#
# The strategy had no direct spec — only exercised indirectly via
# CompositeStrategy and integration tests.
RSpec.describe Kotoshu::Suggestions::Strategies::KeyboardProximityStrategy do
  # Words chosen so adjacent-key substitutions land inside the
  # dictionary. On QWERTY, "h" neighbours "g", "j", "b", "n", "y".
  let(:dictionary) do
    Kotoshu::Dictionary::PlainText.from_words(
      %w[hello jello help jelp hell yello helds helps],
      language_code: "en"
    )
  end

  let(:strategy) { described_class.new }

  let(:context_for) do
    ->(word) { Kotoshu::Suggestions::Context.new(word: word, dictionary: dictionary) }
  end

  describe "#initialize" do
    it "defaults name to :keyboard_proximity" do
      expect(described_class.new.name).to eq(:keyboard_proximity)
    end

    it "is enabled by default" do
      expect(described_class.new).to be_enabled
    end

    it "honours an explicit name override" do
      expect(described_class.new(name: :kbprox).name).to eq(:kbprox)
    end
  end

  describe "KEYBOARD_LAYOUT constant" do
    it "is frozen so external mutation is impossible" do
      expect(described_class::KEYBOARD_LAYOUT).to be_frozen
    end

    it "documents the QWERTY 'h' neighbours used by the smoke tests below" do
      # Pin the layout so the smoke assertions below don't silently
      # start testing nothing if the layout changes.
      expect(described_class::KEYBOARD_LAYOUT["h"]).to contain_exactly("g", "j", "b", "n", "y")
    end

    it "lists space as having no neighbours" do
      expect(described_class::KEYBOARD_LAYOUT[" "]).to eq([])
    end
  end

  describe "#generate" do
    it "returns a SuggestionSet of Suggestion objects" do
      result = strategy.generate(context_for.call("hello"))
      expect(result).to be_a(Kotoshu::Suggestions::SuggestionSet)
      expect(result.to_a).to all(be_a(Kotoshu::Suggestions::Suggestion))
    end

    it "tags every suggestion with source = 'keyboard_proximity'" do
      result = strategy.generate(context_for.call("hello"))
      result.to_a.each do |s|
        expect(s.source).to eq("keyboard_proximity")
      end
    end

    it "excludes the input word from the result set" do
      result = strategy.generate(context_for.call("hello"))
      expect(result.to_words).not_to include("hello")
    end

    it "stamps original_length metadata on each suggestion" do
      result = strategy.generate(context_for.call("hello"))
      result.to_a.each do |s|
        expect(s.metadata[:original_length]).to eq(5)
      end
    end

    it "returns an empty set for a nil word" do
      # The variant generator short-circuits on nil/empty input.
      result = strategy.generate(context_for.call(""))
      expect(result).to be_empty
    end

    it "honours a stricter max_distance by returning at most the same number of suggestions" do
      loose = described_class.new(max_distance: 2)
      strict = described_class.new(max_distance: 1)
      loose_result = loose.generate(context_for.call("hello"))
      strict_result = strict.generate(context_for.call("hello"))
      expect(strict_result.size).to be <= loose_result.size
    end

    it "respects the max_distance cap: no suggestion exceeds the cap" do
      capped = described_class.new(max_distance: 1)
      result = capped.generate(context_for.call("hello"))
      result.to_a.each do |s|
        expect(s.distance).to be <= 1
      end
    end

    it "honours a stricter min_similarity by returning at most the same number of suggestions" do
      loose = described_class.new(min_similarity: 0.1)
      strict = described_class.new(min_similarity: 0.95)
      loose_result = loose.generate(context_for.call("hello"))
      strict_result = strict.generate(context_for.call("hello"))
      expect(strict_result.size).to be <= loose_result.size
    end
  end

  describe "smoke: typo correction via QWERTY neighbours" do
    # 'h' → 'j' is a single adjacent-key substitution on QWERTY.
    # 'hello' should produce 'jello' as a candidate (among others).
    it "finds single-key typo corrections for 'hello'" do
      result = strategy.generate(context_for.call("hello"))
      # We don't pin ranking — just that at least one adjacent-key
      # substitution is found. 'jello' and 'yello' are both in the
      # dictionary and reachable via 'h' → 'j' / 'h' → 'y'.
      expected_neighbours = %w[jello yello]
      expect(result.to_words & expected_neighbours).not_to be_empty
    end

    it "finds single-key typo corrections for 'help'" do
      result = strategy.generate(context_for.call("help"))
      # 'h' → 'j' gives 'jelp' which is in the dictionary.
      expect(result.to_words).to include("jelp")
    end
  end

  describe "#handles?" do
    it "is true for a word not in the dictionary" do
      expect(strategy.handles?(context_for.call("xyzzy"))).to be true
    end

    it "is false for a word in the dictionary" do
      expect(strategy.handles?(context_for.call("hello"))).to be false
    end

    it "is false when the strategy is disabled" do
      disabled = described_class.new(enabled: false)
      expect(disabled.handles?(context_for.call("xyzzy"))).to be false
    end
  end

  describe "ranking" do
    it "sorts suggestions by ascending distance" do
      result = strategy.generate(context_for.call("hello"))
      distances = result.to_a.map(&:distance)
      expect(distances).to eq(distances.sort)
    end
  end
end
