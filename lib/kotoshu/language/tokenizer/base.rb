# frozen_string_literal: true

module Kotoshu
  module Language
    module Tokenizer
      # Abstract base class for tokenizers.
      #
      # Uses Strategy pattern to allow different tokenization approaches
      # for different languages.
      #
      # Subclasses must implement the tokenize method.
      #
      # @example Implement a tokenizer
      #   class MyTokenizer < Tokenizer::Base
      #     def tokenize(text)
      #       text.split(/ /)
      #     end
      #   end
      class Base
        # Tokenize text into words.
        #
        # @param text [String] Text to tokenize
        # @return [Array<String>] Array of tokens
        # @raise [NotImplementedError] Must be implemented by subclass
        def tokenize(text)
          raise NotImplementedError, "#{self.class} must implement #tokenize"
        end

        # Tokenize text with positions.
        #
        # Returns tokens along with their position information.
        #
        # @param text [String] Text to tokenize
        # @return [Array<Hash>] Array of {token:, start:, end:, line:, column:}
        def tokenize_with_positions(text)
          return [] if text.nil?
          return [] if text.empty?

          tokens = []
          line = 1
          column = 1
          position = 0

          while position < text.length
            # Skip whitespace
            while position < text.length && text[position].match?(/\s/)
              if text[position] == "\n"
                line += 1
                column = 1
              else
                column += 1
              end
              position += 1
            end

            break if position >= text.length

            # Find token
            start_pos = position
            start_line = line
            start_column = column

            token_text = extract_next_token(text, position)

            if token_text
              tokens << {
                token: token_text,
                start: start_pos,
                end: start_pos + token_text.length,
                line: start_line,
                column: start_column
              }

              token_text.each_char do |char|
                column += 1
                position += 1
                if char == "\n"
                  line += 1
                  column = 1
                end
              end
            else
              position += 1
              column += 1
            end
          end

          tokens
        end

        # Check if a character is a word character.
        #
        # @param char [String] Single character
        # @return [Boolean] True if word character
        def word_char?(char)
          match?(word_boundary_regex, char)
        end

        # Get word boundary regex for this tokenizer.
        #
        # Subclasses should override this to define word boundaries.
        #
        # @return [Regexp] Word boundary regex
        def word_boundary_regex
          raise NotImplementedError, "#{self.class} must implement #word_boundary_regex"
        end

        # Normalize a token.
        #
        # Subclasses can override this for language-specific normalization.
        #
        # @param token [String] Token to normalize
        # @return [String] Normalized token
        def normalize(token)
          token
        end

        # Check if a token should be skipped.
        #
        # Subclasses can override this for language-specific filtering.
        #
        # @param token [String] Token to check
        # @return [Boolean] True if token should be skipped
        def skip_token?(token)
          return true if token.empty?
          return true if token.match?(/^\d+$/) # Pure numbers
          return true if token.length < 2 && token.match?(/^[^\p{L}]$/)

          false
        end

        protected

        # Extract the next token from text at position.
        #
        # @param text [String] Full text
        # @param position [Integer] Current position
        # @return [String, nil] Next token or nil
        def extract_next_token(text, position)
          remaining = text[position..]
          match = remaining.match(/^#{word_pattern}/)
          match ? match[0] : nil
        end

        # Get pattern for matching tokens.
        #
        # @return [String] Regex pattern string
        def word_pattern
          "[#{word_chars}]+"
        end

        # Get word characters for this tokenizer.
        #
        # @return [String] Character class of word characters
        def word_chars
          raise NotImplementedError, "#{self.class} must implement #word_chars"
        end

        # Check if string matches regex.
        #
        # @param regex [Regexp] Regex to match
        # @param string [String] String to check
        # @return [Boolean] True if matches
        def match?(regex, string)
          regex.match?(string)
        end
      end
    end
  end
end
