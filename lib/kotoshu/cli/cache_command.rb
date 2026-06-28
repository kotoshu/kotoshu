# frozen_string_literal: true

require "thor"
require_relative "../cache/language_cache"
require_relative "../configuration"
require "json"

module Kotoshu
  module Cli
    # Cache management commands.
    #
    # Provides CLI commands for managing the dictionary cache
    # with automatic GitHub download support.
    #
    # @example List available languages
    #   kotoshu cache list
    #
    # @example Download a specific language
    #   kotoshu cache download de
    #
    # @example Show cache status
    #   kotoshu cache status
    #
    # @example Remove cached data
    #   kotoshu cache purge
    class CacheCommand < Thor
      class_option :verbose,
                   type: :boolean,
                   default: false,
                   desc: "Enable verbose output",
                   aliases: ["-v"]

      desc "list", "List available languages and their cache status"
      method_option :verbose, type: :boolean, aliases: '-v', desc: 'Show detailed information'
      def list
        cache = create_cache
        status = cache.cache_status

        puts "Available languages:"
        puts

        # Show cached languages first
        unless status[:cached].empty?
          puts "Cached languages:"
          status[:cached].each do |info|
            print "  #{info[:code]}: #{info[:name]}"
            print " (#{info[:word_count]} words)" if options[:verbose]
            print " [#{info[:license]}]" if options[:verbose]
            puts " ✓"
          end
          puts
        end

        # Show uncached languages
        unless status[:not_cached].empty?
          puts "Not cached (will be downloaded on first use):"
          status[:not_cached].each do |info|
            print "  #{info[:code]}: #{info[:name]}"
            print " (#{info[:word_count]} words)" if options[:verbose]
            puts
          end
        end
      end

      desc "status", "Show cache status and statistics"
      def status
        cache = create_cache
        all_status = cache.cache_status

        total_languages = cache.available_languages.size
        cached_count = all_status[:cached].size
        not_cached_count = all_status[:not_cached].size

        puts "Cache Status:"
        puts "  Cache directory: #{cache.cache_path}"
        puts "  Total languages: #{total_languages}"
        puts "  Cached: #{cached_count}"
        puts "  Not cached: #{not_cached_count}"
        puts

        # Calculate cache size
        cache_size = Dir.glob(File.join(cache.cache_path, '**', '*'))
          .select { |f| File.file?(f) }
          .sum { |f| File.size(f) }

        puts "Cache size: #{format_bytes(cache_size)}"

        # Show oldest and newest cache entries
        all_cached = all_status[:cached].map do |info|
          lang_path = File.join(cache.cache_path, info[:code])
          spelling_meta = File.join(lang_path, 'spelling', 'metadata.json')
          if File.exist?(spelling_meta)
            metadata = JSON.parse(File.read(spelling_meta, encoding: 'UTF-8'))
            [info[:code], Time.iso8601(metadata['downloaded_at'])]
          end
        end.compact

        if all_cached.any?
          oldest = all_cached.min_by { |_, time| time }
          newest = all_cached.max_by { |_, time| time }

          puts
          puts "Oldest cache: #{oldest[0]} (#{oldest[1].strftime('%Y-%m-%d %H:%M')})"
          puts "Newest cache: #{newest[0]} (#{newest[1].strftime('%Y-%m-%d %H:%M')})"
        end
      end

      desc "download LANGUAGE", "Download dictionary for a language from GitHub"
      method_option :force, type: :boolean, aliases: '-f', desc: 'Force re-download even if cached'
      def download(language)
        cache = create_cache

        unless cache.available_languages.include?(language)
          puts "Error: Unknown language '#{language}'"
          puts
          puts "Available languages: #{cache.available_languages.join(', ')}"
          exit(1)
        end

        begin
          puts "Downloading #{language} dictionary from GitHub..."

          # Get dictionary (download if needed)
          dict_result = cache.get_dictionary(language, force_download: options[:force])

          if options[:force] || !dict_result[:metadata]['downloaded_at']
            puts "  ✓ Hunspell dictionary downloaded"
            puts "    Location: #{File.dirname(dict_result[:dic_path])}"
            puts "    Version: #{dict_result[:metadata]['version']}"
          else
            puts "  ✓ Using cached Hunspell dictionary"
            puts "    Location: #{File.dirname(dict_result[:dic_path])}"
            puts "    Cached: #{dict_result[:metadata]['downloaded_at']}"
          end

          # Try to download frequency data (may not be available yet)
          begin
            freq_result = cache.get_frequency_data(language, force_download: options[:force])
            if options[:force] || !freq_result[:metadata]['downloaded_at']
              puts "  ✓ Frequency data downloaded"
            else
              puts "  ✓ Using cached frequency data"
            end
          rescue StandardError => e
            # Frequency data may not be available yet - that's okay
            puts "  ⚠ Frequency data not available (#{e.message})"
          end

          puts
          puts "Dictionary for '#{language}' is ready to use!"
        rescue StandardError => e
          puts "Error downloading dictionary: #{e.message}"
          exit(1)
        end
      end

      desc "info LANGUAGE", "Show information about a language"
      def info(language)
        cache = create_cache

        unless cache.available_languages.include?(language)
          puts "Error: Unknown language '#{language}'"
          puts
          puts "Available languages: #{cache.available_languages.join(', ')}"
          exit(1)
        end

        info_data = cache.get_language_info(language)

        puts "Language: #{info_data[:name]}"
        puts "Code: #{language}"
        puts "Word count: #{info_data[:word_count]}"
        puts "License: #{info_data[:license]}"
        puts "Source: #{info_data[:source]}"
        puts "Cached: #{info_data[:downloaded] ? 'Yes' : 'No'}"

        # Show cached file info if available
        if info_data[:downloaded]
          lang_path = File.join(cache.cache_path, language)

          # Show spelling dict info
          spelling_path = File.join(lang_path, 'spelling', 'metadata.json')
          if File.exist?(spelling_path)
            metadata = JSON.parse(File.read(spelling_path, encoding: 'UTF-8'))
            puts
            puts "Hunspell Dictionary:"
            puts "  Downloaded: #{metadata['downloaded_at']}"
            puts "  Checksum: #{metadata['checksum']}"
          end

          # Show frequency data info if available
          freq_path = File.join(lang_path, 'frequency', 'metadata.json')
          if File.exist?(freq_path)
            metadata = JSON.parse(File.read(freq_path, encoding: 'UTF-8'))
            puts
            puts "Frequency Data:"
            puts "  Downloaded: #{metadata['downloaded_at']}"
            puts "  Checksum: #{metadata['checksum']}"
          end
        end
      end

      desc "purge [LANGUAGE]", "Remove cached dictionary data (for a language or all languages)"
      method_option :confirm, type: :boolean, default: false, desc: "Skip confirmation"
      def purge(language = nil)
        cache = create_cache

        if language.nil?
          # Purge all
          unless options[:confirm]
            puts "This will remove all cached dictionaries and frequency data."
            print "Are you sure? [y/N] "
            return unless /^[Yy]/.match?($stdin.gets.chomp)
          end

          count = cache.purge_all
          puts "Purged #{count} files from cache"
        else
          # Purge specific language
          unless cache.available_languages.include?(language)
            puts "Error: Unknown language '#{language}'"
            puts
            puts "Available languages: #{cache.available_languages.join(', ')}"
            exit(1)
          end

          lang_path = File.join(cache.cache_path, language)

          if File.exist?(lang_path)
            count = Dir.glob(File.join(lang_path, '**', '*')).count { |f| File.file?(f) }
            FileUtils.rm_rf(lang_path)
            puts "Purged #{language} cache (#{count} files)"
          else
            puts "No cached data for #{language}"
          end
        end
      end

      desc "validate LANGUAGE", "Validate cached resources for a language"
      def validate(language)
        cache = create_cache

        puts "Validating #{language}..."

        unless cache.available_languages.include?(language)
          puts "  ✗ Unknown language"
          return
        end

        # Check spelling
        spelling_path = File.join(cache.cache_path, language, 'spelling')
        spelling_meta = File.join(spelling_path, 'metadata.json')

        if File.exist?(spelling_meta)
          metadata = JSON.parse(File.read(spelling_meta, encoding: 'UTF-8'))
          aff_file = File.join(spelling_path, 'index.aff')
          dic_file = File.join(spelling_path, 'index.dic')

          puts "  Spelling:"
          puts "    AFF file: #{File.exist?(aff_file) ? '✓' : '✗'}"
          puts "    DIC file: #{File.exist?(dic_file) ? '✓' : '✗'}"
          puts "    Metadata: ✓"
          puts "    Checksum: #{verify_checksum(dic_file, metadata['checksum']) ? '✓' : '✗'}" if metadata['checksum']
          puts "    Expired: #{expired?(metadata) ? 'Yes' : 'No'}"
        else
          puts "  Spelling: ✗ Not cached"
        end

        # Check frequency
        freq_path = File.join(cache.cache_path, language, 'frequency')
        freq_meta = File.join(freq_path, 'metadata.json')

        if File.exist?(freq_meta)
          puts "  Frequency: ✓"
        else
          puts "  Frequency: ✗ Not cached (optional)"
        end
      end

      private

      # Create a language cache instance.
      #
      # @return [Cache::LanguageCache] The cache instance
      def create_cache
        Cache::LanguageCache.new(
          cache_path: options[:cache_path]
        )
      end

      # Format bytes as human-readable.
      #
      # @param bytes [Integer] Bytes
      # @return [String] Formatted string
      def format_bytes(bytes)
        return "0 B" if bytes.nil? || bytes.zero?

        units = %w[B KB MB GB TB]
        exp = [Math.log(bytes, 1024).floor, units.size - 1].min
        "#{format('%.2f', bytes.to_f / (1024**exp))} #{units[exp]}"
      end

      # Get time ago string.
      #
      # @param iso_time [String] ISO8601 timestamp
      # @return [String] Time ago string
      def time_ago(iso_time)
        return "unknown" unless iso_time

        time = Time.iso8601(iso_time)
        seconds = Time.now - time

        return "just now" if seconds < 60

        minutes = (seconds / 60).to_i
        return "#{minutes}m ago" if minutes < 60

        hours = (minutes / 60).to_i
        return "#{hours}h ago" if hours < 24

        days = (hours / 24).to_i
        return "#{days}d ago" if days < 30

        months = (days / 30).to_i
        return "#{months}mo ago" if months < 12

        years = (months / 12).to_i
        "#{years}y ago"
      end

      # Verify checksum of a file.
      #
      # @param file_path [String] Path to file
      # @param expected_checksum [String] Expected SHA256 checksum
      # @return [Boolean] True if checksum matches
      def verify_checksum(file_path, expected_checksum)
        return false unless File.exist?(file_path)

        require "digest"
        actual = Digest::SHA256.file(file_path).hexdigest
        actual == expected_checksum
      end

      # Check if metadata is expired.
      #
      # @param metadata [Hash] Metadata hash
      # @return [Boolean] True if expired
      def expired?(metadata)
        return false unless metadata['version']

        cached_time = Time.iso8601(metadata['version'])
        Time.now.utc - cached_time > 604_800 # 7 days
      end
    end
  end
end
