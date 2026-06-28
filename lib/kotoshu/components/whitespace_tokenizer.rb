# frozen_string_literal: true

module Kotoshu
  module Components
    # Whitespace-based tokenizer for Latin-script languages.
    #
    # Splits text on whitespace and separates punctuation.
    # Suitable for languages with space-separated words (English, French, German, etc.).
    #
    # This is a simple tokenizer that works well for most Latin-script languages.
    # For more advanced tokenization (contractions, compounds), use language-specific
    # tokenizers.
    #
    # @example Basic tokenization
    #   tokenizer = WhitespaceTokenizer.new
    #   tokens = tokenizer.tokenize("Hello, world!")
    #   # => [
    #   #      { token: "Hello", position: 0, length: 5 },
    #   #      { token: ",", position: 5, length: 1 },
    #   #      { token: "world", position: 7, length: 5 },
    #   #      { token: "!", position: 12, length: 1 }
    #   #    ]
    #
    # @example Tokenizing to strings
    #   tokenizer.tokenize_to_strings("Hello, world!")
    #   # => ["Hello", ",", "world", "!"]
    class WhitespaceTokenizer < Tokenizer
      # Regex pattern for matching tokens (words or punctuation).
      TOKEN_PATTERN = /[\w']+|[^\w\s]/

      # Create a new whitespace tokenizer.
      #
      # @param pattern [Regexp] Optional custom token pattern
      def initialize(pattern: TOKEN_PATTERN)
        @pattern = pattern
      end

      # Split text into tokens.
      #
      # Each token is a hash with:
      # - :token (String) - The token text
      # - :position (Integer) - Character position in original text
      # - :length (Integer) - Token length in characters
      #
      # @param text [String] The input text
      # @return [Array<Hash>] Array of token hashes
      def tokenize(text)
        return [] if text.nil? || text.empty?

        tokens = []
        position = 0

        # Find all matches
        text.scan(@pattern) do |match|
          match_str = match.is_a?(Array) ? match.first : match
          start_pos = text.index(match_str, position)

          tokens << {
            token: match_str,
            position: start_pos,
            length: match_str.length
          }

          position = start_pos + match_str.length
        end

        tokens
      end

      # Get the token pattern used by this tokenizer.
      #
      # @return [Regexp] The token pattern
      def pattern
        @pattern
      end

      # Check if a character is a word character.
      #
      # @param char [String] Single character
      # @return [Boolean] True if word character
      def word_char?(char)
        char.match?(/\w/)
      end

      # Check if a character is punctuation.
      #
      # @param char [String] Single character
      # @return [Boolean] True if punctuation
      def punctuation?(char)
        char.match?(/[^\w\s]/)
      end
    end
  end
end
