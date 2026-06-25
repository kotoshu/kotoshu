# frozen_string_literal: true

module Kotoshu
  module DataStructures
    # Bloom filter - probabilistic data structure for fast membership testing.
    #
    # A Bloom filter is a space-efficient probabilistic data structure that
    # is used to test whether an element is a member of a set. False positive
    # matches are possible, but false negatives are not.
    #
    # @example Basic usage
    #   filter = BloomFilter.new
    #   filter.add("hello")
    #   filter.include?("hello")  # => true (definitely in set)
    #   filter.include?("world")  # => false (probably not in set)
    #
    # @see https://en.wikipedia.org/wiki/Bloom_filter Bloom filter Wikipedia
    class BloomFilter
      # Default false positive rate (1%)
      DEFAULT_FALSE_POSITIVE_RATE = 0.01

      # Default expected number of elements
      DEFAULT_EXPECTED_SIZE = 10_000

      # @return [Integer] Size of the bit array
      attr_reader :size

      # @return [Integer] Number of hash functions
      attr_reader :hash_count

      # @return [Integer] Number of items added
      attr_reader :item_count

      # Create a new Bloom filter.
      #
      # @param expected_size [Integer] Expected number of elements (default: 10_000)
      # @param false_positive_rate [Float] Desired false positive rate (default: 0.01)
      # @param case_sensitive [Boolean] Whether lookups are case-sensitive (default: false)
      def initialize(expected_size: DEFAULT_EXPECTED_SIZE,
                     false_positive_rate: DEFAULT_FALSE_POSITIVE_RATE,
                     case_sensitive: false)
        @case_sensitive = case_sensitive
        @item_count = 0

        # Calculate optimal size and hash count
        # m = -n * ln(p) / (ln(2)^2)
        # k = (m/n) * ln(2)
        @size = calculate_size(expected_size, false_positive_rate)
        @hash_count = calculate_hash_count(@size, expected_size)

        # Initialize bit array
        @bits = Array.new(@size, false)
      end

      # Add an element to the filter.
      #
      # @param item [String] The item to add
      # @return [self] Self for chaining
      def add(item)
        normalized_item = normalize_item(item)

        @hash_count.times do |i|
          index = hash_index(normalized_item, i)
          @bits[index] = true
        end

        @item_count += 1
        self
      end

      # Check if an element might be in the filter.
      #
      # Note: Returns false if the element is definitely NOT in the filter.
      # Returns true if the element is PROBABLY in the filter (may be false positive).
      #
      # @param item [String] The item to check
      # @return [Boolean] True if possibly in filter, false if definitely not
      def include?(item)
        normalized_item = normalize_item(item)

        @hash_count.times do |i|
          index = hash_index(normalized_item, i)
          return false unless @bits[index]
        end

        true
      end
      alias include? include?
      alias might_include? include?

      # Merge another bloom filter into this one.
      #
      # @param other [BloomFilter] Another bloom filter with same parameters
      # @return [self] Self for chaining
      def merge(other)
        raise ArgumentError, "Cannot merge filters with different sizes" unless other.size == @size
        raise ArgumentError, "Cannot merge filters with different hash counts" unless other.hash_count == @hash_count

        @size.times do |i|
          @bits[i] = @bits[i] || other.instance_variable_get(:@bits)[i]
        end

        @item_count += other.item_count
        self
      end

      # Clear all elements from the filter.
      #
      # @return [self] Self for chaining
      def clear
        @bits = Array.new(@size, false)
        @item_count = 0
        self
      end

      # Get filter statistics.
      #
      # @return [Hash] Statistics including :size, :hash_count, :item_count
      def stats
        {
          size: @size,
          hash_count: @hash_count,
          item_count: @item_count
        }
      end

      private

      # Normalize item for consistent hashing.
      #
      # @param item [String] The item to normalize
      # @return [String] Normalized item
      def normalize_item(item)
        @case_sensitive ? item.to_s : item.to_s.downcase
      end

      # Calculate optimal bit array size.
      #
      # @param n [Integer] Expected number of elements
      # @param p [Float] False positive rate
      # @return [Integer] Optimal size in bits
      def calculate_size(n, p)
        # m = -n * ln(p) / (ln(2)^2)
        m = (-n * Math.log(p)) / (Math.log(2)**2)
        m.ceil.to_i
      end

      # Calculate optimal number of hash functions.
      #
      # @param m [Integer] Size of bit array
      # @param n [Integer] Expected number of elements
      # @return [Integer] Optimal number of hash functions
      def calculate_hash_count(m, n)
        # k = (m/n) * ln(2)
        k = (m.to_f / n) * Math.log(2)
        [1, k.ceil.to_i].max # At least 1 hash function
      end

      # Calculate hash index for item with seed.
      #
      # Uses double hashing for multiple hash functions:
      # hash_i(item) = (hash1(item) + i * hash2(item)) % m
      #
      # @param item [String] The item to hash
      # @param seed [Integer] Hash function index
      # @return [Integer] Bit array index
      def hash_index(item, seed)
        # Use Ruby's built-in hash with different seeds
        hash1 = item.hash
        hash2 = (item.hash * 31) + seed

        (hash1 + seed * hash2.abs) % @size
      end
    end
  end
end
