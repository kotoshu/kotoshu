# frozen_string_literal: true

module Kotoshu
  # Two-stage resource resolution.
  #
  # Stage 1 — setup (slow, network-required, explicit):
  #   Kotoshu.setup(:en)                            # download from kotoshu/dictionaries
  #   Kotoshu.setup(:en, want: %i[spelling frequency])
  #   Kotoshu.setup(:en, aff: "/path/to.en.aff", dic: "/path/to/en.dic")  # local files
  #   Kotoshu.setup(:en, from: "/path/to/dict/dir/")                       # local directory
  #
  # Stage 2 — resolve (instant, cache-only, raises on miss):
  #   bundle = Kotoshu::ResourceManager.resolve(language: "en")
  #   bundle.dictionary  # => #<Dictionary::Hunspell ...>
  #
  # The hot path (Kotoshu.correct?, .check, .suggest, .spellchecker_for) calls
  # resolve and lets ResourceNotSetupError propagate. Setup is never implicit.
  class ResourceManager
    DEFAULT_WANT = %i[spelling].freeze

    SetupResult = Struct.new(
      :language,
      :spelling,    # :downloaded | :local | :cached | nil
      :frequency,   # :downloaded | :local | :cached | :unavailable | nil
      :model,       # :downloaded | :cached | :unavailable | nil
      :model_tier,  # :full | :fluency | :mini | nil (tier actually set up)
      :source,      # :kotoshu | :local
      keyword_init: true
    ) do
      def success?
        !spelling.nil? || !frequency.nil?
      end
    end

    class << self
      def setup(language, want: DEFAULT_WANT, force: false, strict: false, **opts)
        new.setup(language: language, want: want, force: force, strict: strict, **opts)
      end

      def setup_from_local(language:, aff:, dic:, frequency: nil, force: false)
        new.setup_from_local(language: language, aff: aff, dic: dic, frequency: frequency, force: force)
      end

      def resolve(language:, want: DEFAULT_WANT, tier: nil)
        new.resolve(language: language, want: want, tier: tier)
      end

      def setup?(language, resource: nil, tier: nil)
        new.setup?(language, resource: resource, tier: tier)
      end

      def languages_setup
        new.languages_setup
      end
    end

    # ---- Stage 1: setup ----

    def setup(language:, want: DEFAULT_WANT, force: false, strict: false, tier: nil,
              aff: nil, dic: nil, from: nil, frequency: nil)
      lang = normalize_language(language)

      if aff || dic || from
        setup_from_local(language: lang, aff: aff, dic: dic, from: from,
                         frequency: frequency, force: force)
      else
        setup_from_remote(lang, want: want, force: force, strict: strict, tier: tier)
      end
    end

    def setup_from_local(language:, aff:, dic:, from: nil, frequency: nil, force: false)
      lang = normalize_language(language)

      aff_path, dic_path = resolve_local_paths(lang, aff: aff, dic: dic, from: from)
      raise ArgumentError, "aff file not found: #{aff_path}" unless File.exist?(aff_path)
      raise ArgumentError, "dic file not found: #{dic_path}" unless File.exist?(dic_path)

      spelling_cache = spelling_cache_for(lang)
      spelling_cache.install_local(lang, aff: aff_path, dic: dic_path, force: force)
      spelling_status = :local

      frequency_status = nil
      if frequency
        raise ArgumentError, "frequency file not found: #{frequency}" unless File.exist?(frequency)

        freq_cache = frequency_cache_for
        freq_cache.install_local(lang, path: frequency, force: force)
        frequency_status = :local
      end

      SetupResult.new(
        language: lang,
        spelling: spelling_status,
        frequency: frequency_status,
        model: nil,
        source: :local
      )
    end

    # ---- Stage 2: resolve (cache-only) ----
    #
    # `tier:` selects which cached model tier to resolve. Default: the
    # configured `model_tier` ("full"). A missing tier raises
    # ResourceNotSetupError exactly like any other unset resource —
    # resolve never downloads and never falls back to another tier.
    # `tier: :any` (explicit opt-in only) maps to the single cached
    # tier; with zero or multiple cached tiers it raises.
    def resolve(language:, want: DEFAULT_WANT, tier: nil)
      lang = normalize_language(language)
      effective_tier = effective_tier(tier)

      spelling_dict = want.include?(:spelling) ? resolve_spelling_cached(lang) : nil
      frequency_data = want.include?(:frequency) ? resolve_frequency_cached(lang) : nil
      model = want.include?(:model) ? resolve_model_cached(lang, tier: effective_tier) : nil

      ResourceBundle.new(
        language: lang,
        dictionary: spelling_dict,
        frequency: frequency_data,
        model: model,
        rules: nil,
        cached: true,
        source_urls: []
      )
    end

    # ---- Predicates ----

    def setup?(language, resource: nil, tier: nil)
      lang = normalize_language(language)
      case resource&.to_sym
      when nil, :spelling
        spelling_cache_for(lang).available?("#{lang}:spelling")
      when :frequency
        fc = frequency_cache_for
        fc.supports_resource?(lang) && fc.available?(lang)
      when :model
        cache = model_cache_for
        if tier.nil?
          cache.available?(cache.tier_resource_id(lang, effective_tier(nil)))
        elsif tier.to_sym == :any
          cache.cached_tiers(lang).any?
        else
          cache.available?(cache.tier_resource_id(lang, tier))
        end
      else
        false
      end
    end

    def languages_setup
      spelling_cache_for(nil).cached_resources
        .map { |r| r.to_s.split(":").first }
        .uniq
        .sort
    end

    private

    def setup_from_remote(lang, want:, force:, strict:, tier: nil)
      config = Configuration.instance
      spelling_status = nil
      frequency_status = nil
      model_status = nil
      model_tier = nil

      if want.include?(:spelling)
        cache = spelling_cache_for(lang, config: config)
        was_cached = cache.available?("#{lang}:spelling")
        if was_cached && !force
          spelling_status = :cached
        else
          warn "[#{lang}] downloading spelling dictionary..." unless quiet?
          cache.get_spelling(lang, force_download: force)
          spelling_status = :downloaded
        end
      end

      if want.include?(:frequency)
        frequency_status = setup_frequency_remote(lang, force: force, strict: strict, config: config)
      end

      if want.include?(:model)
        model_tier = effective_tier(tier, config: config)
        model_status = setup_model_remote(lang, want: want, force: force, strict: strict, config: config, tier: model_tier)
      end

      SetupResult.new(
        language: lang,
        spelling: spelling_status,
        frequency: frequency_status,
        model: model_status,
        model_tier: model_tier,
        source: :kotoshu
      )
    end

    def setup_frequency_remote(lang, force:, strict:, config:)
      cache = frequency_cache_for(config: config)
      return :unavailable unless cache.supports_resource?(lang)

      was_cached = cache.available?(lang)
      return :cached if was_cached && !force

      warn "[#{lang}] downloading frequency data..." unless quiet?
      cache.get(lang, force_download: force)
      :downloaded
    rescue StandardError => e
      raise if strict

      warn "[#{lang}] frequency data unavailable: #{e.class} (#{e.message})" unless quiet?
      :unavailable
    end

    # Set up the ONNX model for `lang` at `tier`.
    #
    # full: today's behavior, byte for byte — AVAILABLE_MODELS gate,
    # git-tree URL, download-or-convert fallback. fluency/mini: the
    # registry-driven path with sha256 verification against the
    # registry entry. In both cases a cached model short-circuits to
    # :cached BEFORE any registry consultation, so offline hosts with
    # a warm cache (but no cached registry) still work.
    def setup_model_remote(lang, want:, force:, strict:, config:, tier: :full)
      tier = Cache::ModelCache.normalize_tier(tier)
      cache = model_cache_for(config: config)
      resource_id = cache.tier_resource_id(lang, tier)

      if tier == :full && !Cache::ModelCache::AVAILABLE_MODELS[:onnx].key?(lang.to_sym)
        return :unavailable
      end

      was_cached = cache.available?(resource_id)
      return :cached if was_cached && !force

      if tier != :full && cache.registry_entry_for(lang, tier).nil?
        warn "[#{lang}] no registry entry for tier #{tier}; available: #{tiers_for_language(cache, lang).join(', ')}" unless quiet?
        return :unavailable
      end

      warn "[#{lang}] downloading ONNX model (#{tier} tier)..." unless quiet?
      if tier == :full
        cache.get(resource_id, force_download: force)
      else
        cache.download_tiered_model(lang, tier: tier, force_download: force)
      end
      :downloaded
    rescue StandardError => e
      raise if strict

      warn "[#{lang}] ONNX model unavailable: #{e.class} (#{e.message})" unless quiet?
      :unavailable
    end

    def resolve_spelling_cached(lang)
      cache = spelling_cache_for(lang)
      resource_id = "#{lang}:spelling"
      raise ResourceNotSetupError.new(lang, "spelling") unless cache.available?(resource_id)

      result = cache.get(resource_id) || cache.load_cached(resource_id)
      raise ResourceNotSetupError.new(lang, "spelling") unless result

      Dictionary::Hunspell.new(
        dic_path: result[:dic_path] || result["dic_path"],
        aff_path: result[:aff_path] || result["aff_path"],
        language_code: lang
      )
    end

    def resolve_frequency_cached(lang)
      cache = frequency_cache_for
      return nil unless cache.supports_resource?(lang)
      raise ResourceNotSetupError.new(lang, "frequency") unless cache.available?(lang)

      begin
        cache.get(lang)
      rescue StandardError
        nil
      end
    end

    # Resolve the cached model for `lang` at `tier` (cache-only —
    # never downloads, never consults the network-side registry).
    #
    # :any maps to the single cached tier; zero or multiple cached
    # tiers raise (deterministic: ambiguity errors list tiers in
    # Cache::ModelCache::TIER_PREFERENCE order — mini, fluency, full —
    # which is a reporting order, not a fallback chain).
    def resolve_model_cached(lang, tier: :full)
      cache = model_cache_for
      return nil unless model_language_supported?(lang, cache)

      if tier.to_sym == :any
        cached = cache.cached_tiers(lang)
        case cached.size
        when 1
          return resolve_tier_cached(lang, cached.first, cache)
        when 0
          raise ResourceNotSetupError.new(lang, "model (no tier cached)")
        else
          raise ResourceResolutionError.new(
            lang,
            "multiple model tiers cached (#{cached.join(', ')}); " \
            "pass tier: one of #{cached.join('|')} explicitly"
          )
        end
      end

      resolve_tier_cached(lang, Cache::ModelCache.normalize_tier(tier), cache)
    end

    def resolve_tier_cached(lang, tier, cache)
      resource_id = cache.tier_resource_id(lang, tier)
      missing = tier == :full ? "model" : "model tier '#{tier}'"
      raise ResourceNotSetupError.new(lang, missing) unless cache.available?(resource_id)

      begin
        cache.get(resource_id)
      rescue StandardError
        nil
      end
    end

    # Whether `lang` can have a model at all: listed in AVAILABLE_MODELS
    # (full-tier gate, unchanged) or any tier already cached on disk.
    def model_language_supported?(lang, cache)
      Cache::ModelCache::AVAILABLE_MODELS[:onnx].key?(lang.to_sym) ||
        cache.cached_tiers(lang).any?
    end

    # The tier a tier-less call means: an explicit argument wins, then
    # the configured `model_tier` (default "full" — an owner decision
    # per plan 67's gates, not tooling's to change).
    def effective_tier(tier, config: nil)
      return :any if tier && tier.to_sym == :any

      Cache::ModelCache.normalize_tier(tier || (config || Configuration.instance).model_tier)
    end

    # Registry tiers available for a language (for diagnostics; may
    # consult the cached registry, never used on the resolve path).
    def tiers_for_language(cache, lang)
      Cache::ModelCache::TIERS.select do |t|
        t == :full ? Cache::ModelCache::AVAILABLE_MODELS[:onnx].key?(lang.to_sym) : cache.registry_entry_for(lang, t)
      end
    end

    def resolve_local_paths(lang, aff:, dic:, from:)
      if from
        dir = File.expand_path(from)
        aff_path = aff || File.join(dir, "#{lang}.aff")
        dic_path = dic || File.join(dir, "#{lang}.dic")
        [aff_path, dic_path]
      else
        [File.expand_path(aff), File.expand_path(dic)]
      end
    end

    def normalize_language(code)
      code.to_s.split("-").first.split("_").first.downcase
    end

    def spelling_cache_for(_lang = nil, config: nil)
      cfg = config || Configuration.instance
      Cache::LanguageCache.new(
        cache_path: cfg.cache_path,
        resource_pin: cfg.resource_pin
      )
    end

    def frequency_cache_for(config: nil)
      cfg = config || Configuration.instance
      Cache::FrequencyCache.new(
        cache_path: cfg.cache_path,
        resource_pin: cfg.resource_pin
      )
    end

    def model_cache_for(config: nil)
      cfg = config || Configuration.instance
      Cache::ModelCache.new(
        cache_path: cfg.cache_path
      )
    end

    def quiet?
      !$stderr.tty? || ENV["KOTOSHU_QUIET"] == "1"
    end
  end
end
