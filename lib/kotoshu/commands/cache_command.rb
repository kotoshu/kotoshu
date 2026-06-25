# frozen_string_literal: true

require_relative '../cache/language_cache'
require_relative '../cache/model_cache'
require_relative '../cache/frequency_cache'
require 'json'

module Kotoshu
  class CacheCommand < Thor
    namespace :cache

    desc 'list [TYPE]', 'List available resources and their cache status'
    method_option :verbose, type: :boolean, aliases: '-v', desc: 'Show detailed information'
    method_option :type, type: :string, aliases: '-t', desc: 'Cache type: language, model, frequency (default: all)'
    def list(type = nil)
      type ||= options[:type] || 'all'

      if type == 'all'
        list_all_types
      else
        list_type(type)
      end
    end

    desc 'download TYPE RESOURCE', 'Download a resource from GitHub'
    method_option :force, type: :boolean, aliases: '-f', desc: 'Force re-download even if cached'
    def download(type, resource)
      cache = cache_for_type(type)

      case type
      when 'language', 'lang', 'l'
        download_language(cache, resource)
      when 'model', 'm'
        download_model(cache, resource)
      when 'frequency', 'freq', 'f'
        download_frequency(cache, resource)
      else
        puts "Error: Unknown cache type '#{type}'"
        puts "Available types: language, model, frequency"
        exit(1)
      end
    end

    desc 'info TYPE RESOURCE', 'Show information about a cached resource'
    def info(type, resource)
      cache = cache_for_type(type)

      case type
      when 'language', 'lang', 'l'
        info_language(cache, resource)
      when 'model', 'm'
        info_model(cache, resource)
      when 'frequency', 'freq', 'f'
        info_frequency(cache, resource)
      else
        puts "Error: Unknown cache type '#{type}'"
        puts "Available types: language, model, frequency"
        exit(1)
      end
    end

    desc 'purge TYPE [RESOURCE]', 'Remove cached data (for a resource or all resources)'
    method_option :type, type: :string, aliases: '-t', desc: 'Cache type: language, model, frequency, or all'
    def purge(type = nil, resource = nil)
      type ||= options[:type]

      if type.nil? || type == 'all'
        purge_all_types
      else
        purge_type(type, resource)
      end
    end

    desc 'status [TYPE]', 'Show cache status and statistics'
    def status(type = nil)
      type ||= options[:type] || 'all'

      if type == 'all'
        status_all_types
      else
        status_type(type)
      end
    end

    desc 'clean', 'Clean expired cache entries'
    def clean
      total_removed = 0
      total_reclaimed = 0

      %w[language model frequency].each do |type|
        cache = cache_for_type(type)
        result = cache.clean
        total_removed += result[:expired_entries_removed]
        total_reclaimed += result[:bytes_reclaimed]
      end

      puts "Cleaned cache:"
      puts "  Entries removed: #{total_removed}"
      puts "  Bytes reclaimed: #{format_bytes(total_reclaimed)}"
    end

    private

    def cache_for_type(type)
      case type
      when 'language', 'lang', 'l'
        Cache::LanguageCache.new
      when 'model', 'm'
        Cache::ModelCache.new
      when 'frequency', 'freq', 'f'
        Cache::FrequencyCache.new
      else
        raise "Unknown cache type: #{type}"
      end
    end

    def list_all_types
      puts "=" * 70
      puts "Kotoshu Cache Status"
      puts "=" * 70
      puts

      %w[language model frequency].each do |type|
        cache = cache_for_type(type)
        puts "#{type.capitalize} Cache:"
        puts "  Directory: #{cache.cache_path}"
        puts "  Resources: #{cache.cached_resources.size} cached"

        if options[:verbose]
          stats = cache.stats
          puts "  Stats: #{stats[:hits]} hits, #{stats[:misses]} misses (#{(stats[:hit_rate] * 100).round(1)}% hit rate)"
          puts "  Size: #{format_bytes(stats[:size_bytes])}"
        end
        puts
      end
    end

    def list_type(type)
      cache = cache_for_type(type)
      resources = cache.cached_resources

      puts "#{type.capitalize} Cache:"
      puts "  Directory: #{cache.cache_path}"
      puts "  Resources: #{resources.size} cached"

      if resources.any?
        puts
        resources.each do |res|
          puts "  - #{res}"
        end
      else
        puts "  (no resources cached yet)"
      end
    end

    def download_language(cache, language)
      unless cache.available_languages.include?(language)
        puts "Error: Unknown language '#{language}'"
        puts "Available languages: #{cache.available_languages.join(', ')}"
        exit(1)
      end

      puts "Downloading resources for #{language}..."

      # Try spelling dictionary
      begin
        dict_result = cache.get_spelling(language, force_download: options[:force])
        puts "  ✓ Spelling dictionary: #{dict_result[:cached] ? 'cached' : 'downloaded'}"
        puts "    Location: #{File.dirname(dict_result[:dic_path])}"
      rescue StandardError => e
        puts "  ✗ Spelling dictionary failed: #{e.message}"
      end

      # Try frequency data (Kelly)
      begin
        freq_cache = Cache::FrequencyCache.new
        if freq_cache.available?(language) || !options[:force]
          freq_result = freq_cache.get(language, force_download: options[:force])
          puts "  ✓ Frequency data: #{freq_result ? 'loaded' : 'not available'}"
        end
      rescue StandardError => e
        puts "  ℹ Frequency data: #{e.message}"
      end
    end

    def download_model(cache, resource_id)
      parts = resource_id.split(':')
      if parts.size != 2
        puts "Error: Resource must be in format 'language:type' (e.g., 'en:fasttext')"
        exit(1)
      end

      language, model_type = parts

      unless cache.available_models_for(language).include?(model_type.to_sym)
        puts "Error: Unknown model '#{model_type}' for language '#{language}'"
        puts "Available models for #{language}: #{cache.available_models_for(language).join(', ')}"
        exit(1)
      end

      puts "Downloading #{model_type} model for #{language}..."

      result = cache.get(resource_id, force_download: options[:force])
      if result
        file_size = File.size(result[:model_path]) if File.exist?(result[:model_path])
        puts "  ✓ Model downloaded: #{result[:model_path]}"
        puts "    Size: #{format_bytes(file_size)}" if file_size
      else
        puts "  ✗ Download failed"
        exit(1)
      end
    end

    def download_frequency(cache, language)
      unless cache.available_languages.include?(language)
        puts "Error: Unknown language '#{language}'"
        puts "Available languages: #{cache.available_languages.join(', ')}"
        exit(1)
      end

      puts "Downloading Kelly frequency data for #{language}..."

      result = cache.get(language, force_download: options[:force])
      if result
        puts "  ✓ Frequency data downloaded: #{result[:frequency_path]}"
        puts "    Tiers: top_50=#{result[:tiers][:top_50].size}, " \
             "top_200=#{result[:tiers][:top_200].size}, top_1000=#{result[:tiers][:top_1000].size}"
      else
        puts "  ✗ Download failed"
        exit(1)
      end
    end

    def info_language(cache, language)
      unless cache.available_languages.include?(language)
        puts "Error: Unknown language '#{language}'"
        puts "Available languages: #{cache.available_languages.join(', ')}"
        exit(1)
      end

      info_data = cache.language_info(language)

      puts "Language: #{info_data[:name]}"
      puts "Code: #{language}"
      puts "Word count: #{info_data[:word_count]}"
      puts "License: #{info_data[:license]}"
      puts "Source: #{info_data[:source]}"

      # Show cache status
      resource_id = "#{language}:spelling"
      if cache.available?(resource_id)
        metadata_path = cache.metadata_path_for(resource_id)
        metadata = cache.send(:read_metadata, metadata_path)
        if metadata
          puts
          puts "Cache Status: Cached"
          puts "  Cached at: #{metadata['cached_at']}"
          puts "  Version: #{metadata['version']}"
          puts "  Checksum: #{metadata['checksum']}"
        end
      else
        puts "Cache Status: Not cached"
      end
    end

    def info_model(cache, resource_id)
      parts = resource_id.split(':')
      if parts.size != 2
        puts "Error: Resource must be in format 'language:type' (e.g., 'en:fasttext')"
        exit(1)
      end

      language, model_type = parts

      model_info = cache.model_info(language, model_type.to_sym)
      unless model_info
        puts "Error: Unknown model '#{model_type}' for language '#{language}'"
        exit(1)
      end

      puts "Model: #{model_info[:file]}"
      puts "Language: #{language}"
      puts "Type: #{model_type}"
      puts "Source: #{model_info[:source]}"
      puts "Size: #{model_info[:size]}"

      # Show cache status
      if cache.available?(resource_id)
        metadata_path = cache.send(:metadata_path_for, resource_id)
        metadata = cache.send(:read_metadata, metadata_path)
        if metadata
          puts
          puts "Cache Status: Cached"
          puts "  Cached at: #{metadata['cached_at']}"
          puts "  Checksum: #{metadata['checksum']}"
        end
      else
        puts "Cache Status: Not cached"
      end
    end

    def info_frequency(cache, language)
      unless cache.available_languages.include?(language)
        puts "Error: Unknown language '#{language}'"
        puts "Available languages: #{cache.available_languages.join(', ')}"
        exit(1)
      end

      puts "Kelly Frequency Data"
      puts "Language: #{language}"

      # Show cache status
      if cache.available?(language)
        result = cache.get(language)
        metadata = result[:metadata]

        puts
        puts "Cache Status: Cached"
        puts "  Cached at: #{metadata['cached_at']}"
        puts "  Version: #{metadata['version']}"
        puts "  Checksum: #{metadata['checksum']}"
        puts "  URL: #{metadata['url']}"
        puts
        puts "Frequency Tiers:"
        puts "  Top 50: #{result[:tiers][:top_50].size} words"
        puts "  Top 200: #{result[:tiers][:top_200].size} words"
        puts "  Top 1000: #{result[:tiers][:top_1000].size} words"
      else
        puts "Cache Status: Not cached"
        puts "  Download with: kotoshu cache download frequency #{language}"
      end
    end

    def purge_all_types
      puts "Purging all cache types..."

      %w[language model frequency].each do |type|
        cache = cache_for_type(type)
        count = cache.cached_resources.size

        if count.positive?
          cache.clear_all
          puts "  ✓ #{type.capitalize}: #{count} resources purged"
        else
          puts "  - #{type.capitalize}: no cached resources"
        end
      end
    end

    def purge_type(type, resource)
      cache = cache_for_type(type)

      if resource.nil?
        # Purge all resources of this type
        count = cache.cached_resources.size
        cache.clear_all
        puts "Purged #{count} #{type} resources"
      else
        # Purge specific resource
        if cache.clear(resource)
          puts "Purged #{type} resource: #{resource}"
        else
          puts "No cached data for #{type}:#{resource}"
        end
      end
    end

    def status_all_types
      puts "=" * 70
      puts "Kotoshu Cache Status"
      puts "=" * 70
      puts

      total_size = 0
      total_hits = 0
      total_misses = 0

      %w[language model frequency].each do |type|
        cache = cache_for_type(type)
        stats = cache.stats

        total_size += stats[:size_bytes]
        total_hits += stats[:hits]
        total_misses += stats[:misses]

        puts "#{type.capitalize} Cache:"
        puts "  Directory: #{cache.cache_path}"
        puts "  Resources cached: #{stats[:cached_resources].size}"
        puts "  Size: #{format_bytes(stats[:size_bytes])}"
        puts "  Hits: #{stats[:hits]}, Misses: #{stats[:misses]}"
        puts "  Hit rate: #{(stats[:hit_rate] * 100).round(1)}%"
        puts
      end

      puts "Total:"
      puts "  Total size: #{format_bytes(total_size)}"
      overall_hit_rate = total_hits + total_misses > 0 ? (total_hits.to_f / (total_hits + total_misses) * 100).round(1) : 0
      puts "  Overall hit rate: #{overall_hit_rate}%"
    end

    def status_type(type)
      cache = cache_for_type(type)
      stats = cache.stats

      puts "#{type.capitalize} Cache:"
      puts "  Directory: #{cache.cache_path}"
      puts "  Resources cached: #{stats[:cached_resources].size}"
      puts "  Size: #{format_bytes(stats[:size_bytes])}"
      puts "  Hits: #{stats[:hits]}, Misses: #{stats[:misses]}"
      puts "  Hit rate: #{(stats[:hit_rate] * 100).round(1)}%"
    end

    # Format bytes to human-readable size
    def format_bytes(bytes)
      return '0 B' if bytes.zero?

      units = %w[B KB MB GB]
      exp = (Math.log(bytes) / Math.log(1024)).to_i
      exp = units.size - 1 if exp >= units.size

      format('%.2f %s', bytes / (1024.0**exp), units[exp])
    end
  end
end
