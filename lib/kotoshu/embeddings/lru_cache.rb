# frozen_string_literal: true

# LruCache - Least Recently Used Cache
#
# Provides efficient O(1) LRU caching with optional TTL support.
# Used for caching embeddings during similarity search.
#
# @example Basic usage
#   cache = LruCache.new(max_size: 1000)
#   cache[:key] = value
#   cache[:key]  # => value
#
# @example With TTL
#   cache = LruCache.new(max_size: 1000, ttl: 300)  # 5 minutes
#
class LruCache
  # @return [Integer] Maximum number of entries
  attr_reader :max_size

  # @return [Integer, nil] TTL in seconds
  attr_reader :ttl

  # @return [Integer] Number of cache hits
  attr_reader :hits

  # @return [Integer] Number of cache misses
  attr_reader :misses

  # Create a new LRU cache
  #
  # @param max_size [Integer] Maximum number of entries (default: 1000)
  # @param ttl [Integer, nil] Time-to-live in seconds (default: nil = no expiry)
  #
  def initialize(max_size: 1000, ttl: nil)
    @max_size = max_size
    @ttl = ttl
    @cache = {}  # key -> {value: v, accessed_at: t, created_at: t}
    @order = []  # Ordered list of keys (most recently used first)
    @hits = 0
    @misses = 0
  end

  # Get value for key
  #
  # @param key [Object] Cache key
  # @return [Object, nil] Cached value or nil if not found/expired
  #
  def [](key)
    entry = @cache[key]
    return nil unless entry

    # Check TTL
    if @ttl && (Time.now - entry[:created_at]) > @ttl
      delete(key)
      @misses += 1
      return nil
    end

    # Update access order (move to front = most recently used)
    @order.delete(key)
    @order.unshift(key)
    entry[:accessed_at] = Time.now

    @hits += 1
    entry[:value]
  end

  # Set value for key
  #
  # @param key [Object] Cache key
  # @param value [Object] Value to cache
  # @return [Object] The value
  #
  def []=(key, value)
    # Evict LRU if at capacity
    if @cache.key?(key)
      # Update existing entry
      @cache[key][:value] = value
      @cache[key][:accessed_at] = Time.now
      # Move to front
      @order.delete(key)
      @order.unshift(key)
      return value
    end

    if @cache.size >= @max_size
      evict_lru
    end

    @cache[key] = {
      value: value,
      accessed_at: Time.now,
      created_at: Time.now
    }
    @order.unshift(key)

    value
  end

  # Check if key exists
  #
  # @param key [Object] Cache key
  # @return [Boolean] True if key exists and not expired
  #
  def key?(key)
    entry = @cache[key]
    return false unless entry

    if @ttl && (Time.now - entry[:created_at]) > @ttl
      delete(key)
      return false
    end

    true
  end

  # Delete key from cache
  #
  # @param key [Object] Cache key
  # @return [Object, nil] Deleted value or nil
  #
  def delete(key)
    entry = @cache.delete(key)
    @order.delete(key)
    entry&.[](:value)
  end

  # Clear all entries
  #
  # @return [self]
  #
  def clear
    @cache.clear
    @order.clear
    self
  end

  # Get current size
  #
  # @return [Integer] Number of entries
  #
  def size
    @cache.size
  end

  # Check if empty
  #
  # @return [Boolean]
  #
  def empty?
    @cache.empty?
  end

  # Get least recently used key-value pair
  #
  # @return [Array<Object, Object>, nil]
  #
  def lru
    return nil if @order.empty?

    key = @order.last
    [key, @cache[key][:value]]
  end

  # Get most recently used key-value pair
  #
  # @return [Array<Object, Object>, nil]
  #
  def mru
    return nil if @order.empty?

    key = @order.first
    [key, @cache[key][:value]]
  end

  # Get all keys
  #
  # @return [Array<Object>] Array of keys
  #
  def keys
    @order.dup
  end

  # Get all values
  #
  # @return [Array<Object>] Array of values
  #
  def values
    @order.map { |key| @cache[key][:value] }
  end

  # Get cache statistics
  #
  # @return [Hash] Statistics
  #
  def stats
    total = @hits + @misses
    {
      size: size,
      max_size: @max_size,
      hits: @hits,
      misses: @misses,
      hit_rate: total.zero? ? 0.0 : @hits.to_f / total,
      ttl: @ttl
    }
  end

  # Fetch with block (cache-aside pattern)
  #
  # @param key [Object] Cache key
  # @return [Object] Cached value or block result
  #
  def fetch(key, &block)
    result = self[key]
    return result if result || key?(key)

    value = block.call
    self[key] = value
    value
  end

  private

  # Evict least recently used entry
  #
  def evict_lru
    return if @order.empty?

    lru_key = @order.last
    @cache.delete(lru_key)
    @order.pop
  end
end
