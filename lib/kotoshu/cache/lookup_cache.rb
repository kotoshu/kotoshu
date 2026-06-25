# frozen_string_literal: true

require_relative "cache"

module Kotoshu
  module Cache
    # LRU (Least Recently Used) cache for fast lookups.
    #
    # This cache automatically evicts the least recently used entries
    # when the maximum size is reached.
    #
    # @example Basic usage
    #   cache = LookupCache.new(max_size: 1000)
    #   cache.write("key", "value")
    #   cache.read("key")  # => "value"
    #
    # @example Using fetch for lazy computation
    #   cache.fetch("expensive_key") { compute_expensive_value() }
    class LookupCache
      include Cache

      # Default maximum cache size
      DEFAULT_MAX_SIZE = 1000

      # @return [Integer] Maximum number of entries
      attr_reader :max_size

      # Create a new LRU cache.
      #
      # @param max_size [Integer] Maximum number of entries (default: 1000)
      def initialize(max_size: DEFAULT_MAX_SIZE)
        @max_size = max_size
        @data = {} # key => [value, access_order]
        @access_order = 0
        @stats = { hits: 0, misses: 0 }
      end

      # Retrieve a value from cache, or compute it.
      #
      # @param key [Object] The cache key
      # @param default [Object] Optional default value (if no block given)
      # @yield Block to compute value on cache miss
      # @return [Object] The cached or computed value
      def fetch(key, default = nil)
        if key?(key)
          record_hit
          @data[key][0] # Return value
        else
          record_miss
          value = block_given? ? yield : default
          write(key, value)
          value
        end
      end

      # Write a value to cache.
      #
      # @param key [Object] The cache key
      # @param value [Object] The value to store
      # @return [Object] The stored value
      def write(key, value)
        evict_if_needed

        @access_order += 1
        @data[key] = [value, @access_order]

        value
      end

      # Read a value from cache.
      #
      # @param key [Object] The cache key
      # @return [Object, nil] The cached value or nil
      def read(key)
        entry = @data[key]

        if entry
          record_hit
          @access_order += 1
          entry[1] = @access_order # Update access order
          entry[0] # Return value
        else
          record_miss
          nil
        end
      end

      # Delete a value from cache.
      #
      # @param key [Object] The cache key
      # @return [Object, nil] The deleted value or nil
      def delete(key)
        entry = @data.delete(key)
        entry&.first # Return value or nil
      end

      # Clear all entries from cache.
      #
      # @return [self] Self for chaining
      def clear
        @data.clear
        @access_order = 0
        self
      end

      # Check if key exists in cache.
      #
      # @param key [Object] The cache key
      # @return [Boolean] True if key exists
      def key?(key)
        @data.key?(key)
      end

      # Get number of entries in cache.
      #
      # @return [Integer] Number of entries
      def size
        @data.size
      end

      # Get cache statistics.
      #
      # @return [Hash] Statistics including :hits, :misses, :size, :hit_rate
      def stats
        total = @stats[:hits] + @stats[:misses]
        hit_rate = total.positive? ? @stats[:hits].to_f / total : 0.0

        {
          hits: @stats[:hits],
          misses: @stats[:misses],
          size: size,
          hit_rate: hit_rate.round(4)
        }
      end

      # Reset statistics counters.
      #
      # @return [self] Self for chaining
      def reset_stats
        @stats = { hits: 0, misses: 0 }
        self
      end

      private

      # Record a cache hit.
      def record_hit
        @stats[:hits] += 1
      end

      # Record a cache miss.
      def record_miss
        @stats[:misses] += 1
      end

      # Evict least recently used entry if cache is full.
      def evict_if_needed
        return if @data.size < @max_size

        # Find entry with lowest access order
        lru_key = @data.min_by { |_, v| v[1] }&.first
        @data.delete(lru_key) if lru_key
      end
    end
  end
end
