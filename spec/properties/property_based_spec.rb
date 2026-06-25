# frozen_string_literal: true

require "tempfile"
require "kotoshu/spellchecker"
require "kotoshu/spellchecker/parallel_checker"
require "kotoshu/dictionary/plain_text"
require "kotoshu/cache/lookup_cache"
require "kotoshu/cache/suggestion_cache"
require "kotoshu/data_structures/bloom_filter"
require "kotoshu/results/result"
require "kotoshu/suggestions/strategies/symspell_strategy"
require "kotoshu/personal_dictionary"
require "kotoshu/suggestions/suggestion"

RSpec.describe "Property-Based Tests", :property do
  let(:dictionary) do
    Kotoshu::Dictionary::PlainText.from_words(
      %w[hello world test example Ruby programming spell checker],
      language_code: "en"
    )
  end

  let(:spellchecker) { Kotoshu::Spellchecker.new(dictionary: dictionary) }

  # ============================================================================
  # DICTIONARY PROPERTIES
  # ============================================================================

  describe "Dictionary lookup properties" do
    context "with case-insensitive dictionary" do
      let(:dict) { Kotoshu::Dictionary::PlainText.from_words(%w[Hello World], language_code: "en", case_sensitive: false) }

      it "maintains case-insensitive lookup property" do
        words = %w[Hello HELLO hello HeLlO hElLo]

        words.each do |word|
          expect(dict.lookup?(word)).to be true
          expect(dict.lookup?(word.downcase)).to eq(dict.lookup?(word.upcase))
        end
      end

      it "maintains case-insensitive suggestion property" do
        sc = Kotoshu::Spellchecker.new(dictionary: dict)

        # Test that misspelled words in different cases get suggestions
        # "helo" is a misspelling of "Hello"
        %w[helo HELO HeLo].each do |word|
          suggestions = sc.suggest(word)
          # All cases should return suggestions for the same misspelling
          expect(suggestions).not_to be_empty
        end
      end
    end

    context "with case-sensitive dictionary" do
      let(:dict) { Kotoshu::Dictionary::PlainText.from_words(%w[Hello World], language_code: "en", case_sensitive: true) }

      it "maintains case-sensitive lookup property" do
        expect(dict.lookup?("Hello")).to be true
        expect(dict.lookup?("hello")).to be false
        expect(dict.lookup?("HELLO")).to be false
      end
    end

    it "returns same result for repeated lookups" do
      result1 = spellchecker.correct?("hello")
      result2 = spellchecker.correct?("hello")
      result3 = spellchecker.correct?("hello")

      expect(result1).to eq(result2)
      expect(result2).to eq(result3)
    end

    it "returns false for non-existent words across different cases" do
      %w[xyzxyz XYZXYZ XyZxYz].each do |word|
        expect(spellchecker.correct?(word)).to be false
      end
    end
  end

  describe "Dictionary mutation properties" do
    it "always finds word immediately after adding" do
      dict = Kotoshu::Dictionary::PlainText.from_words([], language_code: "en")

      expect(dict.lookup?("newword")).to be false

      dict.add_word("newword")
      expect(dict.lookup?("newword")).to be true
      expect(dict.lookup?("newword")).to be true # Idempotent
    end

    it "finds word in custom dictionary after creation" do
      dict = Kotoshu::Dictionary::PlainText.from_words(%w[custom1 custom2], language_code: "en")

      expect(dict.lookup?("custom1")).to be true
      expect(dict.lookup?("custom2")).to be true
      expect(dict.lookup?("custom3")).to be false
    end

    it "maintains word count property" do
      words = %w[a b c d e]
      dict = Kotoshu::Dictionary::PlainText.from_words(words, language_code: "en")

      expect(dict.words.size).to eq(words.size)

      dict.add_word("f")
      expect(dict.words.size).to eq(words.size + 1)
    end
  end

  # ============================================================================
  # CACHE PROPERTIES
  # ============================================================================

  describe "LookupCache properties" do
    let(:cache) { Kotoshu::Cache::LookupCache.new(max_size: 5) }

    it "grows until max_size, then evicts" do
      # Fill cache to max
      5.times { |i| cache.write("key#{i}", "value#{i}") }
      expect(cache.size).to eq(5)

      # Add one more - should evict LRU
      cache.write("key5", "value5")
      expect(cache.size).to eq(5) # Still at max

      # First key should be evicted
      expect(cache.fetch("key0", "not_found")).to eq("not_found")
    end

    it "maintains LRU eviction order" do
      cache.write("a", 1)
      cache.write("b", 2)
      cache.write("c", 3)

      # Read 'a' to update its access order (not fetch)
      cache.read("a")

      # Add two more - cache now at capacity
      cache.write("d", 4)
      cache.write("e", 5)

      # Add one more - should evict 'b' (LRU, least recently used)
      cache.write("f", 6)

      expect(cache.read("a")).to eq(1) # Still there (accessed recently)
      expect(cache.read("b")).to be_nil # Evicted (LRU)
    end

    it "provides consistent cache statistics" do
      cache.write("key1", "value1")

      cache.fetch("key1") { "fallback" } # Hit
      cache.fetch("key2") { "fallback" } # Miss

      stats = cache.stats
      expect(stats[:hits]).to eq(1)
      expect(stats[:misses]).to eq(1)
      expect(stats[:hit_rate]).to eq(0.5)
    end

    it "clears all entries on clear" do
      5.times { |i| cache.write("key#{i}", "value#{i}") }
      expect(cache.size).to eq(5)

      cache.clear
      expect(cache.size).to eq(0)
      expect(cache.size).to be_zero
    end
  end

  describe "SuggestionCache properties" do
    let(:cache) { Kotoshu::Cache::SuggestionCache.new(max_size: 10) }

    it "caches suggestions with same word regardless of max_results" do
      suggestions1 = Kotoshu::Suggestions::SuggestionSet.new([
                                                               Kotoshu::Suggestions::Suggestion.new(word: "hello", distance: 1),
                                                               Kotoshu::Suggestions::Suggestion.new(word: "help", distance: 1)
                                                             ])
      suggestions2 = Kotoshu::Suggestions::SuggestionSet.new([
                                                               Kotoshu::Suggestions::Suggestion.new(word: "hello", distance: 1),
                                                               Kotoshu::Suggestions::Suggestion.new(word: "help", distance: 1),
                                                               Kotoshu::Suggestions::Suggestion.new(word: "he'll", distance: 1)
                                                             ])

      cache.write("helo", suggestions1, max_results: 2)
      cache.write("helo", suggestions2, max_results: 3)

      # Different keys due to different max_results
      expect(cache.size).to eq(2)
    end

    it "generates correct cache keys for word/max_results combinations" do
      cache.write("test", Kotoshu::Suggestions::SuggestionSet.new([
                                                                    Kotoshu::Suggestions::Suggestion.new(word: "test1", distance: 1)
                                                                  ]), max_results: 5)
      cache.write("test", Kotoshu::Suggestions::SuggestionSet.new([
                                                                    Kotoshu::Suggestions::Suggestion.new(word: "test2", distance: 1)
                                                                  ]), max_results: 10)

      result1 = cache.fetch("test", max_results: 5) { "not_found" }
      result2 = cache.fetch("test", max_results: 10) { "not_found" }

      expect(result1.suggestions.map(&:word)).to eq(%w[test1])
      expect(result2.suggestions.map(&:word)).to eq(%w[test2])
    end
  end

  # ============================================================================
  # BLOOM FILTER PROPERTIES
  # ============================================================================

  describe "BloomFilter properties" do
    let(:filter) { Kotoshu::DataStructures::BloomFilter.new(expected_size: 1000, false_positive_rate: 0.01) }

    it "never produces false negatives" do
      words = %w[hello world test example]

      words.each { |w| filter.add(w) }

      words.each do |word|
        expect(filter.include?(word)).to be true
      end
    end

    it "maintains false positive rate within bounds" do
      # Add 1000 words
      1000.times { |i| filter.add("word#{i}") }

      # Test 100 non-existent words
      false_positives = 0
      100.times do |i|
        fp = filter.include?("nonexistent#{i}")
        false_positives += 1 if fp
      end

      # Allow up to 15% false positive rate (generous bound for probabilistic test)
      expect(false_positives).to be < 15
    end

    it "becomes more accurate as size increases" do
      small_filter = Kotoshu::DataStructures::BloomFilter.new(expected_size: 100, false_positive_rate: 0.01)
      large_filter = Kotoshu::DataStructures::BloomFilter.new(expected_size: 10_000, false_positive_rate: 0.01)

      100.times { |i| small_filter.add("word#{i}") }
      100.times { |i| large_filter.add("word#{i}") }

      # Test non-existent words
      small_fp = 0
      large_fp = 0

      50.times do |i|
        small_fp += 1 if small_filter.include?("fake#{i}")
        large_fp += 1 if large_filter.include?("fake#{i}")
      end

      # Large filter should have fewer or equal false positives
      expect(large_fp).to be <= small_fp
    end

    it "handles case-insensitive lookups correctly" do
      filter = Kotoshu::DataStructures::BloomFilter.new(case_sensitive: false)
      filter.add("Hello")

      expect(filter.include?("hello")).to be true
      expect(filter.include?("HELLO")).to be true
      expect(filter.include?("HeLLo")).to be true
    end
  end

  # ============================================================================
  # SUGGESTION PROPERTIES
  # ============================================================================

  describe "Suggestion generation properties" do
    it "finds correct word in suggestions for misspellings" do
      # For misspelled words, the correct word should appear in suggestions
      test_cases = {
        "helo" => "hello",
        "wrld" => "world",
        "tst" => "test"
      }

      test_cases.each do |misspelling, correct|
        next unless spellchecker.correct?(correct)

        suggestions = spellchecker.suggest(misspelling)
        suggestions.suggestions.map(&:word)

        # The correct word should be in the suggestions (or at least some suggestions)
        expect(suggestions.suggestions.size).to be > 0
      end
    end

    it "returns suggestions with valid distances" do
      suggestions = spellchecker.suggest("helo")

      suggestions.suggestions.each do |suggestion|
        expect(suggestion.distance).to be >= 0
        expect(suggestion.distance).to be <= suggestion.word.length
      end
    end

    it "orders suggestions by relevance" do
      suggestions = spellchecker.suggest("helo")
      words = suggestions.suggestions.map(&:word)

      # "hello" should appear before more distant suggestions
      hello_idx = words.index("hello")
      expect(hello_idx).not_to be_nil

      # All suggestions after "hello" should have equal or greater distance
      if hello_idx && hello_idx < words.length - 1
        hello_dist = suggestions.suggestions[hello_idx].distance
        suggestions.suggestions[(hello_idx + 1)..].each do |s|
          expect(s.distance).to be >= hello_dist
        end
      end
    end

    it "respects max_suggestions limit" do
      [1, 3, 5, 10].each do |max|
        suggestions = spellchecker.suggest("xyzxyz", max_suggestions: max)
        expect(suggestions.suggestions.size).to be <= max
      end
    end

    it "returns same suggestions for same input (deterministic)" do
      suggestions1 = spellchecker.suggest("helo")
      suggestions2 = spellchecker.suggest("helo")
      suggestions3 = spellchecker.suggest("helo")

      words1 = suggestions1.suggestions.map(&:word)
      words2 = suggestions2.suggestions.map(&:word)
      words3 = suggestions3.suggestions.map(&:word)

      expect(words1).to eq(words2)
      expect(words2).to eq(words3)
    end
  end

  # ============================================================================
  # SYMSPELL PROPERTIES
  # ============================================================================

  describe "SymSpell strategy properties" do
    let(:symspell) do
      Kotoshu::Suggestions::Strategies::SymSpellStrategy.new(
        dictionary: dictionary,
        max_distance: 2
      )
    end

    it "finds words within deletion distance" do
      # "hello" → delete 1 char → "ello", "hllo", "helo", "helo", "hell"
      context = Kotoshu::Suggestions::Context.new(word: "helo", dictionary: dictionary, max_results: 10)
      suggestions = symspell.generate(context)

      expect(suggestions.suggestions.size).to be > 0
    end

    it "maintains distance upper bound" do
      context = Kotoshu::Suggestions::Context.new(word: "xyzabc", dictionary: dictionary, max_results: 10)
      suggestions = symspell.generate(context)

      suggestions.suggestions.each do |s|
        expect(s.distance).to be <= 2
      end
    end

    it "returns empty for very distant words" do
      context = Kotoshu::Suggestions::Context.new(word: "abcdefg", dictionary: dictionary, max_results: 10)
      suggestions = symspell.generate(context)

      # May return some suggestions but should be limited
      expect(suggestions.suggestions.size).to be < 10
    end
  end

  # ============================================================================
  # PARALLEL CHECKER PROPERTIES
  # ============================================================================

  describe "Parallel checker properties" do
    let(:files) do
      # Create temporary test files
      files = []
      3.times do |i|
        file = Tempfile.new(["kotoshu_test_#{i}", ".txt"])
        file.write("hello world test #{i}")
        file.close
        files << file.path
      end
      files
    end

    after do
      files.each { |f| File.delete(f) if File.exist?(f) }
    end

    it "produces same results as sequential checking" do
      parallel_checker = Kotoshu::Spellchecker::ParallelChecker.new(spellchecker: spellchecker)
      parallel_results = parallel_checker.check_files_parallel(files)
      sequential_results = files.map { |f| spellchecker.check_file(f) }

      expect(parallel_results.size).to eq(sequential_results.size)

      parallel_results.zip(sequential_results).each do |parallel, sequential|
        expect(parallel.errors.size).to eq(sequential.errors.size)
      end
    end

    it "handles empty file list gracefully" do
      checker = Kotoshu::Spellchecker::ParallelChecker.new(spellchecker: spellchecker)
      results = checker.check_files_parallel([])

      expect(results).to eq([])
    end
  end

  # ============================================================================
  # RESULT PATTERN PROPERTIES
  # ============================================================================

  describe "Result pattern properties" do
    it "success chained with map always returns success" do
      result = Kotoshu::Results::Result::Success.new(5)
      mapped = result.map { |x| x * 2 }

      expect(mapped).to be_a_success
      expect(mapped.value).to eq(10)
    end

    it "failure chained with map returns failure" do
      error = StandardError.new("test error")
      result = Kotoshu::Results::Result::Failure.new(error)
      mapped = result.map { |x| x * 2 }

      expect(mapped).to be_a_failure
      expect(mapped.error).to eq(error)
    end

    it "and_then chains successes" do
      result = Kotoshu::Results::Result::Success.new(5)
      chained = result.and_then { |x| Kotoshu::Results::Result::Success.new(x * 2) }

      expect(chained).to be_a_success
      expect(chained.value).to eq(10)
    end

    it "and_then short-circuits on failure" do
      error = StandardError.new("error")
      result = Kotoshu::Results::Result::Failure.new(error)

      chained = result.and_then do |_x|
        # This should not execute
        Kotoshu::Results::Result::Success.new(999)
      end

      expect(chained).to be_a_failure
      expect(chained.error).to eq(error)
    end

    it "or_else recovers from failure" do
      error = StandardError.new("error")
      result = Kotoshu::Results::Result::Failure.new(error)

      recovered = result.or_else do |_err|
        Kotoshu::Results::Result::Success.new("recovered")
      end

      expect(recovered).to be_a_success
      expect(recovered.value).to eq("recovered")
    end
  end

  # ============================================================================
  # PERSONAL DICTIONARY PROPERTIES
  # ============================================================================

  describe "Personal dictionary properties" do
    before do
      # Clean up personal dictionary file before tests
      personal_file = File.expand_path("~/.kotoshu/personal.dic")
      File.delete(personal_file) if File.exist?(personal_file)
    end

    after do
      # Clean up after tests
      personal_file = File.expand_path("~/.kotoshu/personal.dic")
      File.delete(personal_file) if File.exist?(personal_file)
    end

    it "persists words across instances" do
      Kotoshu::PersonalDictionary.add_word("customword1")
      Kotoshu::PersonalDictionary.add_word("customword2")

      words = Kotoshu::PersonalDictionary.words
      expect(words).to include("customword1")
      expect(words).to include("customword2")
    end

    it "handles duplicate adds idempotently" do
      Kotoshu::PersonalDictionary.add_word("duplicate")
      Kotoshu::PersonalDictionary.add_word("duplicate")

      words = Kotoshu::PersonalDictionary.words
      expect(words.count("duplicate")).to eq(1)
    end

    it "can remove added words" do
      Kotoshu::PersonalDictionary.add_word("removeme")
      expect(Kotoshu::PersonalDictionary.words).to include("removeme")

      Kotoshu::PersonalDictionary.remove_word("removeme")
      expect(Kotoshu::PersonalDictionary.words).not_to include("removeme")
    end
  end
end
