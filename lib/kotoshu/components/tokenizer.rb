# frozen_string_literal: true

module Kotoshu
  module Components
    # Base class for tokenizers.
    #
    # Tokenizers split text into individual tokens (words, punctuation).
    # Different languages use different tokenization strategies:
    # - Latin scripts: Whitespace + punctuation
    # - CJK: Morphological analysis
    # - German: Compound word splitting
    # - RTL: Right-to-left text handling
    #
    # @abstract Subclasses must implement #tokenize
    #
    # @example Tokenizing English text
    #   tokenizer = WhitespaceTokenizer.new
    #   tokens = tokenizer.tokenize("Hello, world!")
    #   # => [
    #   #      { token: "Hello", position: 0, length: 5 },
    #   #      { token: ",", position: 5, length: 1 },
    #   #      { token: "world", position: 7, length: 5 },
    #   #      { token: "!", position: 12, length: 1 }
    #   #    ]
    class Tokenizer
      # Split text into tokens.
      #
      # Each token is a hash with:
      # - :token (String) - The token text
      # - :position (Integer) - Character position in original text
      # - :length (Integer) - Token length in characters
      #
      # Additional keys may be added by subclasses:
      # - :pos_tag (String) - Part of speech tag
      # - :lemma (String) - Base form / lemma
      # - :compound_part (Boolean) - Whether this is a compound word part
      # - :script (Symbol) - Script type for multilingual text
      #
      # @abstract Subclasses must implement
      # @param text [String] The input text
      # @return [Array<Hash>] Array of token hashes
      # @raise [NotImplementedError] if not implemented by subclass
      def tokenize(text)
        raise NotImplementedError, "#{self.class} must implement #tokenize"
      end

      # Tokenize and return just the token strings.
      #
      # Convenience method for when you only need the text content.
      #
      # @param text [String] The input text
      # @return [Array<String>] Array of token strings
      def tokenize_to_strings(text)
        tokenize(text).map { |t| t[:token] }
      end
    end
  end
end
