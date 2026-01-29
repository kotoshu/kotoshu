# frozen_string_literal: true

require_relative "base"

module Kotoshu
  module Dictionary
    # Repository for managing multiple dictionary instances.
    #
    # This class provides a centralized registry for dictionaries,
    # allowing them to be registered and retrieved by key.
    #
    # @example Registering and retrieving dictionaries
    #   repo = Repository.new
    #   repo.register(:en_US, unix_dict)
    #   repo.register(:custom, custom_dict)
    #   repo.get(:en_US)  # => unix_dict
    #
    # @example Using the global repository
    #   Repository.register(:en_US, dict)
    #   Repository.get(:en_US)
    class Repository
      # @return [Hash] The dictionary storage
      attr_reader :dictionaries

      # Create a new repository.
      #
      # @param dictionaries [Hash] Initial dictionaries (optional)
      def initialize(dictionaries = {})
        @dictionaries = dictionaries.dup
      end

      # Register a dictionary.
      #
      # @param key [Symbol, String] The key to register under
      # @param dictionary [Base] The dictionary instance
      # @return [self] Self for chaining
      #
      # @example
      #   repo.register(:en_US, unix_dict)
      def register(key, dictionary)
        @dictionaries[key.to_sym] = dictionary
        self
      end
      alias add register
      alias []= register

      # Get a dictionary by key.
      #
      # @param key [Symbol, String] The key
      # @return [Base, nil] The dictionary or nil if not found
      #
      # @example
      #   repo.get(:en_US)
      def get(key)
        @dictionaries[key.to_sym]
      end
      alias [] get

      # Check if a key is registered.
      #
      # @param key [Symbol, String] The key
      # @return [Boolean] True if the key exists
      #
      # @example
      #   repo.registered?(:en_US)  # => true
      def registered?(key)
        @dictionaries.key?(key.to_sym)
      end
      alias has_key? registered?
      alias key? registered?

      # Unregister a dictionary.
      #
      # @param key [Symbol, String] The key
      # @return [Base, nil] The removed dictionary or nil
      #
      # @example
      #   repo.unregister(:en_US)
      def unregister(key)
        @dictionaries.delete(key.to_sym)
      end
      alias remove unregister

      # Clear all dictionaries.
      #
      # @return [self] Self for chaining
      def clear
        @dictionaries.clear
        self
      end

      # Get all registered keys.
      #
      # @return [Array<Symbol>] All keys
      def keys
        @dictionaries.keys
      end

      # Get all dictionaries.
      #
      # @return [Array<Base>] All dictionaries
      def values
        @dictionaries.values
      end

      # Get the number of registered dictionaries.
      #
      # @return [Integer] Dictionary count
      def size
        @dictionaries.size
      end
      alias count size
      alias length size

      # Check if the repository is empty.
      #
      # @return [Boolean] True if empty
      def empty?
        @dictionaries.empty?
      end

      # Iterate over dictionaries.
      #
      # @yield [key, dictionary] Each key and dictionary
      # @return [Enumerator] Enumerator if no block given
      def each(&block)
        return enum_for(:each) unless block_given?
        @dictionaries.each(&block)
      end

      # Merge another repository into this one.
      #
      # @param other [Repository, Hash] The repository or hash to merge
      # @return [self] Self for chaining
      #
      # @example
      #   repo1.merge(repo2)
      def merge(other)
        dicts_to_merge = other.is_a?(Repository) ? other.dictionaries : other

        @dictionaries.merge!(dicts_to_merge)
        self
      end

      # Find dictionaries by language code.
      #
      # @param language_code [String] The language code
      # @return [Array<Base>] Matching dictionaries
      #
      # @example
      #   repo.find_by_language("en-US")
      def find_by_language(language_code)
        @dictionaries.values.select do |dict|
          dict.language_code.casecmp(language_code).zero?
        end
      end

      # Convert to hash.
      #
      # @return [Hash] Hash representation
      def to_h
        @dictionaries.dup
      end

      # String representation.
      #
      # @return [String] String representation
      def to_s
        "Repository(size: #{size})"
      end
      alias inspect to_s

      # Global repository instance.
      #
      # @return [Repository] The global repository
      #
      # @example Using the global repository
      #   Repository.instance.register(:en_US, dict)
      def self.instance
        @instance ||= new
      end

      # Register a dictionary in the global repository.
      #
      # @param key [Symbol, String] The key
      # @param dictionary [Base] The dictionary
      # @return [Repository] The global repository
      #
      # @example
      #   Repository.register(:en_US, dict)
      def self.register(key, dictionary)
        instance.register(key, dictionary)
      end

      # Get a dictionary from the global repository.
      #
      # @param key [Symbol, String] The key
      # @return [Base, nil] The dictionary or nil
      #
      # @example
      #   Repository.get(:en_US)
      def self.get(key)
        instance.get(key)
      end

      # Unregister a dictionary from the global repository.
      #
      # @param key [Symbol, String] The key
      # @return [Base, nil] The removed dictionary or nil
      def self.unregister(key)
        instance.unregister(key)
      end

      # Clear the global repository.
      #
      # @return [Repository] The global repository
      def self.clear
        instance.clear
      end

      # Get all keys from the global repository.
      #
      # @return [Array<Symbol>] All keys
      def self.keys
        instance.keys
      end

      # Check if a key is registered in the global repository.
      #
      # @param key [Symbol, String] The key
      # @return [Boolean] True if the key exists
      def self.registered?(key)
        instance.registered?(key)
      end
    end
  end
end
