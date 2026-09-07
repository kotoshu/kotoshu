# frozen_string_literal: true

require "thor"

module Kotoshu
  module Cli
    # Dictionary command class.
    #
    # @example
    #   kotoshu dict list
    #   kotoshu dict info en-US
    class DictCommand < Thor
      desc "list", "List available dictionaries"
      # Print the available dictionary types (one line each).
      #
      # @return [void]
      def list
        puts "Available dictionary types:"
        puts "  - unix_words: Unix system dictionary"
        puts "  - plain_text: Plain text word list"
        puts "  - custom: Custom in-memory dictionary"
        puts "  - hunspell: Hunspell (.dic/.aff)"
        puts "  - cspell: CSpell (.txt/.trie)"
      end

      desc "info TYPE", "Show information about a dictionary type"
      # Print a short description of one dictionary type, or a hint to
      # run `kotoshu dict list` for an unknown type.
      #
      # @param type [String, Symbol] One of unix_words, plain_text,
      #   custom, hunspell, cspell
      # @return [void]
      def info(type)
        case type.to_sym
        when :unix_words
          puts "UnixWords Dictionary:"
          puts "  Reads from Unix system dictionary files"
          puts "  Default paths:"
          puts "    - /usr/share/dict/words"
          puts "    - /usr/share/dict/web2"
          puts "    - /usr/share/dict/american-english"
        when :plain_text
          puts "PlainText Dictionary:"
          puts "  Reads from plain text word lists"
          puts "  One word per line, # comments supported"
        when :custom
          puts "Custom Dictionary:"
          puts "  In-memory dictionary for user-defined words"
        when :hunspell
          puts "Hunspell Dictionary:"
          puts "  Reads Hunspell .dic and .aff files"
          puts "  Supports morphological affix rules"
        when :cspell
          puts "CSpell Dictionary:"
          puts "  Reads CSpell .txt or .trie files"
          puts "  Uses trie data structure for fast lookups"
        else
          puts "Unknown dictionary type: #{type}"
          puts "Run 'kotoshu dict list' for available types"
        end
      end
    end
  end
end
