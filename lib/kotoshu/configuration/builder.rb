# frozen_string_literal: true

require_relative "../configuration"

module Kotoshu
  class Configuration
    # Builder for creating immutable Configuration objects.
    #
    # Provides a fluent interface for building configuration objects
    # that are frozen after creation, ensuring thread-safety and immutability.
    #
    # @example Building with block
    #   config = Configuration::Builder.build do |b|
    #     b.dictionary_path = "words.txt"
    #     b.language = "en-GB"
    #   end
    #
    # @example Building with fluent methods
    #   config = Configuration::Builder.build
    #     .with_dictionary_path("words.txt")
    #     .with_language("en-GB")
    class Builder
      # Build an immutable configuration.
      #
      # @yield [builder] Optional block for configuration
      # @return [Configuration] Frozen configuration object
      #
      # @example With block
      #   config = Builder.build do |b|
      #     b.dictionary_path = "words.txt"
      #   end
      #
      # @example Without block (uses defaults)
      #   config = Builder.build
      def self.build
        builder_instance = new
        yield(builder_instance) if block_given?
        builder_instance.to_config
      end

      # Create a new builder.
      def initialize
        @settings = DEFAULTS.dup
      end

      # Set dictionary path.
      #
      # @param path [String] Path to dictionary file
      # @return [self] Self for chaining
      def dictionary_path=(path)
        @settings[:dictionary_path] = path
        self
      end

      # Set dictionary type.
      #
      # @param type [Symbol] Dictionary type
      # @return [self] Self for chaining
      def dictionary_type=(type)
        @settings[:dictionary_type] = type
        self
      end

      # Set language code.
      #
      # @param lang [String] Language code
      # @return [self] Self for chaining
      def language=(lang)
        @settings[:language] = lang
        self
      end

      # Set locale.
      #
      # @param locale [String, nil] Locale
      # @return [self] Self for chaining
      def locale=(locale)
        @settings[:locale] = locale
        self
      end

      # Set max suggestions.
      #
      # @param max [Integer] Maximum suggestions
      # @return [self] Self for chaining
      def max_suggestions=(max)
        @settings[:max_suggestions] = max
        self
      end

      # Set case sensitivity.
      #
      # @param sensitive [Boolean] Case sensitive flag
      # @return [self] Self for chaining
      def case_sensitive=(sensitive)
        @settings[:case_sensitive] = sensitive
        self
      end

      # Set verbose mode.
      #
      # @param verbose [Boolean] Verbose flag
      # @return [self] Self for chaining
      def verbose=(verbose)
        @settings[:verbose] = verbose
        self
      end

      # Set suggestion algorithms.
      #
      # @param algorithms [Array<Class>, nil] Suggestion algorithms
      # @return [self] Self for chaining
      def suggestion_algorithms=(algorithms)
        @settings[:suggestion_algorithms] = algorithms
        self
      end

      # Set custom words.
      #
      # @param words [Array<String>] Custom words
      # @return [self] Self for chaining
      def custom_words=(words)
        @settings[:custom_words] = words.dup.freeze
        self
      end

      # Set encoding.
      #
      # @param encoding [String] Character encoding
      # @return [self] Self for chaining
      def encoding=(encoding)
        @settings[:encoding] = encoding
        self
      end

      # Fluent method to set dictionary path.
      #
      # @param path [String] Path to dictionary file
      # @return [Configuration] New configuration
      def with_dictionary_path(path)
        @settings[:dictionary_path] = path
        self
      end

      # Fluent method to set dictionary type.
      #
      # @param type [Symbol] Dictionary type
      # @return [Configuration] New configuration
      def with_dictionary_type(type)
        @settings[:dictionary_type] = type
        self
      end

      # Fluent method to set language.
      #
      # @param lang [String] Language code
      # @return [Configuration] New configuration
      def with_language(lang)
        @settings[:language] = lang
        self
      end

      # Fluent method to set locale.
      #
      # @param locale [String, nil] Locale
      # @return [Configuration] New configuration
      def with_locale(locale)
        @settings[:locale] = locale
        self
      end

      # Fluent method to set max suggestions.
      #
      # @param max [Integer] Maximum suggestions
      # @return [Configuration] New configuration
      def with_max_suggestions(max)
        @settings[:max_suggestions] = max
        self
      end

      # Fluent method to set case sensitivity.
      #
      # @param sensitive [Boolean] Case sensitive flag
      # @return [Configuration] New configuration
      def with_case_sensitive(sensitive)
        @settings[:case_sensitive] = sensitive
        self
      end

      # Fluent method to set verbose mode.
      #
      # @param verbose [Boolean] Verbose flag
      # @return [Configuration] New configuration
      def with_verbose(verbose)
        @settings[:verbose] = verbose
        self
      end

      # Convert builder to frozen Configuration.
      #
      # @return [Configuration] Frozen configuration object
      def to_config
        config = Configuration.new(@settings.dup)
        config.freeze
        config
      end
    end
  end
end
