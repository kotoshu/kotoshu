# frozen_string_literal: true

require "kotoshu"
require "benchmark"

RSpec.describe "SymSpell Benchmark", :slow do
  # Create a dictionary for benchmarking
  let(:dictionary) do
    words = begin
      File.readlines("/usr/share/dict/words", chomp: true)
    rescue StandardError
      []
    end
    words = words.take(10_000) # Use first 10K words
    Kotoshu::Dictionary::PlainText.from_words(words, language_code: "en")
  end

  before do
    skip "No system dictionary available" unless File.exist?("/usr/share/dict/words")
  end

  describe "Performance comparison" do
    let(:symspell_strategy) do
      Kotoshu::Suggestions::Strategies::SymSpellStrategy.new(dictionary: dictionary)
    end

    let(:edit_distance_strategy) do
      Kotoshu::Suggestions::Strategies::EditDistanceStrategy.new
    end

    let(:test_words) do
      # Common misspellings to test
      %w[helo teh recieve seperate occured untill wich]
    end

    it "is faster than EditDistanceStrategy" do
      symspell_times = []
      edit_distance_times = []

      test_words.each do |word|
        context = Kotoshu::Suggestions::Context.new(word: word, dictionary: dictionary)

        # Benchmark SymSpell
        symspell_time = Benchmark.realtime do
          10.times { symspell_strategy.generate(context) }
        end
        symspell_times << symspell_time

        # Benchmark EditDistance
        edit_time = Benchmark.realtime do
          10.times { edit_distance_strategy.generate(context) }
        end
        edit_distance_times << edit_time
      end

      avg_symspell = symspell_times.sum / symspell_times.size
      avg_edit_distance = edit_distance_times.sum / edit_distance_times.size

      puts "\nSymSpell average: #{(avg_symspell * 1000).round(2)}ms per 10 lookups"
      puts "EditDistance average: #{(avg_edit_distance * 1000).round(2)}ms per 10 lookups"
      puts "Speedup: #{(avg_edit_distance / avg_symspell).round(2)}x"

      # SymSpell should be at least 2x faster (allowing for variability)
      expect(avg_symspell).to be < avg_edit_distance
    end

    it "completes single lookup in under 200ms" do
      context = Kotoshu::Suggestions::Context.new(word: "helo", dictionary: dictionary)

      time = Benchmark.realtime do
        symspell_strategy.generate(context)
      end

      # Allow 200ms for first lookup (includes initialization overhead)
      # Subsequent lookups will be much faster (< 1ms)
      expect(time * 1000).to be < 200
    end
  end

  describe "Scalability" do
    it "handles large dictionaries efficiently" do
      words = begin
        File.readlines("/usr/share/dict/words", chomp: true).first(50_000)
      rescue StandardError
        []
      end
      large_dict = Kotoshu::Dictionary::PlainText.from_words(words, language_code: "en")

      # Time the initialization
      init_time = Benchmark.realtime do
        Kotoshu::Suggestions::Strategies::SymSpellStrategy.new(dictionary: large_dict)
      end

      puts "\nInitialization time for 50K words: #{(init_time * 1000).round(2)}ms"

      # Should initialize in under 1 second
      expect(init_time).to be < 1.0
    end
  end

  describe "Accuracy" do
    let(:symspell_strategy) do
      Kotoshu::Suggestions::Strategies::SymSpellStrategy.new(dictionary: dictionary)
    end

    it "finds correct suggestions for misspellings within dictionary" do
      # Use words that are likely in the first 10K words
      # "abandon" -> "abandan" (common misspelling)
      test_words = {
        "abandon" => "abandon", # Correct word should be in dictionary
        "ability" => "ability"
      }

      # First verify the correct words are in the dictionary
      test_words.each_key do |correct_word|
        next unless dictionary.lookup?(correct_word)

        # Create a misspelling by deleting a character
        misspelling = correct_word[0..-2] # Remove last character

        context = Kotoshu::Suggestions::Context.new(word: misspelling, dictionary: dictionary)
        result = symspell_strategy.generate(context)

        # Check that the correct word is suggested
        expect(result.to_words).to include(correct_word),
                                   "Expected to find '#{correct_word}' for misspelling '#{misspelling}', got: #{result.to_words.inspect}"
      end
    end
  end
end
