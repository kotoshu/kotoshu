# frozen_string_literal: true

# base_cache autoloaded via Kotoshu::Cache

module Kotoshu
  module Cache
    # Frequency cache for Kelly Project frequency lists.
    #
    # Manages Kelly frequency list downloads from the kotoshu/frequency-list-kelly
    # repository. Resources are cached locally in `$XDG_CACHE_HOME/kotoshu/frequency-lists/{code}/`
    # with metadata for versioning and expiration.
    #
    # Extends BaseCache for common download, metadata, and validation logic.
    #
    # @example Getting cached frequency data
    #   cache = FrequencyCache.new
    #   result = cache.get('en')
    #   # => { frequency_path: "~/.cache/kotoshu/frequency-lists/en/frequency.json",
    #   #      tiers: { top_50: Set<...>, top_200: Set<...>, top_1000: Set<...> },
    #   #      metadata: { ... } }
    #
    # @example Checking if frequency data is available
    #   cache = FrequencyCache.new
    #   available = cache.available?('en')
    #   # => true
    class FrequencyCache < BaseCache
      # Kelly Project languages available
      KELLY_LANGUAGES = %w[ar zh en el it no ru sv].freeze

      # GitHub repository for Kelly frequency lists
      GITHUB_REPO = "kotoshu/frequency-list-kelly"
      GITHUB_BRANCH = "main"

      # Get list of available languages.
      #
      # @return [Array<String>] List of available language codes
      def available_languages
        KELLY_LANGUAGES.dup
      end

      # Get frequency data for a language (alias for get).
      #
      # @param language_code [String] ISO 639-1 language code
      # @param force_download [Boolean] Force re-download even if cached
      # @return [Hash, nil] Frequency data with :frequency_path, :tiers, :metadata keys
      def get_frequency(language_code, force_download: false)
        get(language_code, force_download: force_download)
      end

      # Check if a resource type is supported.
      #
      # @param resource_id [String] The resource identifier (language code)
      # @return [Boolean] True if supported
      def supports_resource?(resource_id)
        KELLY_LANGUAGES.include?(resource_id)
      end

      # Install a local frequency file into the cache without going
      # through the network. Mirrors {LanguageCache#install_local} for
      # the frequency resource type — symlinks the user's file into the
      # cache layout and writes a `local-source` metadata record so
      # subsequent {#available?} / {#get} calls find it.
      #
      # @param language_code [String] ISO 639-1 language code
      # @param path [String] Path to the local frequency.json file
      # @param force [Boolean] Overwrite an existing install
      # @return [Hash] { frequency_path:, metadata_path:, source: :local }
      def install_local(language_code, path:, force: false)
        lang_path = language_dir(language_code)
        FileUtils.mkdir_p(lang_path)

        target_frequency = File.join(lang_path, "frequency.json")
        target_metadata = metadata_path_for(language_code)

        if File.exist?(target_frequency) || File.symlink?(target_frequency)
          raise ArgumentError, "#{target_frequency} already exists (use force: true to overwrite)" unless force

          File.unlink(target_frequency)
        end

        File.symlink(File.expand_path(path), target_frequency)

        write_metadata(target_metadata,
                       "version" => Time.now.utc.iso8601,
                       "url" => "local:#{File.expand_path(path)}",
                       "language" => language_code,
                       "type" => "kelly_frequency",
                       "source" => "local",
                       "checksum" => checksum(File.read(path)),
                       "cached_at" => Time.now.utc.iso8601)

        { frequency_path: target_frequency, metadata_path: target_metadata, source: :local }
      end

      # List all cached resources.
      #
      # @return [Array<String>] List of cached language codes
      def cached_resources
        directories = Dir.glob(File.join(@cache_path, "*")).select do |path|
          basename = File.basename(path)
          # Skip dotfiles AND the working-directory scratch slot that
          # BaseCache#initialize creates at <cache_path>/tmp/.
          File.directory?(path) && !basename.start_with?(".") && basename != "tmp"
        end
        directories.map { |path| File.basename(path) }
      end

      # Load cached resource data (implements abstract method).
      #
      # Public — this is the cache-only reader BaseCache declares
      # publicly; resolve paths and FrequencyProvider use it to read
      # without any download.
      #
      # @param language_code [String] The language code
      # @return [Hash, nil] Loaded frequency data
      def load_cached(language_code)
        frequency_file = frequency_file_path(language_code)
        metadata_path = metadata_path(language_code)

        return nil unless File.exist?(frequency_file) && File.exist?(metadata_path)

        metadata = read_metadata(metadata_path)
        return nil unless metadata

        # Load frequency file
        # CommonWordsLoader autoloaded via Kotoshu::Data
        data = Data::CommonWordsLoader.load_from_frequency_file(frequency_file)

        {
          frequency_path: frequency_file,
          tiers: data[:tiers],
          metadata: metadata
        }
      end

      protected

      # Download a specific resource (implements abstract method).
      #
      # @param language_code [String] The language code
      # @param dest_path [String] Destination directory
      # @return [Hash] Downloaded frequency data
      def download_resource(language_code, dest_path)
        FileUtils.mkdir_p(dest_path)

        frequency_file = File.join(dest_path, "frequency.json")
        metadata_path = File.join(dest_path, "metadata.json")

        # Download from GitHub
        url = frequency_url(language_code)

        warn "Downloading Kelly frequency data for #{language_code} from #{url}..." if $VERBOSE

        response = download_url(url)
        verify_and_audit(url: url,
                         relative_path: "data/#{language_code}.json",
                         content: response,
                         resource_id: language_code)

        # Validate it's valid JSON
        JSON.parse(response)

        # Save frequency file
        File.write(frequency_file, response)

        # Save metadata
        metadata = {
          version: Time.now.utc.iso8601,
          url: url,
          language: language_code,
          type: "kelly_frequency",
          checksum: checksum(response),
          cached_at: Time.now.utc.iso8601
        }
        write_metadata(metadata_path, metadata)

        # Load and return the data
        load_cached(language_code)
      end

      # Get metadata file path for a resource.
      #
      # @param language_code [String] The language code
      # @return [String] Metadata file path
      def metadata_path_for(language_code)
        File.join(language_dir(language_code), "metadata.json")
      end

      # Get resource directory path.
      #
      # @param language_code [String] The language code
      # @return [String] Resource directory path
      def resource_dir_for(language_code)
        language_dir(language_code)
      end

      # Check if all resource files exist.
      #
      # @param language_code [String] The language code
      # @return [Boolean] True if all files exist
      def resource_files_exist?(language_code)
        File.exist?(frequency_file_path(language_code))
      end

      private

      # Get the directory path for a language.
      #
      # @param language_code [String] ISO 639-1 language code
      # @return [String] Directory path
      def language_dir(language_code)
        File.join(@cache_path, language_code)
      end

      # Get the path to the frequency JSON file.
      #
      # @param language_code [String] ISO 639-1 language code
      # @return [String] File path
      def frequency_file_path(language_code)
        File.join(language_dir(language_code), "frequency.json")
      end

      # Get the path to the metadata file.
      #
      # @param language_code [String] ISO 639-1 language code
      # @return [String] File path
      def metadata_path(language_code)
        metadata_path_for(language_code)
      end

      # Get the GitHub URL for a language's frequency file.
      #
      # @param language_code [String] ISO 639-1 language code
      # @return [String] Download URL
      def frequency_url(language_code)
        @source_registry.url_for(:frequency, lang: language_code)
      end

      # Kelly repo manifest URL (used for integrity verification).
      #
      # @return [String]
      def manifest_url
        @manifest_url || @source_registry.url_for(:freq_manifest)
      end

      # Default cache path: $XDG_CACHE_HOME/kotoshu/frequency-lists/
      #
      # @return [String] Default cache directory path
      def default_cache_path
        File.join(Kotoshu::Paths.cache_path, "frequency-lists")
      end

      # Default URL base for Kelly frequency lists.
      #
      # @return [String] Default URL base
      def default_url_base
        "https://raw.githubusercontent.com"
      end

      # Default cache TTL (7 days).
      #
      # @return [Integer] Default TTL in seconds
      def default_cache_ttl
        604_800
      end
    end
  end
end
