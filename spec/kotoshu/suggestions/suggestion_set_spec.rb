# frozen_string_literal: true

RSpec.describe Kotoshu::Suggestions::SuggestionSet do
  let(:suggestions) do
    [
      Kotoshu::Suggestions::Suggestion.new(word: "hello", distance: 1, confidence: 0.9, source: :edit_distance),
      Kotoshu::Suggestions::Suggestion.new(word: "help",   distance: 2, confidence: 0.7, source: :ngram),
      Kotoshu::Suggestions::Suggestion.new(word: "hell",   distance: 1, confidence: 0.8, source: :edit_distance)
    ]
  end

  let(:set) { described_class.new(suggestions) }

  describe "#to_a consistency with #suggestions" do
    it "returns Array<Suggestion>, the same shape as #suggestions" do
      expect(set.to_a).to all(be_a(Kotoshu::Suggestions::Suggestion))
    end

    it "yields Suggestion objects to Enumerable methods" do
      words = set.map(&:word)
      expect(words).to eq(%w[hello hell help])
    end

    it "returns the same count as #suggestions" do
      expect(set.to_a.size).to eq(set.suggestions.size)
    end
  end

  describe "#to_hashes" do
    it "returns Array<Hash>" do
      expect(set.to_hashes).to all(be_a(Hash))
    end

    it "includes word, distance, confidence, source keys" do
      first = set.to_hashes.first
      expect(first.keys).to include("word", "distance", "confidence", "source")
    end
  end

  describe "#as_json" do
    it "delegates to #to_hashes (serialization shape)" do
      expect(set.as_json).to eq(set.to_hashes)
    end
  end

  describe "#to_words" do
    it "returns Array<String>" do
      expect(set.to_words).to all(be_a(String))
    end

    it "is aliased as #words" do
      expect(set.words).to eq(set.to_words)
    end
  end

  describe "#initialize" do
    it "sorts by combined score on construction (best first)" do
      constructed = described_class.new(suggestions)
      expect(constructed.first.word).to eq("hello")
    end

    it "dedupes case-insensitively on construction" do
      dupes = [
        Kotoshu::Suggestions::Suggestion.new(word: "Hello", distance: 1, confidence: 0.9),
        Kotoshu::Suggestions::Suggestion.new(word: "hello", distance: 1, confidence: 0.9)
      ]
      constructed = described_class.new(dupes)
      expect(constructed.size).to eq(1)
    end

    it "enforces max_size on construction" do
      constructed = described_class.new(suggestions, max_size: 2)
      expect(constructed.size).to eq(2)
      expect(constructed.max_size).to eq(2)
    end

    it "defaults max_size to 10" do
      expect(described_class.new([]).max_size).to eq(10)
    end
  end

  describe "#add" do
    it "appends a suggestion and returns self for chaining" do
      new_suggestion = Kotoshu::Suggestions::Suggestion.new(word: "hallo", distance: 2, confidence: 0.6)
      result = set.add(new_suggestion)
      expect(result).to be(set)
      expect(set.to_words).to include("hallo")
    end

    it "re-sorts after adding (best first)" do
      worse = Kotoshu::Suggestions::Suggestion.new(word: "xyzzy", distance: 5, confidence: 0.1)
      set.add(worse)
      expect(set.last.word).to eq("xyzzy")
    end

    it "respects max_size after add" do
      small = described_class.new([], max_size: 1)
      small.add(Kotoshu::Suggestions::Suggestion.new(word: "a", distance: 1, confidence: 0.9))
      small.add(Kotoshu::Suggestions::Suggestion.new(word: "b", distance: 1, confidence: 0.5))
      expect(small.size).to eq(1)
      expect(small.first.word).to eq("a")
    end

    it "is aliased as <<" do
      s = Kotoshu::Suggestions::Suggestion.new(word: "held", distance: 1, confidence: 0.8)
      set << s
      expect(set.to_words).to include("held")
    end
  end

  describe "#concat" do
    it "appends multiple suggestions and returns self" do
      more = [
        Kotoshu::Suggestions::Suggestion.new(word: "hey",     distance: 2, confidence: 0.7),
        Kotoshu::Suggestions::Suggestion.new(word: "helmet",  distance: 3, confidence: 0.5)
      ]
      result = set.concat(more)
      expect(result).to be(set)
      expect(set.size).to eq(5)
    end

    it "respects max_size after concat" do
      small = described_class.new([], max_size: 2)
      small.concat(suggestions)
      expect(small.size).to eq(2)
    end
  end

  describe "#merge!" do
    it "absorbs another set's suggestions" do
      other = described_class.new([
                                    Kotoshu::Suggestions::Suggestion.new(word: "yellow", distance: 3, confidence: 0.6)
                                  ])
      set.merge!(other)
      expect(set.to_words).to include("yellow")
    end

    it "returns self" do
      other = described_class.empty
      expect(set.merge!(other)).to be(set)
    end
  end

  describe "#from_source" do
    it "returns a new SuggestionSet filtered by source" do
      filtered = set.from_source(:edit_distance)
      expect(filtered).to be_a(Kotoshu::Suggestions::SuggestionSet)
      expect(filtered.to_words).to eq(%w[hello hell])
    end

    it "accepts string sources (normalizes Symbol/String)" do
      filtered = set.from_source("ngram")
      expect(filtered.to_words).to eq(%w[help])
    end

    it "returns an empty set when no suggestions match" do
      filtered = set.from_source(:semantic)
      expect(filtered).to be_empty
    end

    it "does not mutate the receiver" do
      original_size = set.size
      set.from_source(:ngram)
      expect(set.size).to eq(original_size)
    end
  end

  describe "#high_confidence" do
    it "returns suggestions with confidence >= 0.8" do
      high = set.high_confidence
      expect(high.to_words).to include("hello", "hell")
      expect(high.to_words).not_to include("help")
    end

    it "returns a new SuggestionSet" do
      expect(set.high_confidence).to be_a(Kotoshu::Suggestions::SuggestionSet)
    end
  end

  describe "#low_confidence" do
    it "returns suggestions with confidence < 0.5" do
      with_low = described_class.new([
                                       Kotoshu::Suggestions::Suggestion.new(word: "good", distance: 1, confidence: 0.9),
                                       Kotoshu::Suggestions::Suggestion.new(word: "risky", distance: 4, confidence: 0.3)
                                     ])
      low = with_low.low_confidence
      expect(low.to_words).to eq(%w[risky])
    end

    it "returns a new SuggestionSet" do
      expect(set.low_confidence).to be_a(Kotoshu::Suggestions::SuggestionSet)
    end
  end

  describe "#within_distance" do
    it "filters by inclusive distance range" do
      filtered = set.within_distance(min_distance: 0, max_distance: 1)
      expect(filtered.to_words).to include("hello", "hell")
      expect(filtered.to_words).not_to include("help")
    end

    it "returns a new SuggestionSet" do
      expect(set.within_distance(max_distance: 5)).to be_a(Kotoshu::Suggestions::SuggestionSet)
    end

    it "returns an empty set when nothing matches" do
      expect(set.within_distance(min_distance: 10, max_distance: 20)).to be_empty
    end
  end

  describe "#include? / #has_word?" do
    it "returns true when the word is present (case-insensitive)" do
      expect(set.include?("hello")).to be true
      expect(set.include?("HELLO")).to be true
    end

    it "returns false when the word is absent" do
      expect(set.include?("world")).to be false
    end

    it "is aliased as has_word?" do
      expect(set.has_word?("hello")).to be true
    end
  end

  describe "#find_word" do
    it "returns the matching Suggestion (case-insensitive)" do
      found = set.find_word("HELLO")
      expect(found).to be_a(Kotoshu::Suggestions::Suggestion)
      expect(found.word).to eq("hello")
    end

    it "returns nil when not found" do
      expect(set.find_word("missing")).to be_nil
    end
  end

  describe "#top" do
    it "returns the first N suggestions as Array<Suggestion>" do
      top_two = set.top(2)
      expect(top_two).to be_an(Array)
      expect(top_two.size).to eq(2)
      expect(top_two.first.word).to eq("hello")
    end

    it "returns fewer than N when the set is smaller" do
      expect(set.top(100).size).to eq(set.size)
    end
  end

  describe "#first / #last" do
    it "#first returns the best suggestion (highest combined score)" do
      expect(set.first).to be_a(Kotoshu::Suggestions::Suggestion)
      expect(set.first.word).to eq("hello")
    end

    it "#last returns the worst suggestion" do
      expect(set.last.word).to eq("help")
    end

    it "returns nil for #first on an empty set" do
      expect(described_class.empty.first).to be_nil
    end

    it "returns nil for #last on an empty set" do
      expect(described_class.empty.last).to be_nil
    end
  end

  describe "#empty? / #size" do
    it "reports empty? true on a fresh .empty set" do
      expect(described_class.empty).to be_empty
    end

    it "reports empty? false after add" do
      s = described_class.empty
      s.add(Kotoshu::Suggestions::Suggestion.new(word: "x", distance: 1, confidence: 0.5))
      expect(s).not_to be_empty
    end

    it "#size, #count, #length all agree" do
      expect(set.size).to eq(set.count)
      expect(set.size).to eq(set.length)
    end
  end

  describe "#each" do
    it "yields Suggestion objects when a block is given" do
      yielded = []
      set.each { |s| yielded << s }
      expect(yielded).to all(be_a(Kotoshu::Suggestions::Suggestion))
      expect(yielded.size).to eq(set.size)
    end

    it "returns an Enumerator when no block is given" do
      expect(set.each).to be_an(Enumerator)
    end
  end

  describe "#unique" do
    it "returns a new SuggestionSet with case-insensitive unique words" do
      with_dupes = described_class.new([
                                         Kotoshu::Suggestions::Suggestion.new(word: "Hello", distance: 1, confidence: 0.9),
                                         Kotoshu::Suggestions::Suggestion.new(word: "hello", distance: 1, confidence: 0.9)
                                       ])
      # Constructor already dedupes; verify unique is idempotent on deduped sets
      unique = with_dupes.unique
      expect(unique).to be_a(Kotoshu::Suggestions::SuggestionSet)
      expect(unique.size).to eq(with_dupes.size)
    end

    it "does not mutate the receiver" do
      original_size = set.size
      set.unique
      expect(set.size).to eq(original_size)
    end
  end

  describe ".empty" do
    it "returns an empty SuggestionSet" do
      expect(described_class.empty).to be_empty
      expect(described_class.empty).to be_a(Kotoshu::Suggestions::SuggestionSet)
    end

    it "honors a custom max_size" do
      expect(described_class.empty(max_size: 5).max_size).to eq(5)
    end
  end

  describe ".from_words" do
    it "builds a SuggestionSet from a word list with the given source" do
      built = described_class.from_words(%w[hello world], source: :test_corpus)
      expect(built).to be_a(Kotoshu::Suggestions::SuggestionSet)
      expect(built.to_words).to contain_exactly("hello", "world")
      expect(built.suggestions.first.source).to eq("test_corpus")
    end

    it "defaults source to :unknown" do
      built = described_class.from_words(%w[hello])
      expect(built.suggestions.first.source).to eq("unknown")
    end

    it "honors max_size" do
      built = described_class.from_words(%w[a b c d e], max_size: 2)
      expect(built.size).to eq(2)
    end
  end

  describe "explicit deduplication (TODO 56 T5.1)" do
    it "tracks the number of duplicates removed" do
      s1 = Kotoshu::Suggestions::Suggestion.new(word: "hello", distance: 1)
      s2 = Kotoshu::Suggestions::Suggestion.new(word: "Hello", distance: 2)
      set = described_class.new([s1, s2], max_size: 10)
      expect(set.duplicates_removed).to eq(1)
      expect(set.size).to eq(1)
    end

    it "reports zero duplicates when all words are unique" do
      s1 = Kotoshu::Suggestions::Suggestion.new(word: "hello", distance: 1)
      s2 = Kotoshu::Suggestions::Suggestion.new(word: "world", distance: 2)
      set = described_class.new([s1, s2], max_size: 10)
      expect(set.duplicates_removed).to eq(0)
      expect(set.size).to eq(2)
    end

    it "deduplicates after merge!" do
      s1 = Kotoshu::Suggestions::Suggestion.new(word: "hello", distance: 1)
      s2 = Kotoshu::Suggestions::Suggestion.new(word: "hello", distance: 1)
      set_a = described_class.new([s1], max_size: 10)
      set_b = described_class.new([s2], max_size: 10)
      set_a.merge!(set_b)
      expect(set_a.size).to eq(1)
      expect(set_a.duplicates_removed).to eq(1)
    end

    it "deduplicates case-insensitively" do
      s1 = Kotoshu::Suggestions::Suggestion.new(word: "Hello", distance: 1)
      s2 = Kotoshu::Suggestions::Suggestion.new(word: "HELLO", distance: 1)
      s3 = Kotoshu::Suggestions::Suggestion.new(word: "hello", distance: 1)
      set = described_class.new([s1, s2, s3], max_size: 10)
      expect(set.size).to eq(1)
      expect(set.duplicates_removed).to eq(2)
    end
  end
end
