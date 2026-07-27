# frozen_string_literal: true

require "benchmark"
require "timeout"

# Performance regression specs are inherently timing-sensitive and flaky
# on shared CI runners. Tagged :slow so they only run when SLOW_TESTS=1
# is set. Baselines and a proper performance gate belong to the T4.1
# performance pass (see TODO.impl/39-tier3-and-beyond.md).
RSpec.describe "Performance Regression Tests", :performance, :slow do
  let(:dictionary) do
    # Create a reasonably sized dictionary
    words = begin
      File.readlines("/usr/share/dict/words", chomp: true).first(5000)
    rescue StandardError
      []
    end
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
      Benchmark.realtime do
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

  # Compound lookup is the deepest recursion in the checker, and
  # CHECKCOMPOUNDPATTERN replacements widen the search further. Thresholds
  # are set an order of magnitude above measured cost, so they catch a
  # blow-up (an unbounded scan, a lost COMPOUNDMIN guard) rather than the
  # few-percent drift that makes timing specs flaky.
  describe "Hunspell compound lookup" do
    fixtures = File.expand_path("../integrational/fixtures", __dir__)

    def hunspell(dir, name)
      Kotoshu::Dictionary::Hunspell.new(dic_path: File.join(dir, "#{name}.dic"),
                                        aff_path: File.join(dir, "#{name}.aff"),
                                        language_code: "en")
    end

    it "resolves deep German compounds without blowing up" do
      dict = hunspell(fixtures, "germancompounding")
      words = %w[Computerarbeitscomputer Arbeitscomputerarbeit]
      words.each { |word| dict.lookup(word) } # warm

      elapsed = Benchmark.realtime { 200.times { words.each { |word| dict.lookup(word) } } }

      # Measured ~92 ms; main was ~87 ms before replacement support.
      expect(elapsed * 1000).to be < 1000
    end

    it "resolves replacement compounds without scanning every offset" do
      dict = hunspell(fixtures, "checkcompoundpattern4")
      words = %w[sUryOdayaM pErunna sUryaudayaM pEruunna]
      words.each { |word| dict.lookup(word) } # warm

      elapsed = Benchmark.realtime { 500.times { words.each { |word| dict.lookup(word) } } }

      # Measured ~85 ms. A full-width scan per split position lands far above.
      expect(elapsed * 1000).to be < 1000
    end

    it "keeps the pathological compound fixture bounded" do
      # 23 digits over a dictionary of digit strings with COMPOUNDMIN 1 —
      # Hunspell caps this with a time limit Kotoshu does not implement, so
      # this spec is the only thing standing between a change and a hang.
      dict = hunspell(fixtures, "timelimit")

      # Timeout, not a measured threshold: if the compound search stops
      # terminating, an assertion after the fact never runs.
      expect { Timeout.timeout(15) { dict.lookup("1000000000000000000000x") } }
        .not_to raise_error
    end
  end
end
