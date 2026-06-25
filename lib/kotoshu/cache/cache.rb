# frozen_string_literal: true

module Kotoshu
  module Cache
    # Base cache interface.
    #
    # All cache implementations should follow this interface.
    #
    # @abstract Subclass must implement {#fetch}, {#write}, {#read}, {#delete}, {#clear}
    module Cache
      # Retrieve a value from cache, or compute it.
      #
      # @param key [Object] The cache key
      # @yield Block to compute value on cache miss
      # @return [Object] The cached or computed value
      # @abstract Subclass must implement
      def fetch(key, &block)
        raise NotImplementedError
      end

      # Write a value to cache.
      #
      # @param key [Object] The cache key
      # @param value [Object] The value to store
      # @return [Object] The stored value
      # @abstract Subclass must implement
      def write(key, value)
        raise NotImplementedError
      end

      # Read a value from cache.
      #
      # @param key [Object] The cache key
      # @return [Object, nil] The cached value or nil
      # @abstract Subclass must implement
      def read(key)
        raise NotImplementedError
      end

      # Delete a value from cache.
      #
      # @param key [Object] The cache key
      # @return [Object, nil] The deleted value or nil
      # @abstract Subclass must implement
      def delete(key)
        raise NotImplementedError
      end

      # Clear all entries from cache.
      #
      # @return [self] Self for chaining
      # @abstract Subclass must implement
      def clear
        raise NotImplementedError
      end

      # Check if key exists in cache.
      #
      # @param key [Object] The cache key
      # @return [Boolean] True if key exists
      # @abstract Subclass must implement
      def key?(key)
        raise NotImplementedError
      end

      # Get number of entries in cache.
      #
      # @return [Integer] Number of entries
      # @abstract Subclass must implement
      def size
        raise NotImplementedError
      end

      # Get cache statistics.
      #
      # @return [Hash] Statistics including :hits, :misses, :size, :hit_rate
      # @abstract Subclass must implement
      def stats
        raise NotImplementedError
      end

      # Reset statistics counters.
      #
      # @return [self] Self for chaining
      # @abstract Subclass must implement
      def reset_stats
        raise NotImplementedError
      end
    end
  end
end
