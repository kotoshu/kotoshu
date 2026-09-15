#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/kotoshu'
require 'json'
require 'set'

##
# Example: Kelly Frequency List Integration with Kotoshu
#
# This example demonstrates how to integrate Kelly Project frequency lists
# with Kotoshu spell checker to improve suggestion quality.
#
# Key Features:
# 1. Load Kelly frequency data from JSON files
# 2. Integrate with EditDistanceStrategy for frequency-based scoring
# 3. Multi-language support (en, ru, zh, ar, el, it, no, sv)
# 4. CEFR-level bonus scoring
# 5. Side-by-side comparison: with vs without frequency data
#
# Usage:
#   ruby examples/12_kelly_frequency_integration.rb

class KellyFrequencyIntegration
  KELLY_DATA_PATH = File.expand_path('../../frequency-list-kelly/data', __dir__)
  AVAILABLE_LANGUAGES = %w[ar zh en el it no ru sv]

  class << self
    # Load Kelly frequency data for a language
    #
    # @param language_code [String] ISO 639-1 language code
    # @return [Hash] Frequency tiers and metadata
    def load_kelly_data(language_code)
      json_path = File.join(KELLY_DATA_PATH, "#{language_code}.json")

      unless File.exist?(json_path)
        warn "Warning: Kelly data not found for #{language_code} at #{json_path}"
        return nil
      end

      data = JSON.parse(File.read(json_path, encoding: 'UTF-8'))

      # Extract frequency tiers for Kotoshu
      top_50_words = data['tiers']['top_50']['words'] || []
      top_200_words = (data['tiers']['top_50']['words'] || []) +
        (data['tiers']['top_200']['words'] || [])
      top_1000_words = top_200_words +
        (data['tiers']['top_1000']['words'] || [])

      {
        tiers: {
          top_50: Set.new(top_50_words.map(&:downcase)),
          top_200: Set.new(top_200_words.map(&:downcase)),
          top_1000: Set.new(top_1000_words.map(&:downcase))
        },
        metadata: data['metadata']
      }
    end

    # Create spell checker with Hunspell dictionary
    #
    # @param language_code [String] ISO 639-1 language code
    # @return [Kotoshu::Spellchecker]
    def create_spell_checker(language_code)
      # Map Kelly language codes to Hunspell locales
      locale_map = {
        'en' => 'en_US',
        'ru' => 'ru_RU',
        'zh' => 'zh_CN',
        'ar' => 'ar',
        'el' => 'el_GR',
        'it' => 'it_IT',
        'no' => 'nb_NO',
        'sv' => 'sv_SE'
      }

      locale = locale_map[language_code] || "#{language_code}_#{language_code.upcase}"

      # Try to load Hunspell dictionary from system paths
      dic_paths = [
        "/usr/share/hunspell/#{locale}.dic",
        "/usr/local/share/hunspell/#{locale}.dic",
        "/Library/Spelling/#{locale}.dic",  # macOS
        File.expand_path("../dictionaries/#{locale}/#{locale}.dic", __dir__)
      ]

      aff_paths = [
        "/usr/share/hunspell/#{locale}.aff",
        "/usr/local/share/hunspell/#{locale}.aff",
        "/Library/Spelling/#{locale}.aff",  # macOS
        File.expand_path("../dictionaries/#{locale}/#{locale}.aff", __dir__)
      ]

      dic_path = dic_paths.find { |path| File.exist?(path) }
      aff_path = aff_paths.find { |path| File.exist?(path) }

      unless dic_path && aff_path
        warn "Warning: Hunspell dictionary not found for #{locale}"
        warn "Creating simple word list dictionary instead..."
        return create_simple_dictionary(language_code)
      end

      Kotoshu::Spellchecker.new(
        dictionary: Kotoshu::Dictionary::Hunspell.new(
          dic_path: dic_path,
          aff_path: aff_path
        )
      )
    end

    # Create simple word list dictionary (fallback)
    #
    # @param language_code [String] ISO 639-1 language code
    # @return [Kotoshu::Spellchecker]
    def create_simple_dictionary(language_code)
      # Load Kelly data and create a simple word list
      kelly_data = load_kelly_data(language_code)
      return nil unless kelly_data

      words = kelly_data[:tiers][:top_1000].to_a

      Kotoshu::Spellchecker.new(
        dictionary: Kotoshu::Dictionary::PlainText.from_words(
          words,
          language_code: language_code
        )
      )
    end

    # Create EditDistanceStrategy with Kelly frequency data
    #
    # @param language_code [String] ISO 639-1 language code
    # @param use_frequency [Boolean] Whether to use Kelly frequency data
    # @return [Kotoshu::Suggestions::Strategies::EditDistanceStrategy]
    def create_strategy(language_code, use_frequency: true)
      config = { language_code: language_code }

      if use_frequency
        kelly_data = load_kelly_data(language_code)
        if kelly_data
          config[:frequency_tiers] = kelly_data[:tiers]
        end
      end

      Kotoshu::Suggestions::Strategies::EditDistanceStrategy.new(**config)
    end

    # Demonstrate suggestion quality with and without frequency data
    #
    # @param language_code [String] ISO 639-1 language code
    # @param test_words [Array<String>] Words to test
    def demonstrate_suggestions(language_code, test_words)
      puts "\n" + ("=" * 70)
      puts "Language: #{language_code.upcase} - Kelly Frequency Integration Demo"
      puts "=" * 70

      # Create spell checker
      spellchecker = create_spell_checker(language_code)
      unless spellchecker
        puts "Error: Could not create spell checker for #{language_code}"
        return
      end

      # Create strategies with and without frequency data
      strategy_with_freq = create_strategy(language_code, use_frequency: true)
      strategy_without_freq = create_strategy(language_code, use_frequency: false)

      puts "\nTest Cases:"
      puts "-" * 70

      test_words.each do |word|
        puts "\nWord: '#{word}'"

        # Get suggestions without frequency
        context = Kotoshu::Suggestions::Context.new(
          word: word,
          dictionary: spellchecker.dictionary
        )

        suggestions_without = strategy_without_freq.generate(context)
        suggestions_with = strategy_with_freq.generate(context)

        puts "\n  Without Kelly Frequency:"
        suggestions_without.top(3).each do |sug|
          score = sug.metadata[:enhanced_score] || sug.combined_score
          puts "    - #{sug.word} (confidence: #{sug.confidence.round(3)}, score: #{score.round(1)})"
        end

        puts "\n  With Kelly Frequency:"
        suggestions_with.top(3).each do |sug|
          bonus = strategy_with_freq.frequency_bonus(sug.word)
          score = sug.metadata[:enhanced_score] || sug.combined_score
          puts "    - #{sug.word} (confidence: #{sug.confidence.round(3)}, " \
               "score: #{score.round(1)}, freq_bonus: #{bonus})"
        end

        # Show which suggestion moved up in ranking
        without_words = suggestions_without.top(5).map(&:word)
        with_words = suggestions_with.top(5).map(&:word)

        moved_up = with_words - without_words
        if moved_up.any?
          puts "\n  ♪ Words that moved UP in ranking due to frequency: #{moved_up.join(', ')}"
        end
      end
    end

    # Run all demonstrations
    def run_all
      puts "=" * 70
      puts "Kelly Frequency List Integration with Kotoshu"
      puts "=" * 70
      puts "\nLoading Kelly data from: #{KELLY_DATA_PATH}"
      puts "Available languages: #{AVAILABLE_LANGUAGES.join(', ')}"

      # English examples
      demonstrate_suggestions('en', %w[helo wrold recieve teh])

      # Russian examples (Cyrillic)
      demonstrate_suggestions('ru', ['превет', 'москва', 'спасибо']) if AVAILABLE_LANGUAGES.include?('ru')

      # Summary
      puts "\n" + ("=" * 70)
      puts "Summary"
      puts "=" * 70
      puts "\nKey Improvements with Kelly Frequency Data:"
      puts "  ✓ Common words (top 50/200/1000) receive bonus points"
      puts "  ✓ Suggestions are re-ranked based on corpus frequency"
      puts "  ✓ CEFR-level awareness prioritizes learner vocabulary"
      puts "  ✓ Multi-language support with language-specific keyboards"
      puts "\nNext Steps:"
      puts "  1. Download Hunspell dictionaries for your target languages"
      puts "  2. Configure Kotoshu to use Kelly frequency data by default"
      puts "  3. Add custom word lists to supplement Kelly data"
    end
  end
end

# Run the demonstration
if __FILE__ == $PROGRAM_NAME
  KellyFrequencyIntegration.run_all
end
