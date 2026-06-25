# frozen_string_literal: true

require_relative 'cache/cache'
require_relative 'cache/language_cache'
require_relative 'cache/model_cache'

module Kotoshu
  # Cache module for Kotoshu
  #
  # This module provides access to various cache implementations for
  # dictionaries, models, and other resources.
  #
  # @example Using the language cache
  #   cache = Kotoshu::Cache::LanguageCache.new
  #   dict = cache.get_spelling('en')
  #   # => { dic_path: "~/.kotoshu/languages/en/spelling/index.dic",
  #   #      aff_path: "~/.kotoshu/languages/en/spelling/index.aff",
  #   #      metadata: { ... } }
  #
  module Cache
    class << self
      # Create a new language cache instance
      #
      # @param cache_path [String] optional custom cache directory
      # @param url_base [String] optional custom GitHub URL
      # @return [LanguageCache] new language cache instance
      def language_cache(cache_path: nil, url_base: nil)
        LanguageCache.new(cache_path: cache_path, url_base: url_base)
      end

      # Create a new model cache instance
      #
      # @param cache_path [String] optional custom cache directory
      # @return [ModelCache] new model cache instance
      def model_cache(cache_path: nil)
        ModelCache.new(cache_path: cache_path)
      end
    end
  end
end
