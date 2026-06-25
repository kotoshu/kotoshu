# frozen_string_literal: true

# Support module for language-specific test fixtures
#
# This module provides mock data for testing language-specific behavior
# in suggestion strategies. As the implementation evolves to support
# multiple languages, these fixtures will be replaced with actual
# language configuration loaders.
module SpecHelpers
  module LanguageFixtures
    # QWERTY keyboard layout (US/English)
    # Used for: English (en), most international layouts
    QWERTY_LAYOUT = {
      '`' => [0, 0], '1' => [0, 1], '2' => [0, 2], '3' => [0, 3], '4' => [0, 4],
      '5' => [0, 5], '6' => [0, 6], '7' => [0, 7], '8' => [0, 8], '9' => [0, 9],
      '0' => [0, 10], '-' => [0, 11], '=' => [0, 12],
      'q' => [1, 0], 'w' => [1, 1], 'e' => [1, 2], 'r' => [1, 3], 't' => [1, 4],
      'y' => [1, 5], 'u' => [1, 6], 'i' => [1, 7], 'o' => [1, 8], 'p' => [1, 9],
      '[' => [1, 10], ']' => [1, 11], '\\' => [1, 12],
      'a' => [2, 0], 's' => [2, 1], 'd' => [2, 2], 'f' => [2, 3], 'g' => [2, 4],
      'h' => [2, 5], 'j' => [2, 6], 'k' => [2, 7], 'l' => [2, 8], ';' => [2, 9],
      '\'' => [2, 10],
      'z' => [3, 0], 'x' => [3, 1], 'c' => [3, 2], 'v' => [3, 3], 'b' => [3, 4],
      'n' => [3, 5], 'm' => [3, 6], ',' => [3, 7], '.' => [3, 8], '/' => [3, 9]
    }.freeze

    # QWERTZ keyboard layout (German/Central European)
    # Used for: German (de), Austrian (at), Swiss (ch)
    # Key differences from QWERTY:
    # - z and y are swapped
    # - umlaut keys (ä, ö, ü) added
    # - special characters in different positions
    QWERTZ_LAYOUT = {
      '^' => [0, 0], '1' => [0, 1], '2' => [0, 2], '3' => [0, 3], '4' => [0, 4],
      '5' => [0, 5], '6' => [0, 6], '7' => [0, 7], '8' => [0, 8], '9' => [0, 9],
      '0' => [0, 10], 'ß' => [0, 11], '´' => [0, 12],
      'q' => [1, 0], 'w' => [1, 1], 'e' => [1, 2], 'r' => [1, 3], 't' => [1, 4],
      'z' => [1, 5], 'u' => [1, 6], 'i' => [1, 7], 'o' => [1, 8], 'p' => [1, 9],
      'ü' => [1, 10], '+' => [1, 11],
      'a' => [2, 0], 's' => [2, 1], 'd' => [2, 2], 'f' => [2, 3], 'g' => [2, 4],
      'h' => [2, 5], 'j' => [2, 6], 'k' => [2, 7], 'l' => [2, 8], 'ö' => [2, 9],
      'ä' => [2, 10],
      'y' => [3, 0], 'x' => [3, 1], 'c' => [3, 2], 'v' => [3, 3], 'b' => [3, 4],
      'n' => [3, 5], 'm' => [3, 6], ',' => [3, 7], '.' => [3, 8], '-' => [3, 9]
    }.freeze

    # AZERTY keyboard layout (French)
    # Used for: French (fr), Belgian (be)
    # Key differences from QWERTY:
    # - a and q are swapped
    # - z and w are swapped
    # - number row requires shift for digits
    # - accent keys (é, è, à) added
    AZERTY_LAYOUT = {
      '`' => [0, 0], '1' => [0, 1], '2' => [0, 2], '3' => [0, 3], '4' => [0, 4],
      '5' => [0, 5], '6' => [0, 6], '7' => [0, 7], '8' => [0, 8], '9' => [0, 9],
      '0' => [0, 10], ')' => [0, 11], '=' => [0, 12],
      'a' => [1, 0], 'z' => [1, 1], 'e' => [1, 2], 'r' => [1, 3], 't' => [1, 4],
      'y' => [1, 5], 'u' => [1, 6], 'i' => [1, 7], 'o' => [1, 8], 'p' => [1, 9],
      '^' => [1, 10], '$' => [1, 11],
      'q' => [2, 0], 's' => [2, 1], 'd' => [2, 2], 'f' => [2, 3], 'g' => [2, 4],
      'h' => [2, 5], 'j' => [2, 6], 'k' => [2, 7], 'l' => [2, 8], 'm' => [2, 9],
      'ù' => [2, 10],
      'w' => [3, 0], 'x' => [3, 1], 'c' => [3, 2], 'v' => [3, 3], 'b' => [3, 4],
      'n' => [3, 5], ',' => [3, 6], ';' => [3, 7], ':' => [3, 8], '!' => [3, 9]
    }.freeze

    # Common words by language (top words for frequency ranking)
    #
    # NOTE: These are simplified lists for testing purposes.
    # The actual implementation would load these from language-specific data files.
    COMMON_WORDS_BY_LANGUAGE = {
      en: %w[
        the be to of and a in that have I it for not on with he as you do at
        this but his by from they we say her she or an will my one all would
        there their what so up out if about who get which go me when make can
        like time no just him know take people into year your good some could
        them see other than then now look only come its over think also back
        after use two how our work first well way even new want because any
        these give day most us is are was are were been has had have were
        said did does can't won't should would could might must shall
        hello world help test code here text from word with very more
      ].freeze,

      de: %w[
        der die das und ist ich nicht es du Sie wir auch ein eine in mit
        auf für von zu das Den sein haben werden er es dass mit man sich
        Zeit wie an es ich bei war ich vor meiner mir nach seinem ihm ihm
        dem sein seine ihm er dieses seiner dass ich bin es
        hallo welt Hilfe Code hier Text aus Wort mit sehr mehr
      ].freeze,

      fr: %w[
        le de et un à il ne avoir je que son se qui dire pas dans une
        sur avec pour par il elle faire du en ce vous il le le et un à
        il ne pas le je son son que de son il il lui ce d'un d'un il
        bonjour monde aide code ici texte du mot avec très plus
      ].freeze
    }.freeze

    # Get keyboard layout for language code
    #
    # @param language_code [String, Symbol] Language code (e.g., 'en', 'de', 'fr')
    # @return [Hash, nil] Keyboard layout hash or nil if not found
    def self.keyboard_layout_for(language_code)
      case language_code.to_sym
      when :en, :us
        QWERTY_LAYOUT
      when :de, :at, :ch
        QWERTZ_LAYOUT
      when :fr, :be
        AZERTY_LAYOUT
      else
        QWERTY_LAYOUT # Default to QWERTY for unknown languages
      end
    end

    # Get common words for language code
    #
    # @param language_code [String, Symbol] Language code (e.g., 'en', 'de', 'fr')
    # @return [Set<String>, nil] Set of common words or nil if not found
    def self.common_words_for(language_code)
      COMMON_WORDS_BY_LANGUAGE[language_code.to_sym]
    end
  end
end
