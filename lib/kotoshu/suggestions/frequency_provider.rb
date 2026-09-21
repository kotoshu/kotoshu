# frozen_string_literal: true

module Kotoshu
  module Suggestions
    # Loads and caches Kelly Project word-frequency tiers per language.
    #
    # Extracted from EditDistanceStrategy (TODO 56 T5.1 step 3, Phase A)
    # so that strategy construction no longer performs disk IO and
    # network access. The strategy holds a reference to a provider
    # instance; the provider encapsulates the tiered fallback
    # (FrequencyCache → frozen embedded tiers → local YAML → empty).
    # The frozen tier layer (plan 119) carries the same en tables the
    # Rust engine embeds, so a cache-cold machine ranks exactly like
    # the frozen conformance vectors instead of the differently
    # curated YAML.
    #
    # Also exposes the frequency full_list + rank map when the cached
    # Kelly/wiki-unigram file carries one (plan C6). SymSpellStrategy
    # indexes that compact list instead of the Hunspell lexicon so
    # compound-split junk never enters the candidate pool.
    #
    # The provider memoizes per-language data, so repeated lookups
    # for the same language are free after the first call.
    class FrequencyProvider
      EMPTY_TIERS = {
        top_50: Set.new,
        top_200: Set.new,
        top_1000: Set.new
      }.freeze

      EMPTY_DATA = {
        tiers: EMPTY_TIERS,
        full_list: [],
        ranks: {}
      }.freeze

      # @param frequency_cache [Cache::FrequencyCache, nil] Injectable
      #   cache instance (used by tests); defaults to a fresh
      #   FrequencyCache per load.
      def initialize(frequency_cache: nil)
        @frequency_cache = frequency_cache
        @data_by_language = {}
      end

      # Return the frequency tiers for +language_code+.
      #
      # @param language_code [String] ISO 639-1 language code
      # @return [Hash{Symbol => Set}] Hash with :top_50, :top_200, :top_1000
      def tiers_for(language_code)
        data_for(language_code)[:tiers]
      end

      # Compact frequency word list for SymSpell indexing (may be empty).
      #
      # @param language_code [String]
      # @return [Array<String>]
      def full_list_for(language_code)
        data_for(language_code)[:full_list]
      end

      # word.downcase => rank (1 = most frequent). Empty when unknown.
      #
      # @param language_code [String]
      # @return [Hash{String => Integer}]
      def ranks_for(language_code)
        data_for(language_code)[:ranks]
      end

      private

      def data_for(language_code)
        @data_by_language[language_code] ||= load(language_code)
      end

      # Lookup cascade: exact code first ("zh-Hant-TW" has its own
      # variant-pure list), then the BCP-47 base ("en-US" → "en" —
      # the default Configuration language must find the base list).
      # Memoized under the ORIGINAL key so repeated calls stay free.
      def load(language_code)
        code = language_code.to_s
        base = code.split("-").first
        ([code, base].uniq - [nil, ""]).each do |candidate|
          data = load_exact(candidate)
          return data if data
        end

        EMPTY_DATA
      end

      def load_exact(language_code)
        cache_result = try_load_from_frequency_cache(language_code)
        if cache_result && cache_result[:tiers] && cache_result[:tiers][:top_1000].any?
          return {
            tiers: cache_result[:tiers],
            full_list: cache_result[:full_list] || [],
            ranks: cache_result[:ranks] || {}
          }
        end

        frozen = FrozenTiers.tiers_for(language_code)
        return { tiers: frozen, full_list: [], ranks: {} } if frozen

        yaml_data = Data::CommonWordsLoader.load(language_code)
        if yaml_data[:tiers][:top_1000].any?
          return {
            tiers: yaml_data[:tiers],
            full_list: yaml_data[:full_list] || [],
            ranks: yaml_data[:ranks] || {}
          }
        end

        # nil — NOT EMPTY_DATA: a per-code miss must let the cascade
        # try the base language. (EMPTY_DATA is truthy and would
        # short-circuit it.)
        nil
      end

      def try_load_from_frequency_cache(language_code)
        cache = @frequency_cache || Cache::FrequencyCache.new
        # Read cache-only: the suggestion hot path must never trigger a
        # download. Any readable cached bytes win over the YAML fallback
        # (plan 117) — including install_local writes whose TTL marker
        # may not flip cached_data? in the same process.
        begin
          data = cache.load_cached(language_code)
          return data if data && data[:tiers] && data[:tiers][:top_1000]&.any?

          nil
        rescue StandardError => e
          warn "Warning: Failed to load frequency cache for #{language_code}: #{e.message}" if $VERBOSE
          nil
        end
      end
    end
  end
end
