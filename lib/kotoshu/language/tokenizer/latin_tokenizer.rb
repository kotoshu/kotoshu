# frozen_string_literal: true

module Kotoshu
  module Language
    module Tokenizer
      # Tokenizer for Latin-script languages.
      #
      # Base tokenizer for English, French, German, Spanish, Portuguese,
      # and other European languages using Latin script.
      #
      # Handles:
      # - Standard word boundaries (whitespace, punctuation)
      # - Apostrophes within words (contractions, elisions)
      # - Hyphenated words
      # - Numbers with units
      #
      # Subclasses can override for language-specific handling.
      class LatinTokenizer < Base
        # Latin word characters including accented characters
        WORD_CHARS = "a-zA-Zà-ÿ0-9'"

        # Punctuation that separates words
        WORD_SEPARATORS = /[\s"()\[\]{}<>,.;:!?\\\/|`~@#$%^&*+\-=_]/

        # Contractions that should stay together
        CONTRACTIONS = %w[
          I'm I'd I've I'll you're you'd you've you'll he's he'd he'll
          she's she'd she'll it's it'd we're we'd we've we'll they're
          they'd they've they'll that's that'd that'll who's who'd who'll
          what's what'd what'll where's where'd when's when'd why's why'd
          how's how'd can't won't don't shouldn't couldn't wouldn't didn't
          isn't aren't wasn't weren't hasn't haven't hadn't doesn't do
          doesn't didn't mightn't mustn't shan't shouldn't wouldn't
        ].freeze

        # Tokenize text into words.
        #
        # @param text [String] Text to tokenize
        # @return [Array<String>] Array of tokens
        def tokenize(text)
          return [] if text.nil? || text.strip.empty?

          # Split on word boundaries
          raw_tokens = text.split(WORD_SEPARATORS)

          # Filter and normalize
          raw_tokens
            .map { |token| normalize(token) }
            .reject { |token| skip_token?(token) }
        end

        # Get word boundary regex.
        #
        # @return [Regexp] Word boundary regex
        def word_boundary_regex
          /[#{WORD_CHARS}]/
        end

        # Normalize token.
        #
        # Subclasses can override for language-specific normalization.
        #
        # @param token [String] Token to normalize
        # @return [String] Normalized token
        def normalize(token)
          token.strip
        end

        # Check if token should be skipped.
        #
        # @param token [String] Token to check
        # @return [Boolean] True if should skip
        def skip_token?(token)
          return true if super

          # Skip pure numbers
          return true if token.match?(/^\d+$/)

          # Skip single characters (unless a word)
          return true if token.length == 1 && token.match?(/[^a-zA-Zà-ÿ]/)

          # Skip empty tokens
          return true if token.empty?

          # Skip tokens with no letters
          return true unless token.match?(/[a-zA-Zà-ÿ]/)

          false
        end

        protected

        # Get word characters.
        #
        # @return [String] Character class
        def word_chars
          WORD_CHARS
        end

        # Handle contractions to keep them together.
        #
        # @param text [String] Input text
        # @return [String] Text with protected contractions
        def handle_contractions(text)
          result = text.dup

          # Protect common contractions
          CONTRACTIONS.each do |contraction|
            # Use word boundaries to avoid partial matches
            result = result.gsub(/\b#{Regexp.escape(contraction)}\b/, contraction.gsub("'", "\uFEFF"))
          end

          result
        end

        # Extract next token with position.
        #
        # Override to handle apostrophes within words.
        #
        # @param text [String] Full text
        # @param position [Integer] Current position
        # @return [String, nil] Next token or nil
        def extract_next_token(text, position)
          remaining = text[position..]

          # Check for contraction first
          CONTRACTIONS.each do |contraction|
            if remaining.start_with?(contraction) &&
               remaining[contraction.length]&.match?(/\s|[^a-zA-Zà-ÿ]/)
              return contraction
            end
          end

          # Extract word with potential apostrophe
          match = remaining.match(/^([#{WORD_CHARS}]+(?:'[#{WORD_CHARS}]+)?)/)
          match ? match[1] : nil
        end
      end
    end
  end
end
