# frozen_string_literal: true

module Kotoshu
  module Language
    # Abstract base class for language implementations.
    #
    # Uses Template Method pattern to define the interface that all
    # language implementations must follow.
    #
    # Each language implementation should:
    # 1. Inherit from this class
    # 2. Implement the required template methods
    # 3. Register itself with Language::Registry
    #
    # @example Implement a language
    #   class English < Kotoshu::Language::Base
    #     register "en"
    #
    #     def initialize
    #       super(code: "en", name: "English")
    #     end
    #
    #     def tokenizer
    #       @tokenizer ||= Tokenizer::LatinTokenizer.new
    #     end
    #
    #     def normalizer
    #       @normalizer ||= Normalizer::Base.new
    #     end
    #
    #     def dictionary_class
    #       Dictionary::UnixWords
    #     end
    #   end
    class Base
      attr_reader :code, :name, :variant, :region

      # Initialize language.
      #
      # @param code [String] Language code (e.g., "en", "en-US", "de-DE")
      # @param name [String] Human-readable name
      # @param variant [String, nil] Variant name (e.g., "American", "British")
      def initialize(code:, name:, variant: nil)
        @code = code
        @name = name
        @variant = variant
        @region = extract_region(code)
      end

      # Get tokenizer for this language.
      #
      # Subclasses must implement.
      #
      # @return [Tokenizer::Base] Language-specific tokenizer
      # @raise [NotImplementedError] If not implemented
      def tokenizer
        raise NotImplementedError, "#{self.class} must implement #tokenizer"
      end

      # Get normalizer for this language.
      #
      # Subclasses must implement.
      #
      # @return [Normalizer::Base] Language-specific normalizer
      # @raise [NotImplementedError] If not implemented
      def normalizer
        raise NotImplementedError, "#{self.class} must implement #normalizer"
      end

      # Get dictionary class for this language.
      #
      # Subclasses must implement.
      #
      # @return [Class] Dictionary backend class
      # @raise [NotImplementedError] If not implemented
      def dictionary_class
        raise NotImplementedError, "#{self.class} must implement #dictionary_class"
      end

      # Get default dictionary paths for this language.
      #
      # Subclasses can override to provide language-specific paths.
      #
      # @return [Array<String>] List of dictionary paths to search
      def default_dictionary_paths
        []
      end

      # Get character encoding for this language.
      #
      # Default is UTF-8 for all languages.
      #
      # @return [String] Character encoding name
      def encoding
        "UTF-8"
      end

      # Check if language uses right-to-left script.
      #
      # Default is false. Override for Arabic, Hebrew, etc.
      #
      # @return [Boolean] True if RTL
      def rtl?
        false
      end

      # Get script type for this language.
      #
      # Possible values: :latin, :cyrillic, :arabic, :cjk, :mixed
      #
      # @return [Symbol] Script type
      def script_type
        :latin
      end

      # Tokenize text using language-specific tokenizer.
      #
      # @param text [String] Text to tokenize
      # @return [Array<String>] Array of tokens
      def tokenize(text)
        tokenizer.tokenize(text)
      end

      # Normalize text using language-specific normalizer.
      #
      # @param text [String] Text to normalize
      # @param options [Hash] Normalization options
      # @return [String] Normalized text
      def normalize(text, options = {})
        normalizer.normalize(text, options)
      end

      # Check if a word is valid in this language.
      #
      # Uses dictionary lookup.
      #
      # @param word [String] Word to check
      # @param dictionary [Dictionary::Base] Dictionary to use
      # @return [Boolean] True if word is valid
      def valid_word?(word, dictionary:)
        normalized = normalize_word(word)
        dictionary.lookup(normalized)
      end

      # Normalize a word for checking.
      #
      # @param word [String] Word to normalize
      # @return [String] Normalized word
      def normalize_word(word)
        normalizer.normalize_word(word)
      end

      # Get language info hash.
      #
      # @return [Hash] Language information
      def info
        {
          code: code,
          name: name,
          variant: variant,
          region: region,
          encoding: encoding,
          rtl?: rtl?,
          script_type: script_type,
          dictionary_class: dictionary_class.name
        }
      end

      # Check if this language matches given code.
      #
      # Supports base language matching (e.g., "en" matches "en-US").
      #
      # @param other_code [String] Code to compare
      # @return [Boolean] True if matches
      def matches_code?(other_code)
        return false if other_code.nil?

        code == other_code ||
          code.split("-").first == other_code.split("-").first
      end

      # Get full language name with variant.
      #
      # @return [String] Full name
      def full_name
        return name unless variant

        "#{name} (#{variant})"
      end

      # Check if this is a base language (no region).
      #
      # @return [Boolean] True if base language
      def base_language?
        !code.include?("-")
      end

      # Get base language code.
      #
      # @return [String] Base language code (e.g., "en" from "en-US")
      def base_code
        code.split("-").first
      end

      # Get region code.
      #
      # @return [String, nil] Region code or nil
      def region_code
        return nil unless code.include?("-")

        code.split("-", 2).last
      end

      # Check if another language is compatible.
      #
      # Languages are compatible if they share the same base code.
      #
      # @param other [Base] Other language
      # @return [Boolean] True if compatible
      def compatible_with?(other)
        return false unless other.is_a?(Base)

        base_code == other.base_code
      end

      class << self
        # Register this language with the registry.
        #
        # Records +code+ in {registered_codes} so the registry can be
        # rebuilt after a {Kotoshu::Language::Registry.clear} without
        # re-loading the per-language file (which Ruby autoload only
        # runs once). See {Language::Registry.restore_autoload!}.
        #
        # @param code [String] Language code
        # @return [void]
        def register(code)
          registered_codes << code
          Kotoshu::Language::Registry.register(code, self)
        end

        # Per-language class method reader for the codes registered via
        # {register}. Used by {Language::Registry.restore_autoload!} to
        # rebuild the registry after a clear.
        #
        # @return [Array<String>]
        def registered_codes
          @registered_codes ||= []
        end

        # Get or create singleton instance.
        #
        # @return [Base] Language instance
        def instance
          @instance ||= new
        end
      end

      private

      # Extract region from language code.
      #
      # @param code [String] Language code
      # @return [String, nil] Region or nil
      def extract_region(code)
        return nil unless code.include?("-")

        code.split("-", 2).last.upcase
      end
    end
  end
end
