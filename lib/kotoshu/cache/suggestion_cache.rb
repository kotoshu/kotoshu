# frozen_string_literal: true

# LookupCache autoloaded via Kotoshu::Cache

module Kotoshu
  module Cache
    # LRU cache specifically for suggestion results.
    #
    # Extends LookupCache with suggestion-specific features like
    # caching by word + max_results combination.
    #
    # @example Caching suggestions
    #   cache = SuggestionCache.new(max_size: 5000)
    #   cache.write("helo", ["hello", "help"], max_results: 10)
    #   cache.read("helo", max_results: 10)  # => ["hello", "help"]
    class SuggestionCache < LookupCache
      # Default maximum cache size for suggestions
      DEFAULT_MAX_SIZE = 5000

      # Create a new suggestion cache.
      #
      # @param max_size [Integer] Maximum number of entries (default: 5000)
      def initialize(max_size: DEFAULT_MAX_SIZE)
        super
      end

      # Write suggestions to cache.
      #
      # @param word [String] The misspelled word
      # @param suggestions [Array<String>] Suggested words
      # @param max_results [Integer] Max results used for this query
      # @return [Array<String>] The stored suggestions
      def write(word, suggestions, max_results: 10)
        cache_key = cache_key_for(word, max_results)
        super(cache_key, suggestions)
      end

      # Read suggestions from cache.
      #
      # @param word [String] The misspelled word
      # @param max_results [Integer] Max results used for this query
      # @return [Array<String>, nil] Cached suggestions or nil
      def read(word, max_results: 10)
        cache_key = cache_key_for(word, max_results)
        super(cache_key)
      end

      # Fetch suggestions from cache or compute them.
      #
      # @param word [String] The misspelled word
      # @param max_results [Integer] Max results for this query
      # @yield Block to compute suggestions on cache miss
      # @return [Array<String>] Cached or computed suggestions
      def fetch(word, max_results: 10)
        cache_key = cache_key_for(word, max_results)

        if @data.key?(cache_key)
          record_hit
          @access_order += 1
          @data[cache_key][1] = @access_order # Update access order
          @data[cache_key][0] # Return value
        else
          record_miss
          suggestions = yield
          write(word, suggestions, max_results: max_results)
          suggestions
        end
      end

      # Delete suggestions from cache.
      #
      # @param word [String] The misspelled word
      # @param max_results [Integer] Max results for this query
      # @return [Array<String>, nil] Deleted suggestions or nil
      def delete(word, max_results: 10)
        cache_key = cache_key_for(word, max_results)
        super(cache_key)
      end

      # Check if suggestions are cached for this word.
      #
      # @param word [String] The misspelled word
      # @param max_results [Integer] Max results for this query
      # @return [Boolean] True if cached
      def key?(word, max_results: 10)
        cache_key = cache_key_for(word, max_results)
        super(cache_key)
      end

      # Invalidate all cached suggestions for a word.
      #
      # @param word [String] The word to invalidate
      # @return [self] Self for chaining
      def invalidate_word(word)
        # Find and delete all cache entries for this word
        keys_to_delete = @data.keys.select { |key| key.start_with?("#{word}|") }
        keys_to_delete.each { |key| @data.delete(key) }
        self
      end

      private

      # Generate cache key for word + max_results.
      #
      # @param word [String] The word
      # @param max_results [Integer] Max results
      # @return [String] Cache key
      def cache_key_for(word, max_results)
        "#{word.downcase}|#{max_results}"
      end
    end
  end
end
