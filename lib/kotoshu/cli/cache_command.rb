# frozen_string_literal: true

require "thor"
require "json"
require "time"

module Kotoshu
  module Cli
    # Cache management CLI — wired as `kotoshu cache <subcommand>` in cli.rb.
    #
    # Operates on the disk-backed `Cache::LanguageCache`. Reads and writes
    # go through the real cache API (`available?`, `cached_resources`,
    # `clear_all`, `clear`, `clean`, `stats`, `get_spelling`, `get_grammar`,
    # `frequency_available?`, `language_info`). Kelly frequency data lives
    # in a separate `Cache::FrequencyCache`.
    class CacheCommand < Thor
      class_option :cache_path,
                   type: :string,
                   default: nil,
                   desc: "Override the cache directory for this invocation"
      class_option :verbose,
                   type: :boolean,
                   default: false,
                   desc: "Enable verbose output",
                   aliases: ["-v"]

      desc "list", "List cached languages"
      method_option :json,
                    type: :boolean,
                    default: false,
                    desc: "Emit JSON instead of text"
      def list
        cache = create_cache
        languages = cached_languages(cache)

        if options[:json]
          puts JSON.pretty_generate(languages: languages)
          return
        end

        if languages.empty?
          puts "No cached languages found"
          return
        end

        puts "Cached languages:"
        languages.each { |lang| puts "  #{lang}" }
      end

      desc "info", "Show cache statistics"
      method_option :json,
                    type: :boolean,
                    default: false,
                    desc: "Emit JSON instead of text"
      def info
        cache = create_cache
        stats = cache.stats

        if options[:json]
          puts JSON.pretty_generate(
            hits: stats[:hits],
            misses: stats[:misses],
            size: stats[:size_bytes],
            hit_rate: stats[:hit_rate],
            cached_resources: stats[:cached_resources],
            location: cache.cache_path
          )
          return
        end

        puts "Cache Statistics"
        puts "  Location: #{cache.cache_path}"
        puts "  Languages cached: #{cached_languages(cache).size}"
        puts "  Size: #{format_bytes(stats[:size_bytes])}"
        puts "  Hits: #{stats[:hits]}, Misses: #{stats[:misses]}"
        puts "  Hit rate: #{(stats[:hit_rate] * 100).round(1)}%"
      end

      desc "clean", "Remove expired cache entries"
      method_option :dry_run,
                    type: :boolean,
                    default: false,
                    desc: "Show what would be removed without removing"
      def clean
        cache = create_cache

        if options[:dry_run]
          stats = cache.stats
          puts "Dry run — no changes made"
          puts "  Cached resources: #{stats[:cached_resources].size}"
          puts "  Size: #{format_bytes(stats[:size_bytes])}"
          return
        end

        result = cache.clean
        puts "Cache cleaned:"
        puts "  Expired entries removed: #{result[:expired_entries_removed]}"
        puts "  Bytes reclaimed: #{format_bytes(result[:bytes_reclaimed])}"
      end

      desc "evict", "Evict oldest entries to enforce the configured size cap"
      method_option :dry_run,
                    type: :boolean,
                    default: false,
                    desc: "Show what would be evicted without removing"
      def evict
        cache = create_cache
        plan = cache.evict(dry_run: options[:dry_run])

        if options[:dry_run]
          if plan[:evict].empty?
            puts "Nothing to evict — cache is under the size cap"
            return
          end

          puts "Dry run — no changes made"
          puts "Would evict #{plan[:evict].size} entries, " \
               "reclaiming #{format_bytes(plan[:bytes_reclaimed])}:"
          print_eviction_list(plan[:evict])
          return
        end

        if plan[:evict].empty?
          puts "Nothing to evict — cache is under the size cap"
          return
        end

        puts "Evicted #{plan[:evict].size} entries, " \
             "reclaimed #{format_bytes(plan[:bytes_reclaimed])}:"
        print_eviction_list(plan[:evict])
      end

      desc "download LANGUAGE", "Download spelling or grammar for a language"
      method_option :type,
                    type: :string,
                    default: "spelling",
                    desc: "Resource type: spelling, grammar, or frequency"
      method_option :force,
                    type: :boolean,
                    default: false,
                    desc: "Force re-download even if cached"
      def download(language)
        cache = create_cache
        type = options[:type]

        case type
        when "spelling"
          result = cache.get_spelling(language, force_download: options[:force])
          puts "Spelling dictionary for '#{language}' at #{File.dirname(result[:dic_path])}"
        when "grammar"
          result = cache.get_grammar(language, force_download: options[:force])
          puts "Grammar rules for '#{language}' at #{result[:rules_path]}"
        when "frequency"
          freq = Cache::FrequencyCache.new(cache_path: frequency_cache_path(cache))
          result = freq.get_frequency(language, force_download: options[:force])
          puts "Frequency data for '#{language}' at #{result[:frequency_path]}"
        else
          raise Errors::UsageError, "Unknown --type: #{type}"
        end
      end

      desc "purge", "Remove all cached data"
      method_option :confirm,
                    type: :boolean,
                    default: false,
                    desc: "Skip the interactive confirmation prompt"
      def purge
        cache = create_cache

        unless options[:confirm]
          print "This will remove all cached dictionaries and frequency data. [y/N] "
          response = $stdin.gets
          return unless response && response.chomp =~ /\A[yY]\z/
        end

        cache.clear_all
        puts "Cache purged"
      end

      desc "validate LANGUAGE", "Validate cached resources for a language"
      def validate(language)
        cache = create_cache
        puts "Validating #{language}"
        puts "  Spelling: #{resource_status(cache, language, 'spelling')}"
        puts "  Grammar: #{resource_status(cache, language, 'grammar')}"
      end

      # Construct a LanguageCache honoring the --cache_path option.
      #
      # Public so specs can substitute a cache with a temp directory.
      def create_cache
        opts = {}
        opts[:cache_path] = options[:cache_path] if options[:cache_path]
        Cache::LanguageCache.new(**opts)
      end

      # Format bytes as a human-readable string with one decimal place.
      #
      # @param bytes [Integer, nil] Bytes
      # @return [String] Formatted string
      def format_bytes(bytes)
        return "0 B" if bytes.nil? || bytes.zero?

        units = %w[B KB MB GB TB]
        exp = [Math.log(bytes, 1024).floor, units.size - 1].min
        "#{format('%.1f', bytes.to_f / (1024**exp))} #{units[exp]}"
      end

      # Human-readable "time ago" string for an ISO8601 timestamp.
      #
      # @param iso_time [String, nil] ISO8601 timestamp
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

      private

      # Distinct language codes that have at least one cached resource.
      def cached_languages(cache)
        cache.cached_resources.map { |r| r.split(":").first }.uniq
      end

      # Print each entry in an eviction plan: path, size, cached-at.
      #
      # @param entries [Array<Hash>] each has :path, :size, :cached_at
      # @return [void]
      def print_eviction_list(entries)
        entries.each do |e|
          puts "  #{e[:path]} (#{format_bytes(e[:size])}, cached #{e[:cached_at] || 'unknown'})"
        end
      end

      # Status line for a (language, type) pair.
      def resource_status(cache, language, type)
        if cache.available?("#{language}:#{type}")
          "✓"
        else
          "✗ Not cached"
        end
      end

      # FrequencyCache lives under a different cache directory; mirror the
      # override when --cache_path is given so tests stay isolated.
      def frequency_cache_path(language_cache)
        return nil unless options[:cache_path]

        File.join(options[:cache_path], "frequency-lists")
      end
    end
  end
end
