# frozen_string_literal: true

module Kotoshu
  # Core domain models and infrastructure.
  #
  # This module contains the fundamental domain models for the spell checker:
  # - IndexedDictionary: Fast word lookup with multiple indexes
  # - Trie: Prefix tree data structure for efficient string operations
  # - Models: Value objects and result types
  #
  # @example Creating an indexed dictionary
  #   dict = Kotoshu::Core::IndexedDictionary.new(%w[hello world test])
  #   dict.include?("hello")  # => true
  #
  # @example Creating a trie
  #   trie = Kotoshu::Core::Trie::Trie.new
  #   trie.insert("hello")
  #   trie.lookup("hello")  # => true
  module Core
  end
end

# Require core submodules
require_relative "core/exceptions"
require_relative "core/indexed_dictionary"
require_relative "core/trie/trie"
require_relative "core/trie/builder"
require_relative "core/trie/node"
