# frozen_string_literal: true

module Kotoshu
  module Suggestions
    # Loads and caches Kelly Project word-frequency tiers per language.
    #
    # Extracted from EditDistanceStrategy (TODO 56 T5.1 step 3, Phase A)
    # so that strategy construction no longer performs disk IO and
    # network access. The strategy holds a reference to a provider
    # instance; the provider encapsulates the tiered fallback
    # (FrequencyCache → local YAML → empty).
    #
    # The provider memoizes per-language tiers, so repeated lookups
    # for the same language are free after the first call.
    class FrequencyProvider
      EMPTY_TIERS = {
        top_50: Set.new,
        top_200: Set.new,
        top_1000: Set.new
      }.freeze

      # @param frequency_cache [Cache::FrequencyCache, nil] Injectable
      #   cache instance (used by tests); defaults to a fresh
      #   FrequencyCache per load.
      def initialize(frequency_cache: nil)
        @frequency_cache = frequency_cache
        @tiers_by_language = {}
      end

      # Return the frequency tiers for +language_code+.
      #
      # @param language_code [String] ISO 639-1 language code
      # @return [Hash{Symbol => Set}] Hash with :top_50, :top_200, :top_1000
      def tiers_for(language_code)
        @tiers_by_language[language_code] ||= load(language_code)
      end

      private

      def load(language_code)
        cache_result = try_load_from_frequency_cache(language_code)
        return cache_result[:tiers] if cache_result && cache_result[:tiers] && cache_result[:tiers][:top_1000].any?

        yaml_data = Data::CommonWordsLoader.load(language_code)
        return yaml_data[:tiers] if yaml_data[:tiers][:top_1000].any?

        EMPTY_TIERS
      end

      def try_load_from_frequency_cache(language_code)
        cache = @frequency_cache || Cache::FrequencyCache.new
        # Ask about actual cache state (TTL-aware available?), not the
        # static supported-language list — and read cache-only. The
        # suggestion hot path must never trigger a download; downloads
        # happen only through explicit setup (Kotoshu.setup /
        # kotoshu cache download).
        return nil unless cache.available?(language_code)

        begin
          cache.load_cached(language_code)
        rescue StandardError => e
          warn "Warning: Failed to load frequency cache for #{language_code}: #{e.message}" if $VERBOSE
          nil
        end
      end
    end
  end
end
