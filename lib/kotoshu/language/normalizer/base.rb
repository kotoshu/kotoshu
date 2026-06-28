# frozen_string_literal: true

module Kotoshu
  module Language
    module Normalizer
      # Abstract base class for text normalizers.
      #
      # Normalizers transform text to a standard form for comparison.
      # Different languages use different normalization strategies.
      #
      # Examples of normalization:
      # - Accent removal (café -> cafe)
      # - Case folding (Hello -> hello)
      # - Whitespace normalization
      # - Punctuation normalization
      #
      # @example Implement a normalizer
      #   class MyNormalizer < Normalizer::Base
      #     def normalize(text)
      #       super.downcase.gsub(/[áàâä]/, 'a')
      #     end
      #   end
      class Base
        # Normalize text.
        #
        # Default implementation:
        # - Strip leading/trailing whitespace
        # - Collapse multiple whitespace to single space
        # - Downcase (optional)
        #
        # @param text [String] Text to normalize
        # @param options [Hash] Normalization options
        # @option options [Boolean] :downcase (true) Convert to lowercase
        # @option options [Boolean] :strip_punct (false) Remove punctuation
        # @option options [Boolean] :collapse_ws (true) Collapse whitespace
        # @return [String] Normalized text
        def normalize(text, options = {})
          return "" if text.nil?

          defaults = {
            downcase: true,
            strip_punct: false,
            collapse_ws: true
          }
          opts = defaults.merge(options)

          result = text.dup

          # Strip whitespace
          result = result.strip

          # Collapse multiple whitespace
          result = result.gsub(/\s+/, " ") if opts[:collapse_ws]

          # Downcase
          result = result.downcase if opts[:downcase]

          # Strip punctuation
          result = strip_punctuation(result) if opts[:strip_punct]

          result
        end

        # Normalize a word.
        #
        # @param word [String] Word to normalize
        # @return [String] Normalized word
        def normalize_word(word)
          normalize(word)
        end

        # Check if two normalized strings are equal.
        #
        # @param str1 [String] First string
        # @param str2 [String] Second string
        # @return [Boolean] True if equal after normalization
        def normalized_eql?(str1, str2)
          normalize(str1) == normalize(str2)
        end

        protected

        # Strip punctuation from text.
        #
        # @param text [String] Text to strip
        # @return [String] Text without punctuation
        def strip_punctuation(text)
          text.gsub(/[^\p{L}\p{N}\s]/, "")
        end

        # Remove accents from characters.
        #
        # @param text [String] Text with accents
        # @return [String] Text without accents
        def remove_accents(text)
          # Unicode normalization form D (decompose)
          normalized = text.unicode_normalize(:nfd)

          # Remove combining diacritical marks
          normalized.gsub(/[\u0300-\u036F]/, "")
        end

        # Normalize quotes to standard ASCII.
        #
        # @param text [String] Text with quotes
        # @return [String] Text with normalized quotes
        def normalize_quotes(text)
          # Left double quote to straight
          text = text.gsub(/[\u201C\u201D]/, '"')
          # Right double quote to straight
          text = text.gsub(/[\u2018\u2019]/, "'")
          # Backticks to quotes
          text = text.gsub('`', "'")
          # Other quote variants
          text = text.gsub("\u00AB", '"')  # Left-pointing double angle
          text = text.gsub("\u00BB", '"')  # Right-pointing double angle
          text = text.gsub("\u2039", "'")  # Single left-pointing
          text.gsub("\u203A", "'") # Single right-pointing
        end

        # Normalize whitespace.
        #
        # @param text [String] Text with irregular whitespace
        # @return [String] Text with normalized whitespace
        def normalize_whitespace(text)
          text
            .gsub(/[\u00A0\u202F\u205F]/, " ") # Various space chars
            .gsub(/[\u2000-\u200B]/, " ") # Various space chars
            .gsub(/\s+/, " ") # Collapse multiple spaces
            .strip
        end
      end
    end
  end
end
