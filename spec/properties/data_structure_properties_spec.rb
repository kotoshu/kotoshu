# frozen_string_literal: true

require "spec_helper"
require "kotoshu/core/trie/trie"
require "kotoshu/dictionary/plain_text"

# T4.3's named properties (plan 56): Trie order-independence and
# lookup totality, and the no-out-of-dictionary-suggestions invariant.
# Example-based property specs over generated inputs (deterministic
# seeds); the house rule against doubles does not bite here — every
# subject is a real structure built in-spec.
RSpec.describe "Data-structure properties", :property do
  WORDS = [
    "cat", "car", "card", "care", "careful", "caret", "dog", "dodge",
    "hello", "hell", "help", "world", "word", "work", "working",
    "zeitgeist", "naïve", "Über", "日本語", "🚀rocket"
  ].freeze

  describe Kotoshu::Core::Trie::Trie do
    def trie_with(words)
      trie = described_class.new
      words.each { |w| trie.insert(w) }
      trie
    end

    it "lookup is order-independent: every insertion order answers identically" do
      reference = trie_with(WORDS)
      expected = WORDS.map { |w| [w, reference.lookup(w)] }

      orders = [
        WORDS.reverse,
        WORDS.sort_by(&:length),
        WORDS.shuffle(random: Random.new(42)),
        WORDS.shuffle(random: Random.new(1337)),
        WORDS.sort_by(&:bytesize),
      ]
      orders.each do |order|
        trie = trie_with(order)
        WORDS.each_with_index do |w, i|
          expect(trie.lookup(w)).to eq(expected[i][1]), "order #{order.first(3)}... diverged on #{w}"
        end
      end
    end

    it "lookup is total: arbitrary strings never raise" do
      trie = trie_with(WORDS)
      probes = [
        "", " ", "\0", "c", "ca", "car", "cars", "café", "_cats",
        "cat_", "CAT", "🚀rocketfuel", "x" * 1000, WORDS.join,
      ]
      probes.each { |p| expect { trie.lookup(p) }.not_to raise_error }
    end

    it "absent words answer nil and present words answer truthy" do
      trie = trie_with(WORDS)
      WORDS.each { |w| expect(trie.lookup(w)).to be_truthy }
      ["cats", "ca", "hellz", ""].each { |w| expect(trie.lookup(w)).to be_falsey }
    end

    it "has_prefix? agrees with word presence for full words" do
      trie = trie_with(WORDS)
      WORDS.each { |w| expect(trie.has_prefix?(w)).to be(true) }
      expect(trie.has_prefix?("ze")).to be(true)
      expect(trie.has_prefix?("zz")).to be(false)
    end

    it "words_with_prefix returns exactly the inserted subset, order-independent" do
      reference = trie_with(WORDS).words_with_prefix("car").sort
      [WORDS, WORDS.reverse, WORDS.shuffle(random: Random.new(7))].each do |order|
        expect(trie_with(order).words_with_prefix("car").sort).to eq(reference)
      end
      expect(reference).to eq(%w[car card care careful caret])
    end

    it "all_words recovers the inserted set exactly" do
      trie = trie_with(WORDS)
      expect(trie.all_words.sort).to eq(WORDS.sort)
    end
  end

  describe "suggestions come from the dictionary" do
    let(:vocab) do
      # a broad vocabulary: common words plus generated forms, so the
      # property is non-trivial for edit-distance and phonetic sources
      base = %w[
        hello hell help held well tell yellow cello shell
        define definitely finite infinite definition definitive
        receive believe achieve relieve retrieve
        accommodation recommend necessary embarrass occurrence
        programming program progress project provide produce
      ]
      base + base.map(&:capitalize) + %w[AI API JSON XML HTTP]
    end
    let(:dictionary) { Kotoshu::Dictionary::PlainText.from_words(vocab.uniq, language_code: "en") }
    let(:spellchecker) { Kotoshu::Spellchecker.new(dictionary: dictionary) }

    it "every suggested word is a dictionary member" do
      queries = %w[
        helo hlelo definately definatly recieve beleive neccessary
        embaras occurence progam progess projct prodcue
        acommodation recomend hellp yello celo shll
      ]
      queries.each do |q|
        spellchecker.suggest(q, max_suggestions: 10).each do |suggestion|
          expect(dictionary.lookup?(suggestion.word)).to be(true),
                                                         "#{q.inspect} produced out-of-dictionary #{suggestion.word.inspect}"
        end
      end
    end

    it "correctly-spelled words suggest nothing outside themselves" do
      %w[hello define receive].each do |w|
        rows = spellchecker.suggest(w, max_suggestions: 10).map(&:word)
        rows.each { |r| expect(dictionary.lookup?(r)).to be(true) }
      end
    end
  end
end
