# frozen_string_literal: true

require_relative "resource_bundle"
require_relative "cache/language_cache"
require_relative "cache/frequency_cache"
require_relative "dictionary/hunspell"
require_relative "core/exceptions"

module Kotoshu
  # Resolves language resources (dictionaries, frequency data, models,
  # grammar rules) on demand, using the existing cache layer.
  #
  # @example Resolve English resources
  #   bundle = Kotoshu::ResourceManager.resolve(language: "en")
  #   bundle.dictionary  # => #<Dictionary::Hunspell ...>
  #
  # @example Auto-detect language from text
  #   bundle = Kotoshu::ResourceManager.resolve(text: "Guten Tag")
  #   bundle.language  # => "de"
  #
  # @example Offline mode (cached resources only)
  #   bundle = Kotoshu::ResourceManager.resolve(language: "en", offline: true)
  #   # raises ResourceNotCachedError if not pre-fetched
  class ResourceManager
    DEFAULT_WANT = %i[spelling].freeze

    class << self
      # Resolve resources for a language or text.
      #
      # @param text [String, nil] Text to detect language from
      # @param language [String, Symbol, nil] Language code or :auto
      # @param want [Array<Symbol>] Resource types: :spelling, :frequency
      # @param offline [Boolean, nil] Override offline mode
      # @param strict [Boolean, nil] Override strict mode (re-raise on optional-resource failure)
      # @return [ResourceBundle]
      def resolve(text: nil, language: nil, want: DEFAULT_WANT, offline: nil, strict: nil)
        new.resolve(text: text, language: language, want: want, offline: offline, strict: strict)
      end
    end

    # Resolve resources (instance method).
    #
    # @see .resolve
    def resolve(text: nil, language: nil, want: DEFAULT_WANT, offline: nil, strict: nil)
      config = Configuration.instance
      offline = config.offline if offline.nil?
      strict = false if strict.nil?

      lang = resolve_language(text, language, config)

      spelling_result = want.include?(:spelling) ? resolve_spelling(lang, offline) : nil
      frequency_result = want.include?(:frequency) ? resolve_frequency(lang, offline, strict) : nil

      ResourceBundle.new(
        language: lang,
        dictionary: spelling_result&.first,
        frequency: frequency_result,
        model: nil,
        rules: nil,
        cached: spelling_result ? spelling_result.last : true,
        source_urls: [config.dictionaries_url]
      )
    end

    private

    def resolve_language(text, language, config)
      return normalize_language(language) if language && language != :auto
      return config.default_language if text.nil? || text.strip.empty?

      detected = safe_detect(text)
      detected || config.default_language
    end

    def safe_detect(text)
      Language.detect(text)
    rescue StandardError
      nil
    end

    def resolve_spelling(lang, offline)
      cache = Cache::LanguageCache.new(
        cache_path: Configuration.instance.cache_path,
        resource_pin: Configuration.instance.resource_pin
      )
      resource_id = "#{lang}:spelling"
      was_cached = cache.available?(resource_id)

      raise ResourceNotCachedError.new(lang, "spelling") if offline && !was_cached

      warn "[#{lang}] downloading dictionary..." unless was_cached || quiet?

      result = cache.get_spelling(lang)
      dict = Dictionary::Hunspell.new(
        dic_path: result[:dic_path],
        aff_path: result[:aff_path],
        language_code: lang
      )
      [dict, result[:cached] != false]
    end

    def resolve_frequency(lang, offline, strict = false)
      cache = Cache::FrequencyCache.new(
        cache_path: Configuration.instance.cache_path,
        resource_pin: Configuration.instance.resource_pin
      )
      return nil unless cache.supports_resource?(lang)

      raise ResourceNotCachedError.new(lang, "frequency") if offline && !cache.available?(lang)

      warn "[#{lang}] downloading frequency data..." unless cache.available?(lang) || quiet?

      cache.get(lang)
    rescue StandardError => e
      raise if strict

      warn "[#{lang}] frequency data unavailable: #{e.class} (#{e.message})" unless quiet?
      nil
    end

    def normalize_language(code)
      code.to_s.split("-").first.split("_").first.downcase
    end

    def quiet?
      !$stderr.tty? || ENV["KOTOSHU_QUIET"] == "1"
    end
  end
end
