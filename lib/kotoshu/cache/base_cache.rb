# frozen_string_literal: true

require "fileutils"
require "net/http"
require "json"
require "digest"
require "uri"
require "time"

require_relative "../integrity"

module Kotoshu
  module Cache
    # Abstract base class for all cache implementations.
    #
    # Provides common functionality for:
    # - HTTP downloads with metadata
    # - Cache validation (exists, expired)
    # - Statistics tracking (hits, misses, hit rate)
    # - TTL management
    #
    # Subclasses implement specific download and loading logic.
    #
    # @abstract Subclass must implement {#download_resource}, {#load_cached}
    class BaseCache
      # @return [String] Path to the cache directory
      attr_reader :cache_path

      # @return [String] Base URL for downloading resources
      attr_reader :url_base

      # @return [Integer] Cache TTL in seconds
      attr_reader :cache_ttl

      # @return [Integer] Maximum total cache size in bytes. Recorded
      #   for stats and reporting; future eviction logic
      #   (TODO.impl/34-cache-eviction.md) will enforce it.
      attr_reader :max_cache_size

      # @return [String] GitHub repository URL
      attr_reader :github_url

      # @return [Kotoshu::SourceRegistry] Single source of truth for
      #   per-repo URLs and pins. Subclasses MUST build URLs through
      #   this registry rather than constructing URL strings inline.
      attr_reader :source_registry

      # Create a new cache.
      #
      # @param cache_path [String] Path to cache directory
      # @param url_base [String] Base URL for downloads (deprecated; pass source_registry instead)
      # @param cache_ttl [Integer] Cache TTL in seconds
      # @param github_url [String] GitHub repository URL
      # @param resource_pin [String] Branch/tag/commit for URL templates (deprecated; use source_registry)
      # @param manifest_url [String, nil] Override manifest.json URL
      # @param audit_log [Integrity::AuditLog, nil] Override audit log
      # @param source_registry [Kotoshu::SourceRegistry, nil] Single source of truth for URLs/pins
      # @param max_cache_size [Integer, nil] Maximum cache size in bytes (default 1 GB)
      def initialize(cache_path: nil, url_base: nil, cache_ttl: nil, github_url: nil,
                     resource_pin: nil, manifest_url: nil, audit_log: nil,
                     source_registry: nil, max_cache_size: nil)
        @cache_path = cache_path || default_cache_path
        @source_registry = source_registry || default_source_registry
        @url_base = url_base || @source_registry.base_url
        @cache_ttl = cache_ttl || default_cache_ttl
        @github_url = github_url || default_github_url
        @resource_pin = resource_pin || @source_registry.pin_for_source(:spelling)
        @manifest_url = manifest_url
        @audit_log = audit_log || Kotoshu::Integrity::AuditLog.new
        @max_cache_size = max_cache_size || default_max_cache_size
        @manifest = nil
        @manifest_loaded = false
        @hits = 0
        @misses = 0

        # Ensure cache directory exists
        FileUtils.mkdir_p(@cache_path)
        FileUtils.mkdir_p(File.join(@cache_path, "tmp"))
      end

      # Check if a resource is available in cache.
      #
      # @param resource_id [String] The resource identifier (e.g., language code)
      # @return [Boolean] True if resource is cached and valid
      def available?(resource_id)
        return false unless supports_resource?(resource_id)

        metadata_path = metadata_path_for(resource_id)
        return false unless File.exist?(metadata_path)
        return false if expired?(metadata_path)

        resource_files_exist?(resource_id)
      end

      # Get a resource from cache or download it.
      #
      # @param resource_id [String] The resource identifier
      # @param force_download [Boolean] Force re-download even if cached
      # @return [Object, nil] The cached resource or nil if not available
      def get(resource_id, force_download: false)
        return nil unless supports_resource?(resource_id)

        metadata_path = metadata_path_for(resource_id)

        if !force_download && cached?(metadata_path) && !expired?(metadata_path)
          @hits += 1
          return load_cached(resource_id)
        end

        @misses += 1
        download(resource_id)
      end

      # Clear a specific resource from cache.
      #
      # @param resource_id [String] The resource identifier
      # @return [Boolean] True if cache was cleared
      def clear(resource_id)
        return false unless supports_resource?(resource_id)

        resource_dir = resource_dir_for(resource_id)
        if File.exist?(resource_dir)
          FileUtils.rm_rf(resource_dir)
          return true
        end

        false
      end

      # Clear all cached resources.
      #
      # @return [void]
      def clear_all
        @hits = 0
        @misses = 0
        FileUtils.rm_rf(@cache_path)
        FileUtils.mkdir_p(@cache_path)
        FileUtils.mkdir_p(File.join(@cache_path, "tmp"))
      end

      # Get cache statistics.
      #
      # @return [Hash] Statistics including :hits, :misses, :hit_rate, :size
      def stats
        total = @hits + @misses
        hit_rate = total.positive? ? (@hits.to_f / total) : 0.0

        {
          hits: @hits,
          misses: @misses,
          total: total,
          hit_rate: hit_rate,
          cached_resources: cached_resources,
          size_bytes: cache_size,
          oldest_entry: oldest_entry
        }
      end

      # Reset statistics counters.
      #
      # @return [self] Self for chaining
      def reset_stats
        @hits = 0
        @misses = 0
        self
      end

      # Clean expired cache entries.
      #
      # @return [Hash] Cleanup statistics
      def clean
        expired_count = clean_expired
        size_reclaimed = clean_by_size

        {
          expired_entries_removed: expired_count,
          bytes_reclaimed: size_reclaimed
        }
      end

      # List all cached resources.
      #
      # @return [Array<String>] List of cached resource identifiers
      def cached_resources
        raise NotImplementedError, "Subclass must implement"
      end

      # Check if a resource type is supported.
      #
      # @param resource_id [String] The resource identifier
      # @return [Boolean] True if supported
      def supports_resource?(resource_id)
        raise NotImplementedError, "Subclass must implement"
      end

      # Download a resource from GitHub.
      #
      # @param resource_id [String] The resource identifier
      # @return [Object, nil] Downloaded resource or nil on error
      def download(resource_id)
        return nil unless supports_resource?(resource_id)

        resource_dir = resource_dir_for(resource_id)
        FileUtils.mkdir_p(resource_dir)

        begin
          download_resource(resource_id, resource_dir)
        rescue StandardError => e
          warn "Error downloading #{resource_id}: #{e.message}" if $VERBOSE
          nil
        end
      end

      # Abstract: Download a specific resource.
      #
      # @param resource_id [String] The resource identifier
      # @param dest_path [String] Destination directory
      # @return [Object] Downloaded resource
      # @abstract Subclass must implement
      def download_resource(resource_id, dest_path)
        raise NotImplementedError, "Subclass must implement"
      end

      # Abstract: Load cached resource data.
      #
      # @param resource_id [String] The resource identifier
      # @return [Object, nil] Loaded resource or nil
      # @abstract Subclass must implement
      def load_cached(resource_id)
        raise NotImplementedError, "Subclass must implement"
      end

      # Abstract: Get metadata file path for a resource.
      #
      # @param resource_id [String] The resource identifier
      # @return [String] Metadata file path
      # @abstract Subclass must implement
      def metadata_path_for(resource_id)
        raise NotImplementedError, "Subclass must implement"
      end

      # Abstract: Get resource directory path.
      #
      # @param resource_id [String] The resource identifier
      # @return [String] Resource directory path
      # @abstract Subclass must implement
      def resource_dir_for(resource_id)
        raise NotImplementedError, "Subclass must implement"
      end

      # Abstract: Check if all resource files exist.
      #
      # @param resource_id [String] The resource identifier
      # @return [Boolean] True if all files exist
      # @abstract Subclass must implement
      def resource_files_exist?(resource_id)
        raise NotImplementedError, "Subclass must implement"
      end

      protected

      # Download content from a URL.
      #
      # @param url [String] URL to download
      # @return [String] Downloaded content
      def download_url(url)
        uri = URI.parse(url)

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")
        http.open_timeout = 10
        http.read_timeout = 30

        request = Net::HTTP::Get.new(uri.request_uri)

        response = http.request(request)

        raise "Failed to download #{url}: #{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)

        response.body
      end

      # Download a file to disk, streaming in chunks.
      #
      # @param url [String] Source URL
      # @param dest_path [String] Destination file path
      # @param reporter [#start,#update,#maybe_report_periodic,#finish,nil]
      #   Optional progress reporter. Defaults to
      #   Kotoshu.configuration.download_reporter (typically nil for
      #   programmatic use, set by the CLI during setup).
      def download_file(url, dest_path, reporter: nil)
        reporter ||= Kotoshu.configuration.download_reporter
        uri = URI.parse(url)

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")
        http.open_timeout = 30
        http.read_timeout = 300

        request = Net::HTTP::Get.new(uri.request_uri)

        http.request(request) do |response|
          case response
          when Net::HTTPSuccess
            content_length = content_length_from(response)
            FileUtils.mkdir_p(File.dirname(dest_path))
            received = 0
            reporter&.start(content_length)
            File.open(dest_path, "wb") do |file|
              response.read_body do |chunk|
                file.write(chunk)
                received += chunk.bytesize
                reporter&.update(received)
                reporter&.maybe_report_periodic
              end
            end
            reporter&.finish
          when Net::HTTPRedirection
            download_file(response["location"], dest_path, reporter: reporter)
          else
            raise "Failed to download #{url}: #{response.code} #{response.message}"
          end
        end
      end

      # Extract Content-Length safely. Some servers omit it (chunked
      # transfer encoding); caller treats nil as "size unknown".
      # @param response [Net::HTTPResponse]
      # @return [Integer, nil]
      def content_length_from(response)
        raw = response["Content-Length"]
        return nil if raw.nil? || raw.strip.empty?

        Integer(raw)
      rescue ArgumentError
        nil
      end

      # Write metadata to file.
      #
      # @param path [String] Metadata file path
      # @param metadata [Hash] Metadata to write
      def write_metadata(path, metadata)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, JSON.pretty_generate(metadata))
      end

      # Read metadata from file.
      #
      # @param path [String] Metadata file path
      # @return [Hash, nil] Metadata or nil
      def read_metadata(path)
        return nil unless File.exist?(path)

        JSON.parse(File.read(path))
      rescue JSON::ParserError
        nil
      end

      # Check if cached file exists.
      #
      # @param metadata_path [String] Path to metadata file
      # @return [Boolean] True if cached
      def cached?(metadata_path)
        File.exist?(metadata_path)
      end

      # Check if cached file is expired.
      #
      # @param metadata_path [String] Path to metadata file
      # @return [Boolean] True if expired
      def expired?(metadata_path)
        return true unless File.exist?(metadata_path)

        metadata = read_metadata(metadata_path)
        return true unless metadata

        cached_time_str = metadata["cached_at"] || metadata["version"]
        return true unless cached_time_str

        begin
          cached_time = Time.iso8601(cached_time_str)
          Time.now.utc - cached_time > @cache_ttl
        rescue StandardError
          true
        end
      end

      # Calculate checksum of content.
      #
      # @param content [String] Content to checksum
      # @return [String] SHA256 checksum
      def checksum(content)
        Digest::SHA256.hexdigest(content)
      end

      # Verify downloaded content against the manifest and log to audit.
      #
      # If a manifest is published for this cache's content repo, the content's
      # SHA-256 is checked against the manifest entry for `relative_path`. A
      # mismatch raises {Kotoshu::IntegrityError} — callers MUST remove the
      # corrupt bytes from disk so the next call re-downloads. When no manifest
      # entry exists (kotoshu/dictionaries hasn't shipped one yet), the content
      # is logged as `"unverified"` and accepted — graceful degradation.
      #
      # @param url [String] Source URL (for audit log)
      # @param relative_path [String] Manifest lookup key (e.g., "en/spelling/index.dic")
      # @param content [String] Downloaded bytes
      # @param resource_id [String, nil] Caller-supplied resource identifier
      # @return [void]
      def verify_and_audit(url:, relative_path:, content:, resource_id: nil)
        sha = Digest::SHA256.hexdigest(content)
        entry = manifest_entry_for(relative_path)

        if entry.nil?
          @audit_log.record(
            url: url, status: "unverified", size: content.bytesize,
            sha256: sha, manifest_sha256: nil, resource_id: resource_id
          )
          return
        end

        if sha == entry.sha256
          @audit_log.record(
            url: url, status: "verified", size: content.bytesize,
            sha256: sha, manifest_sha256: entry.sha256, resource_id: resource_id
          )
        else
          @audit_log.record(
            url: url, status: "mismatch", size: content.bytesize,
            sha256: sha, manifest_sha256: entry.sha256, resource_id: resource_id
          )
          raise Kotoshu::IntegrityError.new(
            relative_path, expected: entry.sha256, actual: sha, url: url
          )
        end
      end

      # Pin used in URL templates (default "main"; override via constructor
      # or KOTOSHU_RESOURCE_PIN env var through Configuration).
      #
      # @return [String]
      attr_reader :resource_pin

      private

      # Look up a manifest entry by relative path. Loads the manifest
      # lazily on first call; treats HTTP 404/410 as "no manifest" (returns
      # nil) so verification is gracefully skipped.
      def manifest_entry_for(relative_path)
        load_manifest! unless @manifest_loaded
        @manifest&.fetch(relative_path)
      end

      # Fetch the manifest once per cache instance. Sets @manifest_loaded
      # regardless of outcome so we don't retry on every download.
      def load_manifest!
        @manifest_loaded = true
        url = manifest_url
        return unless url

        begin
          @manifest = Kotoshu::Integrity::Manifest.load(url)
        rescue StandardError => e
          warn "Manifest fetch failed for #{url}: #{e.message}" if $VERBOSE
          @manifest = nil
        end
      end

      # Default manifest URL — subclasses override to point at their repo's
      # manifest.json. Returns nil to opt out of manifest verification.
      def manifest_url
        @manifest_url
      end

      # Get cache size in bytes.
      #
      # @return [Integer] Total size in bytes
      def cache_size
        total = 0
        Dir.glob(File.join(@cache_path, "**", "*")).each do |path|
          total += File.size(path) if File.file?(path)
        end
        total
      end

      # Get oldest cached entry timestamp.
      #
      # @return [String, nil] ISO8601 timestamp or nil
      def oldest_entry
        oldest = nil

        Dir.glob(File.join(@cache_path, "**", "metadata.json")).each do |metadata_path|
          metadata = read_metadata(metadata_path)
          next unless metadata

          timestamp = metadata["cached_at"] || metadata["version"]
          next unless timestamp

          oldest = timestamp if oldest.nil? || timestamp < oldest
        end

        oldest
      end

      # Clean expired cache entries.
      #
      # @return [Integer] Number of entries removed
      def clean_expired
        count = 0

        Dir.glob(File.join(@cache_path, "**", "metadata.json")).each do |metadata_path|
          next unless expired?(metadata_path)

          dir_path = File.dirname(metadata_path)
          FileUtils.rm_rf(dir_path)
          count += 1
        end

        count
      end

      # Clean cache entries by size.
      #
      # @return [Integer] Bytes reclaimed
      def clean_by_size
        0 # Override in subclass if needed
      end

      # Parse resource identifier into components.
      #
      # @param resource_id [String] The resource identifier (e.g., "en:spelling" or "en:fasttext")
      # @return [Array<String>, nil] Array of parts or nil if invalid
      def parse_resource_id(resource_id)
        parts = resource_id.split(":")
        return nil unless parts.size == 2

        parts
      end

      # Extract language code from resource identifier.
      #
      # @param resource_id [String] The resource identifier
      # @return [String, nil] Language code or nil if invalid
      def extract_language(resource_id)
        parts = parse_resource_id(resource_id)
        return nil unless parts

        parts[0]
      end

      # Extract resource type from resource identifier.
      #
      # @param resource_id [String] The resource identifier
      # @return [String, nil] Resource type or nil if invalid
      def extract_type(resource_id)
        parts = parse_resource_id(resource_id)
        return nil unless parts

        parts[1]
      end

      # Default cache path: $XDG_CACHE_HOME/kotoshu
      #
      # @return [String] Default cache path
      def default_cache_path
        Kotoshu::Paths.cache_path
      end

      # Default URL base.
      #
      # @return [String] Default URL base
      def default_url_base
        Kotoshu::SourceRegistry::DEFAULT_BASE_URL
      end

      # Default source registry — pulls from global Configuration so
      # ENV (KOTOSHU_REPOS_BASE_URL, KOTOSHU_DICTIONARIES_PIN, etc.)
      # and programmatic config reach the cache layer automatically.
      #
      # @return [Kotoshu::SourceRegistry]
      def default_source_registry
        Kotoshu::Configuration.instance.source_registry
      end

      # Default GitHub URL.
      #
      # @return [String] Default GitHub URL
      def default_github_url
        "https://github.com/kotoshu"
      end

      # Default cache TTL (7 days).
      #
      # @return [Integer] Default TTL in seconds
      def default_cache_ttl
        604_800
      end

      # Default maximum cache size (1 GB). Future eviction logic
      # (TODO.impl/34) will enforce this; for now it is reported in
      # stats so consumers can decide whether to display a warning.
      #
      # @return [Integer] Default max cache size in bytes
      def default_max_cache_size
        1_073_741_824
      end
    end
  end
end
