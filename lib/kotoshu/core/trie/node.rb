# frozen_string_literal: true

module Kotoshu
  module Core
    module Trie
      # Node in the Trie data structure.
      # Each node represents a character and its children.
      class Node
        attr_reader :character, :children, :terminal, :payload

        def initialize(character = "")
          @character = character
          @children = {}
          @terminal = false
          @payload = nil
        end

        # Add a child node for the given character.
        #
        # @param character [String] The character to add
        # @return [Node] The new or existing child node
        def add_child(character)
          @children[character] ||= Node.new(character)
        end

        # Get child node for the given character.
        #
        # @param character [String] The character to look up
        # @return [Node, nil] The child node or nil if not found
        def child(character)
          @children[character]
        end

        # Check if this node has a child for the given character.
        #
        # @param character [String] The character to check
        # @return [Boolean] True if child exists
        def has_child?(character)
          @children.key?(character)
        end

        # Mark this node as terminal (end of a word).
        #
        # @param payload [Object] Optional payload to store at this node
        def mark_terminal(payload = nil)
          @terminal = true
          @payload = payload
        end

        # Check if this node is terminal.
        #
        # @return [Boolean] True if this is the end of a word
        def terminal?
          @terminal
        end

        # Get all children of this node.
        #
        # @return [Hash] Hash of character to node mappings
        def all_children
          @children
        end

        # Check if this node has any children.
        #
        # @return [Boolean] True if there are children
        def has_children?
          !@children.empty?
        end

        # Get the number of children.
        #
        # @return [Integer] Number of child nodes
        def child_count
          @children.size
        end

        # Convert node to string representation.
        #
        # @return [String] String representation
        def to_s
          "Node('#{@character}', terminal: #{@terminal}, children: #{@children.keys})"
        end

        # Inspect the node.
        #
        # @return [String] Inspection string
        def inspect
          to_s
        end
      end
    end
  end
end
