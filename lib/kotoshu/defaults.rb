# frozen_string_literal: true

require_relative "configuration/builder"

module Kotoshu
  # Sensible defaults for Kotoshu configuration.
  #
  # Provides auto-detection of system dictionaries and fallback
  # to bundled dictionaries, ensuring Kotoshu works out of the box.
  module Defaults
    # Standard system dictionary paths.
    SYSTEM_DICTIONARY_PATHS = [
      "/usr/share/dict/words",
      "/usr/share/dict/web2",
      "/usr/share/dict/web2a",
      "/usr/dict/words"
    ].freeze

    # Bundled dictionary paths (relative to gem root).
    BUNDLED_DICTIONARY_PATHS = [
      "dictionaries/unix_words/words",
      "dictionaries/unix_words/web2",
      "dictionaries/unix_words/web2a"
    ].freeze

    class << self
      # Detect system dictionary.
      #
      # @return [String, nil] Path to system dictionary or nil
      def detect_system_dictionary
        SYSTEM_DICTIONARY_PATHS.find do |path|
          File.exist?(path)
        end
      end

      # Get path to bundled dictionary.
      #
      # @return [String, nil] Path to bundled dictionary or nil
      def bundled_dictionary_path
        BUNDLED_DICTIONARY_PATHS.find do |path|
          full_path = File.expand_path("../../#{path}", __dir__)
          File.exist?(full_path)
        end
      end

      # Get default dictionary.
      #
      # Tries system dictionary first, then bundled dictionary,
      # then falls back to an empty custom dictionary.
      #
      # @return [Dictionary::Base] A working dictionary
      def default_dictionary
        # Try system dictionary
        system_path = detect_system_dictionary
        return Dictionary::PlainText.new(system_path, language_code: "en") if system_path

        # Try bundled dictionary
        bundled_path = bundled_dictionary_path
        if bundled_path
          full_path = File.expand_path("../../#{bundled_path}", __dir__)
          return Dictionary::PlainText.new(full_path, language_code: "en")
        end

        # Fall back to minimal dictionary with common words
        Dictionary::PlainText.from_words(
          %w[the and for are but not you all any can had has him his how her its now our our was what],
          language_code: "en"
        )
      end

      # Configure Kotoshu with sensible defaults.
      #
      # @return [Configuration] The configured instance
      def configure
        default_dictionary

        Configuration::Builder.build do |c|
          c.dictionary_type = :plain_text
          c.language = "en-US"
          c.max_suggestions = 10
          c.case_sensitive = false
        end
      end
    end
  end
end
