# frozen_string_literal: true

module Kotoshu
  # Language module for multi-language support.
  #
  # Provides language detection, tokenization, and normalization
  # for different languages with proper OOP design.
  #
  # @example Detect language
  #   Kotoshu::Language.detect("Hello world")  # => "en"
  #
  # @example Get language class
  #   lang_class = Kotoshu::Language.get("en-US")
  #
  # @example List supported languages
  #   Kotoshu::Language.supported_codes  # => ["de-DE", "en-US", ...]
  module Language
    autoload :Registry, "kotoshu/language/registry"
    autoload :Detector, "kotoshu/language/detector"
    autoload :LanguageIdentifier, "kotoshu/language/identifier"
    autoload :Segmenter, "kotoshu/language/segmenter"
    autoload :Segment, "kotoshu/language/segmenter"
    autoload :Suika, "kotoshu/language/suika"

    module Tokenizer
      autoload :Base, "kotoshu/language/tokenizer/base"
      autoload :LatinTokenizer, "kotoshu/language/tokenizer/latin_tokenizer"
      autoload :FrenchTokenizer, "kotoshu/language/tokenizer/french_tokenizer"
      autoload :GermanTokenizer, "kotoshu/language/tokenizer/german_tokenizer"
      autoload :SpanishTokenizer, "kotoshu/language/tokenizer/spanish_tokenizer"
      autoload :PortugueseTokenizer, "kotoshu/language/tokenizer/portuguese_tokenizer"
      autoload :RussianTokenizer, "kotoshu/language/tokenizer/russian_tokenizer"
      autoload :JapaneseTokenizer, "kotoshu/language/tokenizer/japanese_tokenizer"
    end

    module Normalizer
      autoload :Base, "kotoshu/language/normalizer/base"
      autoload :Arabic, "kotoshu/language/normalizer/arabic"
      autoload :Hebrew, "kotoshu/language/normalizer/hebrew"
    end

    # Base class for per-language implementations (Kotoshu::Languages::*).
    # File path is historical (languages/base.rb under language/).
    autoload :Base, "kotoshu/language/languages/base"

    class << self
      # Detect language from text.
      #
      # Delegates to Detector.
      #
      # @param text [String] Text to analyze
      # @return [String, nil] Detected language code
      def detect(text)
        Detector.detect(text)
      end

      # Detect with confidence score.
      #
      # @param text [String] Text to analyze
      # @return [Array<String, Float>] Language code and confidence
      def detect_with_confidence(text)
        Detector.detect_with_confidence(text)
      end

      # Get language class by code.
      #
      # Delegates to Registry.
      #
      # @param code [String] Language code
      # @return [Class, nil] Language class or nil
      def get(code)
        Registry.get(code)
      end

      # Check if language is registered.
      #
      # @param code [String] Language code
      # @return [Boolean] True if registered
      def registered?(code)
        Registry.registered?(code)
      end

      # Get all supported language codes.
      #
      # @return [Array<String>] List of codes
      def supported_codes
        Registry.supported_codes
      end

      # Get language info.
      #
      # @param code [String] Language code
      # @return [Hash, nil] Language info or nil
      def info(code)
        Registry.info(code)
      end

      # Register a language.
      #
      # @param code [String] Language code
      # @param klass [Class] Language class
      # @return [void]
      def register(code, klass)
        Registry.register(code, klass)
      end
    end
  end
end

# Register the default detector with the registry.
# Both Registry and Detector are autoloaded above; referencing them
# here triggers their loads.
Kotoshu::Language::Registry.register_detector(Kotoshu::Language::Detector)
