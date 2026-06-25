# frozen_string_literal: true

module Kotoshu
  module Algorithms
    # Capitalization handling for different languages.
    #
    # Ported from Spylls (Python) capitalization.py
    #
    # This module provides capitalization detection and conversion for different
    # language casing rules, including special handling for Turkic and German languages.
    module Capitalization
      # Type of capitalization detected by Casing.guess.
      #
      # NO:: all lowercase ("foo")
      # INIT:: titlecase, only initial letter is capitalized ("Foo")
      # ALL:: all uppercase ("FOO")
      # HUH:: mixed capitalization ("fooBar")
      # HUHINIT:: mixed capitalization, first letter is capitalized ("FooBar")
      module Type
        NO = :no
        INIT = :init
        ALL = :all
        HUH = :huh
        HUHINIT = :huhinit
      end

      # Base class for casing-related algorithms specific for dictionary's language.
      #
      # This is a class (not a set of functions) because it needs to have
      # subclasses for specific language casing, which have only some aspects
      # different from generic one.
      class Casing
        # Guess word's capitalization. Redefined in GermanCasing.
        #
        # @param word [String] The word to analyze
        # @return [Symbol] One of the Type constants
        def guess(word)
          return Type::NO if word.downcase == word
          return Type::ALL if word.upcase == word
          return Type::INIT if word[0].upcase == word[0] && word[1..].downcase == word[1..]

          if word[0].upcase == word[0]
            Type::HUHINIT
          else
            Type::HUH
          end
        end

        # Lowercases the word. Returns list of possible lowercasings for all
        # casing classes to behave consistently.
        #
        # In GermanCasing (and only there), lowercasing word like "STRASSE"
        # produces two possibilities: "strasse" and "ße" (ß is most of the time
        # upcased to SS, so we can't decide which of downcased words is "right"
        # and need to check both).
        #
        # Also redefined in TurkicCasing, because in Turkic languages lowercase
        # "i" is uppercased as "İ", and uppercase "I" is downcased as "ı".
        #
        # @param word [String] The word to lowercase
        # @return [Array<String>] List of possible lowercasings
        def lower(word)
          # Can't be properly lowercased in non-Turkic collation
          return [] if word.nil? || word.empty? || word[0] == 'İ'

          # Turkic "lowercase dot i" to latinic "i", just in case
          [word.downcase.gsub('i̇', 'i')]
        end

        # Uppercase the word. Redefined in TurkicCasing, because in Turkic
        # languages lowercase "i" is uppercased as "İ", and uppercase "I"
        # is downcased as "ı".
        #
        # @param word [String] The word to uppercase
        # @return [String] Uppercased word
        def upper(word)
          word.upcase
        end

        # Capitalize (convert word to all lowercase and first letter uppercase).
        # Returns a list of results for same reasons as lower.
        #
        # @param word [String] The word to capitalize
        # @return [Enumerator<String>] Enum of capitalized variants
        def capitalize(word)
          return enum_for(:capitalize, word) unless block_given?

          if word.length == 1
            yield upper(word[0])
          else
            upper_first = upper(word[0])
            lower(word[1..]).each do |lowered|
              yield upper_first + lowered
            end
          end
        end

        # Just change the case of the first letter to lower.
        # Returns a list of results for same reasons as lower.
        #
        # @param word [String] The word to process
        # @return [Enumerator<String>] Enum of variants with lowercased first letter
        def lowerfirst(word)
          return enum_for(:lowerfirst, word) unless block_given?

          lower(word[0]).each do |lowered|
            yield lowered + word[1..]
          end
        end

        # Returns hypotheses of how the word might have been cased (in dictionary),
        # if we consider it is spelled correctly.
        #
        # Example: If word is "Kitten", hypotheses are "kitten", "Kitten".
        #
        # @param word [String] The word to analyze
        # @return [Array<Symbol, Array<String>>] Pair of [captype, variants]
        def variants(word)
          captype = guess(word)

          result = case captype
                   when Type::NO
                     [word]
                   when Type::INIT
                     [word, *lower(word)]
                   when Type::HUHINIT
                     [word, *lowerfirst(word).to_a]
                   when Type::HUH
                     [word]
                   when Type::ALL
                     [word, *lower(word), *capitalize(word).to_a]
                   end

          [captype, result]
        end

        # Returns hypotheses of how the word might have been cased if it is a
        # misspelling.
        #
        # Example: "DiCtionary" (HUHINIT capitalization) produces hypotheses
        # "DiCtionary", "diCtionary", "dictionary", "Dictionary", and all of
        # them are checked by Suggest.
        #
        # @param word [String] The word to analyze
        # @return [Array<Symbol, Array<String>>] Pair of [captype, variants]
        def corrections(word)
          captype = guess(word)

          result = case captype
                   when Type::NO
                     [word]
                   when Type::INIT
                     [word, *lower(word)]
                   when Type::HUHINIT
                     [word, *lowerfirst(word).to_a, *lower(word), *capitalize(word).to_a]
                   when Type::HUH
                     [word, *lower(word)]
                   when Type::ALL
                     [word, *lower(word), *capitalize(word).to_a]
                   end

          [captype, result]
        end

        # Used by suggest: by known (valid) suggestion, and initial word's
        # capitalization, produce proper suggestion capitalization.
        #
        # Example: If misspelling was "Kiten" (INIT capitalization),
        # found suggestion "kitten", then this method makes it "Kitten".
        #
        # @param word [String] The valid suggestion word
        # @param cap [Symbol] Original word's capitalization type
        # @return [String] Properly capitalized suggestion
        def coerce(word, cap)
          case cap
          when Type::INIT, Type::HUHINIT
            upper(word[0]) + word[1..]
          when Type::ALL
            upper(word)
          else
            word
          end
        end
      end

      # Redefines upper and lower, because in Turkic languages lowercase "i"
      # is uppercased as "İ", and uppercase "I" is downcased as "ı".
      #
      # Example:
      #   turkic = Kotoshu::Algorithms::Capitalization::TurkicCasing.new
      #   turkic.lower('Izmir')  # => ['ızmir']
      #   turkic.upper('Izmir')  # => 'IZMİR'
      class TurkicCasing < Casing
        U2L = {
          'İ' => 'i',
          'I' => 'ı'
        }.freeze

        L2U = {
          'i' => 'İ',
          'ı' => 'I'
        }.freeze

        # Translate uppercase Turkic characters to lowercase.
        #
        # @param word [String] The word to lowercase
        # @return [Array<String>] List of lowercased variants
        def lower(word)
          translated = word.chars.map { |c| U2L[c] || c }.join
          super(translated)
        end

        # Translate lowercase Turkic characters to uppercase.
        #
        # @param word [String] The word to uppercase
        # @return [String] Uppercased word
        def upper(word)
          translated = word.chars.map { |c| L2U[c] || c }.join
          super(translated)
        end
      end

      # Redefines lower because in German "SS" can be lowercased both as "ss" and "ß".
      #
      # Example:
      #   german = Kotoshu::Algorithms::Capitalization::GermanCasing.new
      #   german.lower('STRASSE')  # => ['straße', 'strasse']
      class GermanCasing < Casing
        # Generate sharp S (ß) variants for all "ss" occurrences.
        #
        # @param text [String] The text to process
        # @param start [Integer] Starting position for search
        # @return [Array<String>] All variants with ß replacements
        def sharp_s_variants(text, start = 0)
          pos = text.index('ss', start)
          return [] unless pos

          replaced = text[0...pos] + 'ß' + text[(pos + 2)..]
          [replaced,
           *sharp_s_variants(replaced, pos + 1),
           *sharp_s_variants(text, pos + 2)]
        end

        # Lowercase word, generating both "ss" and "ß" variants where applicable.
        #
        # @param word [String] The word to lowercase
        # @return [Array<String>] List of lowercased variants
        def lower(word)
          lowered = super.first
          return [lowered] unless word.include?('SS')

          [*sharp_s_variants(lowered), lowered]
        end

        # Guess word's capitalization, accounting for German ß handling.
        #
        # In German uppercased words, ß (which is lowercase, and usually uppercased
        # as SS) is allowed: "straße" => "STRAßE"
        #
        # @param word [String] The word to analyze
        # @return [Symbol] One of the Type constants
        def guess(word)
          result = super

          # Check if removing ß makes it ALL caps
          if word.include?('ß')
            word_without_ss = word.gsub('ß', '')
            return Type::ALL if super(word_without_ss) == Type::ALL
          end

          result
        end
      end
    end
  end
end
