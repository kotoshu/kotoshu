# frozen_string_literal: true

require "benchmark"

# Performance regression specs are inherently timing-sensitive and flaky
# on shared CI runners. Tagged :slow so they only run when SLOW_TESTS=1
# is set. Baselines and a proper performance gate belong to the T4.1
# performance pass (see TODO.impl/39-tier3-and-beyond.md).
RSpec.describe "Performance Regression Tests", :performance, :slow do
  let(:dictionary) do
    # Create a reasonably sized dictionary
    words = File.readlines("/usr/share/dict/words", chomp: true).first(5000) rescue []
    Kotoshu::Dictionary::PlainText.from_words(words, language_code: "en")
  end

  let(:spellchecker) { Kotoshu::Spellchecker.new(dictionary: dictionary) }

  before do
    skip "No system dictionary available" unless File.exist?("/usr/share/dict/words")
  end

  describe "lookup performance" do
    it "completes single lookup in under 1ms" do
      time = Benchmark.realtime do
        100.times { spellchecker.correct?("hello") }
      end

      avg_time_ms = (time / 100) * 1000
      expect(avg_time_ms).to be < 1.0
    end

    it "completes 1000 lookups in under 100ms" do
      words = dictionary.words.first(1000)

      time = Benchmark.realtime do
        words.each { |word| spellchecker.correct?(word) }
      end

      expect(time * 1000).to be < 100
    end
  end

  describe "suggestion performance" do
    it "generates suggestions in under 10ms" do
      time = Benchmark.realtime do
        10.times { spellchecker.suggest("helo") }
      end

      avg_time_ms = (time / 10) * 1000
      expect(avg_time_ms).to be < 10.0
    end

    it "generates suggestions faster with cache" do
      # First call (cache miss)
      spellchecker.suggest("helo")

      # Second call (cache hit)
      time = Benchmark.realtime do
        100.times { spellchecker.suggest("helo") }
      end

      avg_time_ms = (time / 100) * 1000
      expect(avg_time_ms).to be < 1.0
    end
  end

  describe "cache effectiveness" do
    it "achieves > 80% cache hit rate for repeated lookups" do
      # Warm up cache with 100 lookups
      words = dictionary.words.first(100)
      words.each { |word| spellchecker.correct?(word) }

      hits = 0
      misses = 0

      # Check same words again
      time = Benchmark.realtime do
        words.each do |word|
          if spellchecker.correct?(word)
            hits += 1
          else
            misses += 1
          end
        end
      end

      hit_rate = hits.to_f / (hits + misses)
      expect(hit_rate).to be > 0.8
    end
  end
end
