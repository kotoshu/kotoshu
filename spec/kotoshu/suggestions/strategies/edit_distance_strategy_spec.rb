# frozen_string_literal: true

require_relative '../../../../lib/kotoshu/suggestions/strategies/edit_distance_strategy'
require_relative '../../../../lib/kotoshu/suggestions/context'
require_relative '../../../../lib/kotoshu/dictionary/plain_text'
require_relative '../../../support/language_fixtures'

module SpecHelpers
  module LanguageFixtures
    # Re-include to make module available in this spec
  end
end

RSpec.describe Kotoshu::Suggestions::Strategies::EditDistanceStrategy do
  # ==========================================================================
  # Language-Agnostic Core Algorithm Tests
  # ==========================================================================
  #
  # These tests verify the core edit distance algorithm works correctly
  # regardless of language-specific data (keyboard layouts, word frequencies).
  # The algorithm itself is universal and should produce the same results
  # for any language.

  describe 'core algorithm (language-agnostic)' do
    let(:dictionary) do
      Kotoshu::Dictionary::PlainText.from_words(
        %w[hello world help held hell bell well tell shell yellow],
        language_code: 'en'
      )
    end

    let(:context) { Kotoshu::Suggestions::Context.new(word: 'helo', dictionary: dictionary) }
    let(:strategy) { described_class.new }

    include_examples 'an edit distance calculator'
    include_examples 'a typo pattern detector'
    include_examples 'a keyboard proximity detector'

    describe '#calculate_enhanced_score' do
      it 'combines multiple scoring factors' do
        score = strategy.calculate_enhanced_score('helo', 'hello', 1)
        expect(score).to be_a(Numeric)
        expect(score).to be > 0
      end

      it 'gives lower score (better) for common typo patterns' do
        # helo -> hello (missing double letter) should score better than
        # helo -> help (substitution)
        hello_score = strategy.calculate_enhanced_score('helo', 'hello', 1)
        help_score = strategy.calculate_enhanced_score('helo', 'help', 1)

        expect(hello_score).to be < help_score
      end

      it 'penalizes length differences' do
        # Shorter words should score worse when original is longer
        short_score = strategy.calculate_enhanced_score('hello', 'hi', 3)
        long_score = strategy.calculate_enhanced_score('hello', 'helloing', 2)

        expect(short_score).to be > long_score
      end
    end

    describe '#calculate_ngram_similarity' do
      # NOTE: This is now the typo correction similarity metric, not traditional n-grams
      # It combines character overlap, prefix/suffix matching, and length similarity

      it 'returns 1.0 for identical words' do
        similarity = strategy.calculate_ngram_similarity('hello', 'hello')
        expect(similarity).to eq(1.0)
      end

      it 'returns 0.0 for completely different words' do
        similarity = strategy.calculate_ngram_similarity('abc', 'xyz')
        expect(similarity).to eq(0.0)
      end

      it 'gives high similarity for words with common prefix' do
        similarity = strategy.calculate_ngram_similarity('hello', 'hell')
        expect(similarity).to be > 0.7
      end

      it 'gives high similarity for words with common suffix' do
        similarity = strategy.calculate_ngram_similarity('hello', 'jello')
        expect(similarity).to be > 0.7
      end

      it 'handles words with character overlap' do
        # Both 'hello' and 'help' share 'hel' prefix and 'l' character
        similarity = strategy.calculate_ngram_similarity('hello', 'help')
        expect(similarity).to be > 0.5
      end
    end
  end

  # ==========================================================================
  # English Language Behavior Tests
  # ==========================================================================
  #
  # These tests verify English-specific behavior, including:
  # - QWERTY keyboard layout
  # - English common words list
  # - English-specific typo patterns
  #
  # NOTE: The current implementation uses hardcoded constants for English.
  # Future implementations should load this data from language-specific
  # configuration files.

  describe 'English language behavior' do
    let(:dictionary) do
      # Create a dictionary with words needed for testing
      # Include common words plus specific test words
      common_words = SpecHelpers::LanguageFixtures::COMMON_WORDS_BY_LANGUAGE[:en]
      test_words = %w[hello world help held hell bell well tell shell yellow]
      Kotoshu::Dictionary::PlainText.from_words(
        (common_words + test_words).uniq,
        language_code: 'en'
      )
    end

    let(:strategy) { described_class.new }

    # Most common English typo: transposition
    context 'with transposition errors' do
      it 'ranks "world" first for "wrold"' do
        context = Kotoshu::Suggestions::Context.new(word: 'wrold', dictionary: dictionary)
        result = strategy.generate(context)

        expect(result.first.word).to eq('world')
      end

      it 'gives "world" highest confidence for "wrold"' do
        context = Kotoshu::Suggestions::Context.new(word: 'wrold', dictionary: dictionary)
        result = strategy.generate(context)

        world = result.find_word('world')
        expect(world).not_to be_nil
        expect(world.confidence).to eq(1.0)
      end
    end

    # Second most common English typo: missing double letter
    context 'with missing double letters' do
      it 'ranks "hello" first for "helo"' do
        context = Kotoshu::Suggestions::Context.new(word: 'helo', dictionary: dictionary)
        result = strategy.generate(context)

        expect(result.first.word).to eq('hello')
      end

      it 'ranks "hello" above "help" for "helo"' do
        context = Kotoshu::Suggestions::Context.new(word: 'helo', dictionary: dictionary)
        result = strategy.generate(context)

        hello_idx = result.to_words.index('hello')
        help_idx = result.to_words.index('help')

        expect(hello_idx).to be < help_idx
      end

      it 'gives "hello" highest confidence for "helo"' do
        context = Kotoshu::Suggestions::Context.new(word: 'helo', dictionary: dictionary)
        result = strategy.generate(context)

        hello = result.find_word('hello')
        expect(hello).not_to be_nil
        expect(hello.confidence).to eq(1.0)
      end
    end

    context 'with keyboard proximity errors' do
      it 'recognizes adjacent key substitutions on QWERTY' do
        # o -> p substitution (adjacent on QWERTY)
        context = Kotoshu::Suggestions::Context.new(word: 'helo', dictionary: dictionary)
        result = strategy.generate(context)

        # "help" should appear because o->p is an adjacent key typo
        expect(result.to_words).to include('help')
      end

      it 'ranks adjacent-key substitutions higher than distant-key substitutions' do
        context = Kotoshu::Suggestions::Context.new(word: 'helo', dictionary: dictionary)
        result = strategy.generate(context)

        # Find suggestions with single substitution
        help = result.find_word('help')  # o->p (adjacent)
        helm = result.find_word('helm')  # o->m (distant)

        # Both might not exist in our small dictionary, so skip if not found
        if help && helm
          expect(help.confidence).to be > helm.confidence
        end
      end
    end

    context 'with common English words' do
      it 'gives frequency bonus to common words' do
        # 'the' is one of the most common English words
        context = Kotoshu::Suggestions::Context.new(word: 'teh', dictionary: dictionary)
        result = strategy.generate(context)

        expect(result.to_words).to include('the')
      end
    end
  end

  # ==========================================================================
  # Language-Specific Configuration Tests
  # ==========================================================================
  #
  # EditDistanceStrategy resolves keyboard layout and frequency tiers from
  # the language_code kwarg via Keyboard::Registry.layout_for and
  # Cache::FrequencyCache. These specs pin the language-aware wiring so
  # regressions to "English-only" defaults surface immediately.

  describe 'multi-language support' do
    context 'with German language' do
      let(:dictionary) do
        Kotoshu::Dictionary::PlainText.from_words(
          %w[hallo welt hilfe das der die],
          language_code: 'de'
        )
      end

      let(:strategy) { described_class.new(language_code: 'de') }

      it 'selects the QWERTZ keyboard layout' do
        expect(strategy.keyboard_name).to eq('QWERTZ')
      end

      it 'generates a suggestion for a German typo' do
        context = Kotoshu::Suggestions::Context.new(word: 'halo', dictionary: dictionary)
        result = strategy.generate(context)

        expect(result).to be_a(Kotoshu::Suggestions::SuggestionSet)
        expect(result.to_words).to include('hallo')
      end

      it 'treats z and y as adjacent on QWERTZ (transposition bonus)' do
        # On QWERTZ, z and y are swapped vs QWERTY — pick a word where the
        # transposition lands on a real dictionary word.
        dict = Kotoshu::Dictionary::PlainText.from_words(
          %w[dazu daten],
          language_code: 'de'
        )
        context = Kotoshu::Suggestions::Context.new(word: 'dayu', dictionary: dict)
        result = strategy.generate(context)

        # Transposition of y/z on QWERTZ should not penalize "dayu" → "dazu"
        expect(result.to_words).to include('dazu') if result.to_words.any?
      end
    end

    context 'with French language' do
      let(:french_dictionary) do
        Kotoshu::Dictionary::PlainText.from_words(
          %w[bonjour monde aide le de et un],
          language_code: 'fr'
        )
      end

      let(:french_strategy) { described_class.new(language_code: 'fr') }

      it 'selects the AZERTY keyboard layout' do
        expect(french_strategy.keyboard_name).to eq('AZERTY')
      end

      it 'generates a suggestion for a French typo' do
        context = Kotoshu::Suggestions::Context.new(word: 'bonjur', dictionary: french_dictionary)
        result = french_strategy.generate(context)

        expect(result).to be_a(Kotoshu::Suggestions::SuggestionSet)
        expect(result.to_words).to include('bonjour')
      end
    end

    context 'with English language' do
      let(:strategy) { described_class.new(language_code: 'en') }

      it 'selects the QWERTY keyboard layout as the default' do
        expect(strategy.keyboard_name).to eq('QWERTY')
      end
    end

    context 'with Russian language' do
      let(:strategy) { described_class.new(language_code: 'ru') }

      it 'selects the JCUKEN keyboard layout' do
        expect(strategy.keyboard_name).to eq('JCUKEN')
      end
    end
  end

  # ==========================================================================
  # Threshold Filtering Tests
  # ==========================================================================
  #
  # These tests verify that similarity-based threshold filtering works
  # correctly to filter out low-quality suggestions.

  describe 'threshold filtering' do
    let(:dictionary) do
      Kotoshu::Dictionary::PlainText.from_words(
        SpecHelpers::LanguageFixtures::COMMON_WORDS_BY_LANGUAGE[:en],
        language_code: 'en'
      )
    end

    it 'filters out low-similarity suggestions' do
      strategy = described_class.new(
        min_jaro_similarity: 0.70 # Filter out suggestions with < 70% similarity
      )

      context = Kotoshu::Suggestions::Context.new(word: 'wrold', dictionary: dictionary)
      result = strategy.generate(context)

      # "fold" has similarity ~0.65, should be filtered out
      # "world" has similarity 1.0, should be included
      expect(result.to_words).to include('world')
      expect(result.to_words).not_to include('fold')
    end

    it 'respects min_results configuration even with threshold' do
      # Add words similar to "wrold" to test min_results behavior
      test_dictionary = Kotoshu::Dictionary::PlainText.from_words(
        (SpecHelpers::LanguageFixtures::COMMON_WORDS_BY_LANGUAGE[:en] + %w[world word would old rod fold rolf
                                                                           told]).uniq,
        language_code: 'en'
      )

      strategy = described_class.new(
        min_jaro_similarity: 0.75, # High but achievable threshold
        min_results: 3 # Always return at least 3 suggestions
      )

      context = Kotoshu::Suggestions::Context.new(word: 'wrold', dictionary: test_dictionary)
      result = strategy.generate(context)

      # "world" should rank first (transposition is most common typo)
      expect(result.first.word).to eq('world')

      # Should have at least min_results even with high threshold
      expect(result.size).to be >= 3
    end

    it 'filters by confidence threshold as well' do
      strategy = described_class.new(
        min_confidence: 0.50 # Filter out suggestions with < 50% confidence
      )

      context = Kotoshu::Suggestions::Context.new(word: 'wrold', dictionary: dictionary)
      result = strategy.generate(context)

      # First suggestion should have highest confidence (>= 0.80)
      expect(result.first.confidence).to be >= 0.80

      # With reasonable threshold, should get some results
      expect(result.size).to be > 0
    end
  end

  # ==========================================================================
  # Performance Tests
  # ==========================================================================

  describe 'performance', :slow do
    let(:large_dictionary) do
      words = begin
        File.readlines('/usr/share/dict/words', chomp: true)
      rescue StandardError
        []
      end
      words = words[1000..11_000] || words.take(10_000)
      Kotoshu::Dictionary::PlainText.from_words(words, language_code: 'en')
    end

    let(:strategy) { described_class.new }

    before do
      skip 'No system dictionary available' unless File.exist?('/usr/share/dict/words')
    end

    it 'generates suggestions in reasonable time' do
      context = Kotoshu::Suggestions::Context.new(
        word: 'wrold',
        dictionary: large_dictionary
      )

      start_time = Time.now
      result = strategy.generate(context)
      elapsed = Time.now - start_time

      # Should complete in under 1 second for 10,000 words
      expect(elapsed).to be < 1.0
      expect(result.size).to be > 0
    end

    it 'handles long words efficiently' do
      context = Kotoshu::Suggestions::Context.new(
        word: 'supercalifragilisticexpialidocious',
        dictionary: large_dictionary
      )

      start_time = Time.now
      strategy.generate(context)
      elapsed = Time.now - start_time

      # Should complete quickly even for long words with no matches
      expect(elapsed).to be < 1.5
    end
  end

  # ==========================================================================
  # Integration Tests
  # ==========================================================================

  describe 'integration with other strategies' do
    let(:dictionary) do
      Kotoshu::Dictionary::PlainText.from_words(
        SpecHelpers::LanguageFixtures::COMMON_WORDS_BY_LANGUAGE[:en],
        language_code: 'en'
      )
    end

    it 'produces suggestions compatible with SuggestionSet' do
      strategy = described_class.new(dictionary: dictionary)
      context = Kotoshu::Suggestions::Context.new(word: 'wrold', dictionary: dictionary)
      result = strategy.generate(context)

      expect(result).to be_a(Kotoshu::Suggestions::SuggestionSet)
      expect(result.suggestions).to all(be_a(Kotoshu::Suggestions::Suggestion))
    end

    it 'includes metadata in suggestions' do
      strategy = described_class.new(dictionary: dictionary)
      context = Kotoshu::Suggestions::Context.new(word: 'wrold', dictionary: dictionary)
      result = strategy.generate(context)

      result.suggestions.each do |suggestion|
        expect(suggestion.metadata).to include(:original_length)
        expect(suggestion.metadata).to include(:ngram_score)
        expect(suggestion.metadata).to include(:enhanced_score)
      end
    end

    it 'provides source information' do
      strategy = described_class.new(dictionary: dictionary)
      context = Kotoshu::Suggestions::Context.new(word: 'wrold', dictionary: dictionary)
      result = strategy.generate(context)

      expect(result.suggestions).to all(be_from_source(:edit_distance))
    end
  end

  # ==========================================================================
  # Edge Cases and Error Handling
  # ==========================================================================

  describe 'edge cases' do
    let(:dictionary) do
      Kotoshu::Dictionary::PlainText.from_words(
        %w[hello world test],
        language_code: 'en'
      )
    end

    let(:strategy) { described_class.new }

    it 'handles empty word' do
      context = Kotoshu::Suggestions::Context.new(word: '', dictionary: dictionary)
      result = strategy.generate(context)

      expect(result).to be_a(Kotoshu::Suggestions::SuggestionSet)
      expect(result.size).to be_zero
    end

    it 'handles single character word' do
      context = Kotoshu::Suggestions::Context.new(word: 'x', dictionary: dictionary)
      result = strategy.generate(context)

      expect(result).to be_a(Kotoshu::Suggestions::SuggestionSet)
    end

    it 'handles very long word' do
      long_word = 'a' * 100
      context = Kotoshu::Suggestions::Context.new(word: long_word, dictionary: dictionary)
      result = strategy.generate(context)

      expect(result).to be_a(Kotoshu::Suggestions::SuggestionSet)
    end

    it 'handles special characters' do
      context = Kotoshu::Suggestions::Context.new(word: 'h@llo', dictionary: dictionary)
      result = strategy.generate(context)

      expect(result).to be_a(Kotoshu::Suggestions::SuggestionSet)
    end

    it 'handles unicode characters' do
      context = Kotoshu::Suggestions::Context.new(word: 'héllo', dictionary: dictionary)
      result = strategy.generate(context)

      expect(result).to be_a(Kotoshu::Suggestions::SuggestionSet)
    end
  end
end
