# frozen_string_literal: true

require_relative "language/registry"
require_relative "language/detector"
require_relative "language/suika"
require_relative "language/tokenizer/base"
require_relative "language/tokenizer/latin_tokenizer"
require_relative "language/tokenizer/french_tokenizer"
require_relative "language/tokenizer/german_tokenizer"
require_relative "language/tokenizer/spanish_tokenizer"
require_relative "language/tokenizer/portuguese_tokenizer"
require_relative "language/tokenizer/russian_tokenizer"
require_relative "language/tokenizer/japanese_tokenizer"
require_relative "language/normalizer/base"
require_relative "language/languages/base"

# Load all language-specific modules from new structure (languages/{en,fr,de,ja,pt,ru,es}/)
require_relative "languages"

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
    # Register the default detector with the registry
    Registry.register_detector(Detector)

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
