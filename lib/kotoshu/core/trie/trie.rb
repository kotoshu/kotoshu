# frozen_string_literal: true

require_relative "node"

module Kotoshu
  module Core
    module Trie
      # Trie (prefix tree) data structure for efficient word storage and lookup.
      # Supports prefix matching, word validation, and traversal.
      class Trie
        attr_reader :root, :size

        def initialize
          @root = Node.new
          @size = 0
        end

        # Insert a word into the trie.
        #
        # @param word [String] The word to insert
        # @param payload [Object] Optional payload to store with the word
        # @return [Trie] Self for chaining
        def insert(word, payload = nil)
          node = @root
          word.each_char do |char|
            node = node.add_child(char)
          end

          # Only increment size if this is a new word
          @size += 1 unless node.terminal?
          node.mark_terminal(payload)

          self
        end

        # Check if a word exists in the trie.
        #
        # @param word [String] The word to look up
        # @return [Boolean] True if the word exists
        def lookup(word)
          node = find_node(word)
          !node.nil? && node.terminal?
        end
        alias has_word? lookup
        alias contains? lookup

        # Check if any words in the trie start with the given prefix.
        #
        # @param prefix [String] The prefix to check
        # @return [Boolean] True if any words have this prefix
        def has_prefix?(prefix)
          !find_node(prefix).nil?
        end

        # Get the node for a given word/prefix.
        #
        # @param word [String] The word or prefix to find
        # @return [Node, nil] The node or nil if not found
        def find_node(word)
          node = @root
          word.each_char do |char|
            return nil unless node.has_child?(char)
            node = node.child(char)
          end
          node
        end

        # Get all words with the given prefix.
        #
        # @param prefix [String] The prefix to match
        # @return [Array<String>] Array of words with the prefix
        def words_with_prefix(prefix)
          start_node = find_node(prefix)
          return [] if start_node.nil?

          words = []
          collect_words(start_node, prefix, words)
          words
        end

        # Get all words in the trie.
        #
        # @return [Array<String>] Array of all words
        def all_words
          words = []
          collect_words(@root, "", words)
          words
        end

        # Count words with the given prefix.
        #
        # @param prefix [String] The prefix to count
        # @return [Integer] Number of words with the prefix
        def count_prefix(prefix)
          words_with_prefix(prefix).size
        end

        # Get suggestions for a word based on prefix matching.
        # Returns words that share the longest common prefix.
        #
        # @param word [String] The word to get suggestions for
        # @param max_results [Integer] Maximum number of results
        # @return [Array<String>] Array of suggested words
        def suggestions(word, max_results: 10)
          # Find the longest matching prefix
          node = @root
          i = 0

          while i < word.length && node.has_child?(word[i])
            node = node.child(word[i])
            i += 1
          end

          # Collect all completions from this point
          words = []
          collect_words_limited(node, word[0...i], words, max_results)
          words
        end

        # Iterate over all words in the trie.
        #
        # @yield [word, payload] Each word and its optional payload
        # @return [Enumerator] Enumerator if no block given
        def each_word
          return enum_for(:each_word) unless block_given?

          traverse(@root, "") do |word, node|
            yield word, node.payload if node.terminal?
          end

          self
        end

        # Traverse the trie with a visitor.
        #
        # @yield [prefix, node] Each prefix and node visited
        # @return [Trie] Self for chaining
        def traverse(node = @root, prefix = "", &block)
          return enum_for(:traverse, node, prefix) unless block_given?

          yield prefix, node

          node.all_children.each_value do |child|
            traverse(child, prefix + child.character, &block)
          end

          self
        end

        # Check if the trie is empty.
        #
        # @return [Boolean] True if trie has no words
        def empty?
          @size.zero?
        end

        # Clear all words from the trie.
        #
        # @return [Trie] Self for chaining
        def clear
          @root = Node.new
          @size = 0
          self
        end

        # Merge another trie into this one.
        #
        # @param other [Trie] The trie to merge
        # @return [Trie] Self for chaining
        def merge!(other)
          other.each_word do |word, payload|
            insert(word, payload)
          end
          self
        end

        # Create a new trie with common words from two tries.
        #
        # @param other [Trie] The other trie
        # @return [Trie] New trie with common words
        def &(other)
          result = Trie.new
          each_word do |word, _payload|
            result.insert(word) if other.lookup(word)
          end
          result
        end

        # Create a new trie with words from either trie.
        #
        # @param other [Trie] The other trie
        # @return [Trie] New trie with all words
        def |(other)
          result = Trie.new
          each_word { |word, payload| result.insert(word, payload) }
          other.each_word { |word, payload| result.insert(word, payload) }
          result
        end

        # Convert trie to string representation.
        #
        # @return [String] String representation
        def to_s
          "Trie(size: #{@size})"
        end

        # Inspect the trie.
        #
        # @return [String] Inspection string
        def inspect
          to_s
        end

        private

        # Collect all words from a given node.
        #
        # @param node [Node] The starting node
        # @param prefix [String] The current prefix
        # @param words [Array] Array to collect words into
        def collect_words(node, prefix, words)
          if node.terminal?
            words << prefix
          end

          node.all_children.each do |char, child|
            collect_words(child, prefix + char, words)
          end
        end

        # Collect words with a limit.
        #
        # @param node [Node] The starting node
        # @param prefix [String] The current prefix
        # @param words [Array] Array to collect words into
        # @param limit [Integer] Maximum number of words to collect
        def collect_words_limited(node, prefix, words, limit)
          return if words.size >= limit

          if node.terminal?
            words << prefix
          end

          return if words.size >= limit

          node.all_children.each_value do |child|
            collect_words_limited(child, prefix + child.character, words, limit)
            break if words.size >= limit
          end
        end
      end
    end
  end
end
