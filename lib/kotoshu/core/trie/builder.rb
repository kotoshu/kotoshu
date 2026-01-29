# frozen_string_literal: true

require_relative "trie"

module Kotoshu
  module Core
    module Trie
      # Builder class for constructing Trie objects.
      # Provides a fluent interface for building tries from various sources.
      class Builder
        def initialize
          @trie = Trie.new
        end

        # Add a single word to the trie.
        #
        # @param word [String] The word to add
        # @param payload [Object] Optional payload
        # @return [Builder] Self for chaining
        def add_word(word, payload = nil)
          @trie.insert(word, payload)
          self
        end
        alias << add_word

        # Add multiple words to the trie.
        #
        # @param words [Array<String>] Array of words to add
        # @return [Builder] Self for chaining
        def add_words(words)
          words.each { |word| add_word(word) }
          self
        end

        # Build a trie from a hash (word => payload mapping).
        #
        # @param hash [Hash] Hash of words to payloads
        # @return [Builder] Self for chaining
        def from_hash(hash)
          hash.each { |word, payload| add_word(word, payload) }
          self
        end

        # Build a trie from an array of words.
        #
        # @param array [Array<String>] Array of words
        # @return [Builder] Self for chaining
        def from_array(array)
          add_words(array)
          self
        end

        # Build a trie from a file (one word per line).
        #
        # @param path [String] Path to the file
        # @return [Builder] Self for chaining
        def from_file(path)
          File.foreach(path, chomp: true) do |line|
            next if line.empty? || line.start_with?("#")
            add_word(line)
          end
          self
        end

        # Build a trie from a string (newline-separated words).
        #
        # @param text [String] String containing words
        # @return [Builder] Self for chaining
        def from_string(text)
          text.each_line do |line|
            word = line.strip
            next if word.empty? || word.start_with?("#")
            add_word(word)
          end
          self
        end

        # Get the built trie.
        #
        # @return [Trie] The constructed trie
        def build
          @trie.freeze
        end

        # Build a trie from a file path (class method).
        #
        # @param path [String] Path to the file
        # @return [Trie] The constructed trie
        def self.from_file(path)
          new.from_file(path).build
        end

        # Build a trie from an array of words (class method).
        #
        # @param words [Array<String>] Array of words
        # @return [Trie] The constructed trie
        def self.from_array(words)
          new.from_array(words).build
        end

        # Build a trie from a hash (class method).
        #
        # @param hash [Hash] Hash of words to payloads
        # @return [Trie] The constructed trie
        def self.from_hash(hash)
          new.from_hash(hash).build
        end

        # Build a trie from a string (class method).
        #
        # @param text [String] String containing words
        # @return [Trie] The constructed trie
        def self.from_string(text)
          new.from_string(text).build
        end
      end
    end
  end
end
