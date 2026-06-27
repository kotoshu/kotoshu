# frozen_string_literal: true

module Kotoshu
  # Single source of truth for where each remote resource lives.
  #
  # Every URL the cache layer fetches is built here. Caches do not
  # construct URL strings inline. Per-repo pins honor that
  # `kotoshu/dictionaries` ships on `v1` while the other repos are on
  # `main`, which previously caused silent 404s on first-use.
  #
  # @example
  #   registry = Kotoshu::SourceRegistry.new
  #   registry.url_for(:spelling, lang: "en", ext: "aff")
  #   # => "https://raw.githubusercontent.com/kotoshu/dictionaries/v1/en/spelling/index.aff"
  class SourceRegistry
    Source = Struct.new(:repo, :default_pin, :template, keyword_init: true)

    DEFAULT_BASE_URL = "https://raw.githubusercontent.com/kotoshu"

    # @return [Hash<Symbol, Source>]
    SOURCES = {
      spelling:         Source.new(repo: "dictionaries",         default_pin: "v1",   template: "dictionaries/%<pin>s/%<lang>s/spelling/index.%<ext>s"),
      grammar:          Source.new(repo: "dictionaries",         default_pin: "v1",   template: "dictionaries/%<pin>s/%<lang>s/grammar/rules.yaml"),
      dict_manifest:    Source.new(repo: "dictionaries",         default_pin: "v1",   template: "dictionaries/%<pin>s/manifest.json"),
      frequency:        Source.new(repo: "frequency-list-kelly", default_pin: "main", template: "frequency-list-kelly/%<pin>s/data/%<lang>s.json"),
      freq_manifest:    Source.new(repo: "frequency-list-kelly", default_pin: "main", template: "frequency-list-kelly/%<pin>s/manifest.json"),
      model:            Source.new(repo: "models-fasttext-onnx", default_pin: "main", template: "models-fasttext-onnx/%<pin>s/models/%<lang>s/fasttext.%<lang>s.onnx"),
      model_vocab:      Source.new(repo: "models-fasttext-onnx", default_pin: "main", template: "models-fasttext-onnx/%<pin>s/models/%<lang>s/fasttext.%<lang>s.vocab.json"),
      model_manifest:   Source.new(repo: "models-fasttext-onnx", default_pin: "main", template: "models-fasttext-onnx/%<pin>s/manifest.json")
    }.freeze

    # @param base_url [String] GitHub raw root, no trailing slash.
    # @param pins [Hash<String, String>] Optional per-repo pin overrides
    #   keyed by repo name (e.g. `{ "dictionaries" => "v2" }`).
    def initialize(base_url: DEFAULT_BASE_URL, pins: {})
      @base_url = base_url.to_s.chomp("/")
      @pins = pins.transform_keys(&:to_s).freeze
    end

    # @return [String] Configured GitHub raw root (no trailing slash).
    attr_reader :base_url

    # @param source_key [Symbol] One of `SOURCES.keys`.
    # @param lang [String, nil] Language code, interpolated into template.
    # @param ext [String, nil] File extension, interpolated into template.
    # @return [String] Fully-qualified URL.
    def url_for(source_key, lang: nil, ext: nil)
      source = SOURCES.fetch(source_key) do
        raise ArgumentError, "unknown source: #{source_key.inspect}"
      end
      path = source.template % { pin: pin_for(source), lang: lang, ext: ext }
      "#{@base_url}/#{path}"
    end

    # @param source_key [Symbol]
    # @return [String] Resolved pin (override or default).
    def pin_for_source(source_key)
      source = SOURCES.fetch(source_key)
      pin_for(source)
    end

    # @param source_key [Symbol]
    # @return [String] Repo name (e.g. "dictionaries").
    def repo_for(source_key)
      SOURCES.fetch(source_key).repo
    end

    private

    def pin_for(source)
      @pins.fetch(source.repo, source.default_pin)
    end
  end
end
