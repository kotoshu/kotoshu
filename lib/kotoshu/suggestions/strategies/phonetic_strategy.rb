# frozen_string_literal: true

module Kotoshu
  module Suggestions
    module Strategies
      # Phonetic suggestion strategy.
      #
      # Generates suggestions by finding words with similar phonetic codes
      # using algorithms like Soundex and Metaphone.
      #
      # @example Creating a phonetic strategy
      #   strategy = PhoneticStrategy.new(algorithm: :soundex)
      #   result = strategy.generate(context)
      class PhoneticStrategy < BaseStrategy
        # Supported algorithms.
        ALGORITHMS = %i[soundex metaphone].freeze

        # Create a new phonetic strategy.
        #
        # @param name [String, Symbol] Name of the strategy
        # @param config [Hash] Configuration options
        # @option config [Symbol] algorithm The algorithm to use (:soundex or :metaphone)
        # @option config [Integer] max_results Maximum results to return
        def initialize(name: :phonetic, **config)
          super
        end

        # Generate suggestions based on phonetic similarity.
        #
        # @param context [Context] The suggestion context
        # @return [SuggestionSet] Suggestions with same phonetic code
        def generate(context)
          word = context.word
          algorithm = get_config(:algorithm, :soundex)
          max_dist = 2

          # Get phonetic code for input word
          word_code = phonetic_code(word, algorithm)

          # Find words with same phonetic code
          results = []
          each_phonetic_pair(context, algorithm) do |dict_word, dict_code|
            next if dict_word == word
            next unless dict_code == word_code

            dist = edit_distance(word, dict_word)
            next if dist > max_dist || dist.zero?

            results << [dict_word, dist]
          end

          # Sort by distance and convert to suggestions
          sorted_words = results.sort_by { |_, dist| dist }.map(&:first)
          create_suggestion_set(sorted_words)
        end

        # Check if this strategy should handle the context.
        #
        # @param context [Context] The suggestion context
        # @return [Boolean] True if the word needs correction
        def handles?(context)
          return false unless enabled?

          !dictionary_lookup(context, context.word)
        end

        private

        # Yield each dictionary word paired with its phonetic code, in
        # word-list order. For Soundex over a Dictionary::Base backend
        # the codes come from the dictionary's memoized sweep index
        # ({Dictionary::Base#sweep_index}) — one Soundex per word for
        # the dictionary's lifetime instead of one per sweep. Every
        # other combination (ad-hoc Hash/Array dictionaries, Metaphone)
        # computes each code live, exactly as before.
        #
        # @param context [Context] The suggestion context
        # @param algorithm [Symbol] The phonetic algorithm
        # @yield [String, String] Each word and its phonetic code
        # @return [void]
        def each_phonetic_pair(context, algorithm)
          dictionary = context.dictionary
          if algorithm == :soundex && dictionary.is_a?(Kotoshu::Dictionary::Base)
            dictionary.sweep_index.each_with_soundex { |*pair| yield(*pair) }
          else
            dictionary_words(context).each do |dict_word|
              yield dict_word, phonetic_code(dict_word, algorithm)
            end
          end
        end

        # Get phonetic code for a word.
        #
        # @param word [String] The word
        # @param algorithm [Symbol] The algorithm to use
        # @return [String] The phonetic code
        def phonetic_code(word, algorithm = :soundex)
          case algorithm
          when :soundex
            soundex_code(word)
          when :metaphone
            metaphone_code(word)
          else
            soundex_code(word)
          end
        end

        # Calculate Soundex code for a word.
        #
        # Soundex is a phonetic algorithm developed by Robert C. Russell
        # and Margaret King Odell in the early 1900s. The implementation
        # lives in {Algorithms::Soundex} and is shared with
        # {Suggestions::SweepIndex}, which memoizes the code per
        # dictionary word.
        #
        # @param word [String] The word
        # @return [String] The Soundex code (letter + 3 digits)
        #
        # @example
        #   soundex_code("Robert")  # => "R163"
        #   soundex_code("Rupert")  # => "R163"
        #   soundex_code("Ashcraft") # => "A261"
        def soundex_code(word)
          Algorithms::Soundex.code(word)
        end

        # Calculate Metaphone code for a word.
        #
        # Metaphone is an improved phonetic algorithm developed by
        # Lawrence Philips in 1990.
        #
        # @param word [String] The word
        # @return [String] The Metaphone code
        #
        # @example
        #   metaphone_code("Schmidt")  # => "XMT"
        #   metaphone_code("Smith")    # => "SM0"
        def metaphone_code(word)
          return "" if word.nil? || word.empty?

          word = word.upcase.gsub(/[^A-Z]/, "")
          return "" if word.empty?

          # Metaphone rules (simplified implementation)
          code = ""
          i = 0
          length = word.length

          while i < length && code.length < 4
            char = word[i]
            next_char = i + 1 < length ? word[i + 1] : ""

            case char
            when "A", "E", "I", "O", "U"
              # Vowels are only encoded at the beginning
              code += char if i.zero?
            when "B"
              code += "B"
            when "C"
              if next_char == "H" && i + 2 < length && %w[A E I O U].include?(word[i + 2])
                # "CH" followed by vowel => "X"
                code += "X"
                i += 1
              elsif next_char == "I" && i + 2 < length && word[i + 2] == "A"
                # "CIA" => "X"
                code += "X"
                i += 2
              elsif %w[S G].include?(next_char)
                # "CS", "CG" => "X"
                code += "X"
                i += 1
              else
                code += "K"
              end
            when "D"
              if next_char == "G" && i + 2 < length && %w[I E Y].include?(word[i + 2])
                # "DG" followed by I, E, Y => "J"
                code += "J"
                i += 1
              else
                code += "T"
              end
            when "F"
              code += "F"
            when "G"
              if next_char == "H"
                # "GH" => silent unless at beginning or after vowel
                if i.zero?
                  code += "K"
                  i += 1
                end
              elsif next_char == "N"
                # "GN" => "N" (silent G)
                i += 1
              elsif next_char == "N" && i + 2 < length && word[i + 2] == "E" && i + 3 < length && word[i + 3] == "D"
                # "GNED" => "N" (silent G)
                i += 3
              else
                code += "K"
              end
            when "H"
              # H is silent unless at beginning
              code += "H" if i.zero?
            when "J"
              code += "J"
            when "K"
              code += "K"
              i += 1 if next_char == "N" # "KN" => "N"
            when "L"
              code += "L"
            when "M"
              code += "M"
            when "N"
              code += "N"
            when "P"
              if next_char == "H"
                # "PH" => "F"
                code += "F"
                i += 1
              else
                code += "P"
              end
            when "Q"
              code += "K"
            when "R"
              code += "R"
            when "S"
              if next_char == "H"
                # "SH" => "X"
                code += "X"
                i += 1
              elsif next_char == "I" && i + 2 < length && word[i + 2] == "O"
                # "SIO" or "SIA" => "X"
                code += "X"
                i += 2
              else
                code += "S"
              end
            when "T"
              if next_char == "I" && i + 2 < length && %w[O A].include?(word[i + 2])
                # "TIO" or "TIA" => "X"
                code += "X"
                i += 2
              elsif next_char == "H"
                # "TH" => "0"
                code += "0"
                i += 1
              else
                code += "T"
              end
            when "V"
              code += "F"
            when "W", "Y"
              # W and Y are semi-vowels, only encode at beginning
              code += char if i.zero?
            when "X"
              code += "KS"
            when "Z"
              code += "S"
            end

            i += 1
          end

          code[0...4] # Max 4 characters
        end

        # Calculate Damerau-Levenshtein edit distance.
        #
        # Delegates to Algorithms::EditDistance so phonetically equal
        # candidates are measured with the same metric as the edit
        # distance strategy — an adjacent transposition ("recieve" ->
        # "receive") costs 1, not 2.
        #
        # @param str1 [String] First string
        # @param str2 [String] Second string
        # @return [Integer] Edit distance
        def edit_distance(str1, str2)
          Algorithms::EditDistance.distance(str1, str2)
        end
      end
    end
  end
end
