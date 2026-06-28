# frozen_string_literal: true

# base_cache autoloaded via Kotoshu::Cache

module Kotoshu
  module Cache
    # Language cache for dynamic dictionary and grammar rule downloads.
    #
    # Manages per-language dictionary and grammar rule downloads from a remote
    # repository. Resources are cached locally in `$XDG_CACHE_HOME/kotoshu/languages/{code}/`
    # with metadata for versioning and expiration.
    #
    # Extends BaseCache for common download, metadata, and validation logic.
    #
    # @example Getting a cached spelling dictionary
    #   cache = LanguageCache.new
    #   result = cache.get('en')
    #   # => { aff_path: "~/.cache/kotoshu/languages/en/spelling/index.aff",
    #   #      dic_path: "~/.cache/kotoshu/languages/en/spelling/index.dic",
    #   #      metadata: { ... } }
    #
    # @example Checking cache statistics
    #   stats = cache.stats
    #   # => { hits: 5, misses: 1, hit_rate: 0.83, ... }
    class LanguageCache < BaseCache
      # Supported resource types
      RESOURCE_TYPES = %w[spelling grammar frequency].freeze

      # Available languages
      AVAILABLE_LANGUAGES = %w[de en es fr pt ru].freeze

      # Get or download spelling dictionary for a language.
      #
      # @param language [String] Language code (e.g., 'en', 'de')
      # @param force_download [Boolean] Force re-download even if cached
      # @return [Hash] Dictionary paths and metadata
      def get_spelling(language, force_download: false)
        resource_id = "#{language}:spelling"
        result = get(resource_id, force_download: force_download)
        result || download_spelling(language)
      end

      # Install a spelling dictionary from local files (no download).
      # Used by ResourceManager.setup_from_local when the user already
      # has .aff/.dic files on disk. Symlinks the source files into the
      # cache directory so subsequent cache lookups find them. Existing
      # symlinks are replaced when force: true; existing real files
      # raise ArgumentError unless force: true.
      #
      # @param language [String] Language code
      # @param aff [String] Path to .aff file
      # @param dic [String] Path to .dic file
      # @param force [Boolean] Overwrite existing install
      # @return [Hash] Installed paths
      def install_local(language, aff:, dic:, force: false)
        require "fileutils"

        resource_id = "#{language}:spelling"
        lang_path = resource_dir_for(resource_id)
        FileUtils.mkdir_p(lang_path)

        target_aff = File.join(lang_path, "index.aff")
        target_dic = File.join(lang_path, "index.dic")

        if File.exist?(target_aff) || File.symlink?(target_aff)
          raise ArgumentError, "#{target_aff} already exists (use force: true to overwrite)" unless force

          File.unlink(target_aff)
        end
        if File.exist?(target_dic) || File.symlink?(target_dic)
          raise ArgumentError, "#{target_dic} already exists (use force: true to overwrite)" unless force

          File.unlink(target_dic)
        end

        File.symlink(File.expand_path(aff), target_aff)
        File.symlink(File.expand_path(dic), target_dic)

        write_metadata(metadata_path_for(resource_id),
                       build_metadata(language, "spelling", "local-source"))

        { aff_path: target_aff, dic_path: target_dic, source: :local }
      end

      # Alias for get_spelling for backward compatibility.
      #
      # @param language [String] Language code
      # @param force_download [Boolean] Force re-download
      # @return [Hash] Dictionary paths and metadata
      def get_dictionary(language, force_download: false)
        get_spelling(language, force_download)
      end

      # Get or download grammar rules for a language.
      #
      # @param language [String] Language code
      # @param force_download [Boolean] Force re-download
      # @return [Hash] Rules path and metadata
      def get_grammar(language, force_download: false)
        resource_id = "#{language}:grammar"
        result = get(resource_id, force_download: force_download)
        result || download_grammar(language)
      end

      # Check if frequency data is available for a language.
      #
      # @param language_code [String] ISO 639-1 language code
      # @return [Boolean] True if frequency data exists
      def frequency_available?(language_code)
        resource_id = "#{language_code}:frequency"
        available?(resource_id)
      end

      # Get list of available languages.
      #
      # @return [Array<String>] List of supported language codes
      def available_languages
        AVAILABLE_LANGUAGES.dup
      end

      # Absolute on-disk path for a (language, resource_type) pair.
      #
      # Composes `cache_path/languages/{lang}/{type}`. Use this rather
      # than reaching into `cache_path` from outside the cache — it
      # keeps the on-disk layout encapsulated and lets the layout
      # evolve without breaking callers.
      #
      # @param language [String] Language code (e.g., 'en', 'de')
      # @param type [String] Resource type ('spelling', 'grammar', 'frequency')
      # @return [String] Absolute directory path for the resource
      def language_path(language, type)
        File.join(@cache_path, "languages", language, type)
      end

      # Get language metadata (word count, license, source).
      #
      # @param language_code [String] The language code
      # @return [Hash] Language info
      def language_info(language_code)
        {
          "de" => { name: "German", word_count: 75_873, license: "GPL", source: "igerman98" },
          "en" => { name: "English", word_count: 49_568, license: "LGPL/MPL/GPL", source: "SCOWL" },
          "es" => { name: "Spanish", word_count: 57_344, license: "GPL", source: "LibreOffice" },
          "fr" => { name: "French", word_count: 84_310, license: "MPL 2.0", source: "Grammalecte" },
          "pt" => { name: "Portuguese", word_count: 312_368, license: "LGPLv3 + MPL", source: "VERO" },
          "ru" => { name: "Russian", word_count: 146_269, license: "BSD-style", source: "Alexander Lebedev" }
        }[language_code] || { name: language_code.upcase, word_count: 0, license: "Unknown", source: "Unknown" }
      end

      # Get cache size in bytes (override for language-specific tracking).
      #
      # @return [Integer] Total size in bytes
      def cache_size
        total = 0
        Dir.glob(File.join(@cache_path, "languages", "**", "*.dic")).each do |path|
          total += File.size(path) if File.file?(path)
        end
        total
      end

      # List all cached resources.
      #
      # @return [Array<String>] List of cached resource identifiers
      def cached_resources
        Dir.glob(File.join(@cache_path, "languages", "**", "metadata.json")).map do |path|
          relative = Pathname.new(path).relative_path_from(Pathname.new(@cache_path))
          parts = relative.to_s.split("/")
          "#{parts[1]}:#{parts[2]}"
        end.uniq
      end

      # Check if a resource type is supported.
      #
      # @param resource_id [String] The resource identifier (e.g., "en:spelling")
      # @return [Boolean] True if supported
      def supports_resource?(resource_id)
        parts = resource_id.split(":")
        return false unless parts.size == 2

        language, type = parts
        AVAILABLE_LANGUAGES.include?(language) && RESOURCE_TYPES.include?(type)
      end

      protected

      # Download a spelling dictionary.
      #
      # @param language [String] Language code
      # @return [Hash] Dictionary paths and metadata
      def download_spelling(language)
        lang_path = resource_dir_for("#{language}:spelling")
        resource_id = "#{language}:spelling"

        # Download index.aff
        aff_url = @source_registry.url_for(:spelling, lang: language, ext: "aff")
        aff_content = download_url(aff_url)
        verify_and_audit(url: aff_url,
                         relative_path: "#{language}/spelling/index.aff",
                         content: aff_content,
                         resource_id: resource_id)
        File.write(File.join(lang_path, "index.aff"), aff_content)

        # Download index.dic
        dic_url = @source_registry.url_for(:spelling, lang: language, ext: "dic")
        dic_content = download_url(dic_url)
        verify_and_audit(url: dic_url,
                         relative_path: "#{language}/spelling/index.dic",
                         content: dic_content,
                         resource_id: resource_id)
        File.write(File.join(lang_path, "index.dic"), dic_content)

        # Save metadata
        metadata = build_metadata(language, "spelling", checksum(dic_content))
        write_metadata(metadata_path_for(resource_id), metadata)

        {
          aff_path: File.join(lang_path, "index.aff"),
          dic_path: File.join(lang_path, "index.dic"),
          cached: false,
          metadata: metadata
        }
      end

      # Download grammar rules.
      #
      # @param language [String] Language code
      # @return [Hash] Rules path and metadata
      def download_grammar(language)
        lang_path = resource_dir_for("#{language}:grammar")
        resource_id = "#{language}:grammar"

        # Download rules.yaml
        rules_url = @source_registry.url_for(:grammar, lang: language)
        rules_content = download_url(rules_url)
        verify_and_audit(url: rules_url,
                         relative_path: "#{language}/grammar/rules.yaml",
                         content: rules_content,
                         resource_id: resource_id)
        File.write(File.join(lang_path, "rules.yaml"), rules_content)

        # Save metadata
        metadata = build_metadata(language, "grammar", checksum(rules_content))
        write_metadata(metadata_path_for(resource_id), metadata)

        {
          rules_path: lang_path,
          cached: false,
          metadata: metadata
        }
      end

      # Download frequency data.
      #
      # @param language [String] Language code
      # @return [Hash] Frequency data path and metadata
      def download_frequency(language)
        lang_path = resource_dir_for("#{language}:frequency")
        resource_id = "#{language}:frequency"

        # Download frequency.json from Kelly repository
        freq_url = @source_registry.url_for(:frequency, lang: language)
        freq_content = download_url(freq_url)
        verify_and_audit(url: freq_url,
                         relative_path: "data/#{language}.json",
                         content: freq_content,
                         resource_id: resource_id)

        # Validate JSON
        JSON.parse(freq_content)

        # Save frequency file
        freq_file = File.join(lang_path, "frequency.json")
        File.write(freq_file, freq_content)

        # Save metadata (with custom URL for Kelly)
        metadata = build_metadata(language, "kelly_frequency", checksum(freq_content))
        metadata[:url] = freq_url # Override with specific Kelly URL
        write_metadata(metadata_path_for(resource_id), metadata)

        {
          frequency_path: freq_file,
          cached: false,
          metadata: metadata
        }
      end

      private

      # LanguageCache serves from the kotoshu/dictionaries repo for spelling
      # and grammar; frequency lives in a separate repo (kelly). Pin the
      # manifest URL at the dictionaries repo since that's the primary
      # surface users see. Kelly's manifest can be added when that repo
      # ships one.
      def manifest_url
        @manifest_url || @source_registry.url_for(:dict_manifest)
      end

      # Download a specific resource (implements abstract method).
      #
      # @param resource_id [String] The resource identifier
      # @param dest_path [String] Destination directory
      # @return [Object] Downloaded resource
      def download_resource(resource_id, _dest_path)
        language = extract_language(resource_id)
        type = extract_type(resource_id)
        return nil unless language && type

        case type
        when "spelling" then download_spelling(language)
        when "grammar" then download_grammar(language)
        when "frequency" then download_frequency(language)
        else raise "Unknown resource type: #{type}"
        end
      end

      # Load cached resource data (implements abstract method).
      #
      # @param resource_id [String] The resource identifier
      # @return [Object, nil] Loaded resource or nil
      def load_cached(resource_id)
        parts = parse_resource_id(resource_id)
        return nil unless parts

        type = parts[1]
        metadata = load_metadata_for(resource_id)
        return nil unless metadata

        load_cached_resource_by_type(resource_id, type, metadata)
      end

      # Load metadata for a resource.
      #
      # @param resource_id [String] The resource identifier
      # @return [Hash, nil] Metadata or nil if not found
      def load_metadata_for(resource_id)
        metadata_path = metadata_path_for(resource_id)
        return nil unless File.exist?(metadata_path)

        read_metadata(metadata_path)
      end

      # Load cached resource by type.
      #
      # @param resource_id [String] The resource identifier
      # @param type [String] The resource type
      # @param metadata [Hash] The resource metadata
      # @return [Hash, nil] Loaded resource or nil
      def load_cached_resource_by_type(resource_id, type, metadata)
        case type
        when "spelling" then load_cached_spelling(resource_id, metadata)
        when "grammar" then load_cached_grammar(resource_id, metadata)
        when "frequency" then load_cached_frequency(resource_id, metadata)
        end
      end

      # Load cached spelling resource.
      #
      # @param resource_id [String] The resource identifier
      # @param metadata [Hash] The resource metadata
      # @return [Hash] Spelling resource data
      def load_cached_spelling(resource_id, metadata)
        lang_path = resource_dir_for(resource_id)
        {
          aff_path: File.join(lang_path, "index.aff"),
          dic_path: File.join(lang_path, "index.dic"),
          cached: true,
          metadata: metadata
        }
      end

      # Load cached grammar resource.
      #
      # @param resource_id [String] The resource identifier
      # @param metadata [Hash] The resource metadata
      # @return [Hash] Grammar resource data
      def load_cached_grammar(resource_id, metadata)
        lang_path = resource_dir_for(resource_id)
        {
          rules_path: lang_path,
          cached: true,
          metadata: metadata
        }
      end

      # Load cached frequency resource.
      #
      # @param resource_id [String] The resource identifier
      # @param metadata [Hash] The resource metadata
      # @return [Hash, nil] Frequency resource data or nil
      def load_cached_frequency(resource_id, metadata)
        # CommonWordsLoader autoloaded via Kotoshu::Data
        freq_file = File.join(resource_dir_for(resource_id), "frequency.json")
        return nil unless File.exist?(freq_file)

        data = Data::CommonWordsLoader.load_from_frequency_file(freq_file)
        {
          frequency_path: freq_file,
          tiers: data[:tiers],
          metadata: metadata
        }
      end

      # Build metadata hash for a resource.
      #
      # @param language [String] Language code
      # @param type [String] Resource type
      # @param content_checksum [String] SHA256 checksum of content
      # @return [Hash] Metadata hash
      def build_metadata(language, type, content_checksum)
        {
          version: Time.now.utc.iso8601,
          url: @url_base,
          language: language,
          type: type,
          checksum: content_checksum,
          cached_at: Time.now.utc.iso8601
        }
      end

      public

      # Get metadata file path for a resource.
      #
      # @param resource_id [String] The resource identifier
      # @return [String] Metadata file path
      def metadata_path_for(resource_id)
        language = extract_language(resource_id)
        type = extract_type(resource_id)
        File.join(language_path(language, type), "metadata.json")
      end

      # Get resource directory path.
      #
      # @param resource_id [String] The resource identifier
      # @return [String] Resource directory path
      def resource_dir_for(resource_id)
        language_path(extract_language(resource_id), extract_type(resource_id))
      end

      # Check if all resource files exist.
      #
      # @param resource_id [String] The resource identifier
      # @return [Boolean] True if all files exist
      def resource_files_exist?(resource_id)
        type = extract_type(resource_id)
        return false unless type

        lang_path = resource_dir_for(resource_id)

        case type
        when "spelling"
          File.exist?(File.join(lang_path, "index.aff")) &&
            File.exist?(File.join(lang_path, "index.dic"))
        when "grammar"
          File.exist?(File.join(lang_path, "rules.yaml"))
        when "frequency"
          File.exist?(File.join(lang_path, "frequency.json"))
        else
          false
        end
      end
    end
  end
end
