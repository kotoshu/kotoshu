# frozen_string_literal: true

require 'yaml'
require 'set'
require 'fileutils'

module Kotoshu
  module Data
    # Loads and provides access to common words data for all supported languages.
    #
    # This loader supports loading from:
    # 1. Local YAML files in lib/kotoshu/data/common_words/{language}.yml
    # 2. Frequency.json files downloaded from GitHub (via LanguageCache)
    #
    # Each language file contains:
    # - metadata: Source information, word count, last updated
    # - tiers: Top 50, top 200, and top 1000 most common words
    #
    # @example Loading English common words
    #   loader = CommonWordsLoader.new
    #   tiers = loader.load('en')
    #   tiers[:top_50].include?('the')  # => true
    #
    # @example Getting available languages
    #   CommonWordsLoader.available_languages  # => ['de', 'en', 'es', 'fr', 'pt', 'ru']
    #
    # @example Loading with tier specification
    #   loader.load('en', tier: :top_200)  # Combines top_50 + top_200
    class CommonWordsLoader
      # Default data directory (local YAML files)
      DATA_DIR = File.expand_path('../common_words', __FILE__).freeze

      class << self
        # Load common words for a language.
        #
        # @param language_code [String] ISO 639-1 language code (e.g., 'en', 'de')
        # @param tier [Symbol] Tier level: :top_50, :top_200, or :top_1000
        # @return [Hash{Symbol => Set}] Hash with :tiers (tier sets) and :metadata
        def load(language_code, tier: :top_1000)
          yaml_file = File.join(DATA_DIR, "#{language_code}.yml")

          if File.exist?(yaml_file)
            load_from_yaml(yaml_file, tier)
          else
            {
              tiers: empty_tiers,
              metadata: { source: 'none', language: language_code }
            }
          end
        end

        # Load from GitHub frequency.json (Phase 2 integration).
        # Also handles Kelly frequency-list format from kotoshu/frequency-list-kelly
        #
        # @param language_code [String] ISO 639-1 language code
        # @param frequency_path [String] Path to frequency.json file
        # @return [Hash{Symbol => Set}] Hash with :tiers and :metadata
        def load_from_frequency_file(frequency_path)
          return { tiers: empty_tiers, metadata: {} } unless File.exist?(frequency_path)

          data = JSON.parse(File.read(frequency_path, encoding: 'UTF-8'))

          # Handle Kelly format: tiers[tier_name]['words']
          # Check if format has nested 'words' key (Kelly format)
          has_words_key = data.dig('tiers', 'top_50', 'words')

          tiers = if has_words_key
                    # Kelly format: data['tiers']['top_50']['words']
                    {
                      top_50: Set.new(data.dig('tiers', 'top_50', 'words') || []),
                      top_200: Set.new(
                        (data.dig('tiers', 'top_50', 'words') || []) +
                        (data.dig('tiers', 'top_200', 'words') || [])
                      ),
                      top_1000: Set.new(
                        (data.dig('tiers', 'top_50', 'words') || []) +
                        (data.dig('tiers', 'top_200', 'words') || []) +
                        (data.dig('tiers', 'top_1000', 'words') || [])
                      )
                    }
                  else
                    # Legacy format: data['tiers']['top_50'] is array
                    {
                      top_50: Set.new(data.dig('tiers', 'top_50') || []),
                      top_200: Set.new((data.dig('tiers', 'top_50') || []) + (data.dig('tiers', 'top_200') || [])),
                      top_1000: Set.new(
                        (data.dig('tiers', 'top_50') || []) +
                        (data.dig('tiers', 'top_200') || []) +
                        (data.dig('tiers', 'top_1000') || [])
                      )
                    }
                  end

          metadata = data['metadata'] || {}

          { tiers: tiers, metadata: metadata }
        end

        # Get list of languages with local YAML files.
        #
        # @return [Array<String>] List of available language codes
        def available_languages
          Dir.glob(File.join(DATA_DIR, '*.yml')).map { |f| File.basename(f, '.yml') }
        end

        # Check if a language has local data.
        #
        # @param language_code [String] ISO 639-1 language code
        # @return [Boolean] True if data file exists
        def available?(language_code)
          File.exist?(File.join(DATA_DIR, "#{language_code}.yml"))
        end

        private

        def load_from_yaml(yaml_file, requested_tier)
          data = YAML.unsafe_load_file(yaml_file)

          # Get all tiers from the data
          yaml_tiers = data['tiers'] || {}

          # Build cumulative tiers based on requested level
          tier_50 = Set.new(yaml_tiers['top_50'] || [])
          tier_200 = Set.new((yaml_tiers['top_50'] || []) + (yaml_tiers['top_200'] || []))
          tier_1000 = Set.new(
            (yaml_tiers['top_50'] || []) +
            (yaml_tiers['top_200'] || []) +
            (yaml_tiers['top_1000'] || [])
          )

          tiers = {
            top_50: tier_50,
            top_200: tier_200,
            top_1000: tier_1000
          }

          metadata = data['metadata'] || {}

          { tiers: tiers, metadata: metadata }
        end

        def empty_tiers
          {
            top_50: Set.new,
            top_200: Set.new,
            top_1000: Set.new
          }
        end
      end
    end
  end
end
