# frozen_string_literal: true

require_relative "resource_bundle"
require_relative "cache/language_cache"
require_relative "cache/frequency_cache"
require_relative "cache/model_cache"
require_relative "dictionary/hunspell"
require_relative "core/exceptions"

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

      def resolve(language:, want: DEFAULT_WANT)
        new.resolve(language: language, want: want)
      end

      def setup?(language, resource: nil)
        new.setup?(language, resource: resource)
      end

      def languages_setup
        new.languages_setup
      end
    end

    # ---- Stage 1: setup ----

    def setup(language:, want: DEFAULT_WANT, force: false, strict: false,
              aff: nil, dic: nil, from: nil, frequency: nil)
      lang = normalize_language(language)

      if aff || dic || from
        setup_from_local(language: lang, aff: aff, dic: dic, from: from,
                         frequency: frequency, force: force)
      else
        setup_from_remote(lang, want: want, force: force, strict: strict)
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
        freq_cache.install_local(lang, path: frequency, force: force) if freq_cache.respond_to?(:install_local)
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

    def resolve(language:, want: DEFAULT_WANT)
      lang = normalize_language(language)

      spelling_dict = want.include?(:spelling) ? resolve_spelling_cached(lang) : nil
      frequency_data = want.include?(:frequency) ? resolve_frequency_cached(lang) : nil
      model = want.include?(:model) ? resolve_model_cached(lang) : nil

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

    def setup?(language, resource: nil)
      lang = normalize_language(language)
      case resource&.to_sym
      when nil, :spelling
        spelling_cache_for(lang).available?("#{lang}:spelling")
      when :frequency
        fc = frequency_cache_for
        fc.respond_to?(:supports_resource?) && fc.supports_resource?(lang) && fc.available?(lang)
      when :model
        model_cache_for.available?("#{lang}:onnx")
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

    def setup_from_remote(lang, want:, force:, strict:)
      config = Configuration.instance
      spelling_status = nil
      frequency_status = nil
      model_status = nil

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
        model_status = setup_model_remote(lang, want: want, force: force, strict: strict, config: config)
      end

      SetupResult.new(
        language: lang,
        spelling: spelling_status,
        frequency: frequency_status,
        model: model_status,
        source: :kotoshu
      )
    end

    def setup_frequency_remote(lang, force:, strict:, config:)
      cache = frequency_cache_for(config: config)
      return :unavailable unless cache.respond_to?(:supports_resource?) && cache.supports_resource?(lang)

      was_cached = cache.available?(lang)
      return :cached if was_cached && !force

      warn "[#{lang}] downloading frequency data..." unless quiet?
      cache.get(lang, force_download: force) if cache.respond_to?(:get)
      :downloaded
    rescue StandardError => e
      raise if strict

      warn "[#{lang}] frequency data unavailable: #{e.class} (#{e.message})" unless quiet?
      :unavailable
    end

    def setup_model_remote(lang, want:, force:, strict:, config:)
      return :unavailable unless Cache::ModelCache::AVAILABLE_MODELS[:onnx].key?(lang.to_sym)

      cache = model_cache_for(config: config)
      resource_id = "#{lang}:onnx"
      was_cached = cache.available?(resource_id)
      return :cached if was_cached && !force

      warn "[#{lang}] downloading ONNX model..." unless quiet?
      cache.get(resource_id, force_download: force)
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
      return nil unless cache.respond_to?(:supports_resource?) && cache.supports_resource?(lang)
      raise ResourceNotSetupError.new(lang, "frequency") unless cache.available?(lang)

      begin
        cache.get(lang)
      rescue StandardError
        nil
      end
    end

    def resolve_model_cached(lang)
      cache = model_cache_for
      resource_id = "#{lang}:onnx"
      return nil unless Cache::ModelCache::AVAILABLE_MODELS[:onnx].key?(lang.to_sym)
      raise ResourceNotSetupError.new(lang, "model") unless cache.available?(resource_id)

      begin
        cache.get(resource_id)
      rescue StandardError
        nil
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
