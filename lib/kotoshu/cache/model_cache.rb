# frozen_string_literal: true

# base_cache autoloaded via Kotoshu::Cache
require "zlib"
require "open-uri"
require "open3"

module Kotoshu
  module Cache
    # Manages embedding model downloads from FastText CDN and GitHub.
    #
    # Extends BaseCache to support FastText .vec files and ONNX models.
    # Downloads FastText models from Facebook's public CDN.
    #
    # @example Downloading a FastText model
    #   cache = ModelCache.new
    #   vec_file = cache.get_fasttext_model('en')
    #   model = FastTextModel.from_file(vec_file)
    #
    # @example Downloading an ONNX model
    #   onnx_file = cache.get_onnx_model('en')
    class ModelCache < BaseCache
      # Available models in FastText CDN and models-fasttext-onnx repository
      AVAILABLE_MODELS = {
        # FastText crawl vectors (300D) from Facebook Research
        # https://dl.fbaipublicfiles.com/fasttext/vectors-crawl/
        # Selected high-resource languages
        fasttext: {
          de: { file: "cc.de.300.vec.gz", size: 1_000_000, source: "FastText Common Crawl" },
          en: { file: "cc.en.300.vec.gz", size: 2_000_000, source: "FastText Common Crawl" },
          es: { file: "cc.es.300.vec.gz", size: 1_000_000, source: "FastText Common Crawl" },
          fr: { file: "cc.fr.300.vec.gz", size: 1_000_000, source: "FastText Common Crawl" },
          pt: { file: "cc.pt.300.vec.gz", size: 1_000_000, source: "FastText Common Crawl" },
          ru: { file: "cc.ru.300.vec.gz", size: 1_000_000, source: "FastText Common Crawl" }
        },
        # ONNX models (active set) from models-fasttext-onnx repository.
        # Sizes synced with manifest.json in kotoshu/models-fasttext-onnx.
        # The repo holds .onnx for 158 languages but only the 9 below are
        # tracked and exposed — to promote a language, see
        # models-fasttext-onnx/.gitignore and re-sync this constant.
        # https://github.com/kotoshu/models-fasttext-onnx
        onnx: {
          de: { file: "fasttext.de.onnx", size: 120_000_415, source: "models-fasttext-onnx" },
          en: { file: "fasttext.en.onnx", size: 120_000_415, source: "models-fasttext-onnx" },
          es: { file: "fasttext.es.onnx", size: 120_000_415, source: "models-fasttext-onnx" },
          fr: { file: "fasttext.fr.onnx", size: 120_000_415, source: "models-fasttext-onnx" },
          pt: { file: "fasttext.pt.onnx", size: 120_000_415, source: "models-fasttext-onnx" },
          ru: { file: "fasttext.ru.onnx", size: 120_000_415, source: "models-fasttext-onnx" },
          zh: { file: "fasttext.zh.onnx", size: 120_000_415, source: "models-fasttext-onnx" },
          ja: { file: "fasttext.ja.onnx", size: 120_000_415, source: "models-fasttext-onnx" },
          ko: { file: "fasttext.ko.onnx", size: 120_000_415, source: "models-fasttext-onnx" },
        }
      }.freeze

      # Model tiers published by kotoshu/models-fasttext-onnx (registry
      # ids `kotoshu://models/{lang}/{tier}`). `full` is today's layout
      # and behavior; `fluency` and `mini` are the tiered tiers resolved
      # through the registry (TODO.impl/67 M1).
      TIERS = %i[full fluency mini].freeze

      # First line of a Git LFS pointer stub — what raw.githubusercontent.com
      # serves for LFS-tracked files (*.onnx) instead of the object content.
      # Used to detect pointer-stub downloads/caches by content: the legacy
      # download path records the checksum of whatever it downloaded, so a
      # pointer stub passes checksum verification forever.
      LFS_POINTER_PREFIX = "version https://git-lfs.github.com/spec/v1"

      # Deterministic tier preference order, smallest footprint first.
      # This is NOT a fallback chain — tiers are never silently
      # substituted. It only fixes the ordering in which cached tiers
      # are reported (e.g. ambiguity errors from `tier: :any`), so
      # output is stable across machines and runs.
      TIER_PREFERENCE = %i[mini fluency full].freeze

      # Normalize and validate a tier name.
      #
      # @param tier [String, Symbol] "full", "fluency", or "mini"
      # @return [Symbol] the normalized tier symbol
      # @raise [ArgumentError] for any other value (covers config
      #   `model_tier` / `KOTOSHU_MODEL_TIER` and caller typos)
      def self.normalize_tier(tier)
        symbol = tier.to_s.downcase.strip.to_sym
        unless TIERS.include?(symbol)
          raise ArgumentError,
                "unknown model tier #{tier.inspect} (expected one of: #{TIERS.join(', ')})"
        end

        symbol
      end

      # Get or download FastText model for a language.
      #
      # @param language_code [String] ISO 639-1 language code
      # @param force_download [Boolean] Force re-download
      # @return [String, nil] Path to downloaded .vec file
      def get_fasttext_model(language_code, force_download: false)
        resource_id = "#{language_code}:fasttext"
        result = get(resource_id, force_download: force_download)

        result&.dig(:model_path)
      end

      # Get or download ONNX model for a language.
      #
      # @param language_code [String] ISO 639-1 language code
      # @param force_download [Boolean] Force re-download
      # @return [String, nil] Path to downloaded .onnx file
      def get_onnx_model(language_code, force_download: false)
        resource_id = "#{language_code}:onnx"
        result = get(resource_id, force_download: force_download)

        result&.dig(:model_path)
      end

      # ---- Tier-aware model resources (TODO.impl/67 M1) ----

      # Resource identifier for a (language, tier) model.
      #
      # The `full` tier maps to today's two-part id ("{lang}:onnx") and
      # therefore to today's on-disk layout — backwards compatible.
      # `fluency`/`mini` get a third path segment so tiers coexist:
      #
      #   models/{lang}/models/onnx/                # full (unchanged)
      #   models/{lang}/models/onnx/mini/           # mini
      #   models/{lang}/models/onnx/fluency/        # fluency
      #
      # @param language_code [String] ISO 639-1 language code
      # @param tier [String, Symbol] one of {TIERS}
      # @return [String] resource id ("en:onnx" or "en:onnx:mini")
      def tier_resource_id(language_code, tier)
        tier = self.class.normalize_tier(tier)
        lang = language_code.to_s
        tier == :full ? "#{lang}:onnx" : "#{lang}:onnx:#{tier}"
      end

      # Whether a resource id carries a tier segment ("{lang}:onnx:{tier}").
      #
      # @param resource_id [String] resource identifier
      # @return [Boolean] true for well-formed tiered ids
      def tiered_resource_id?(resource_id)
        parts = resource_id.to_s.split(":")
        return false unless parts.size == 3

        _lang, type, tier = parts
        type == "onnx" && TIERS.include?(tier.to_sym)
      end

      # Tier of a tiered resource id ("en:onnx:mini" -> :mini).
      # Returns nil for legacy two-part ids.
      #
      # @param resource_id [String] resource identifier
      # @return [Symbol, nil]
      def tier_from_resource_id(resource_id)
        return nil unless tiered_resource_id?(resource_id)

        resource_id.split(":")[2].to_sym
      end

      # Model tiers currently cached for a language (disk-only lookup;
      # never touches the network, so it is resolve-safe).
      #
      # The legacy layout (`{lang}/models/onnx/`) counts as :full.
      #
      # @param language_code [String] ISO 639-1 language code
      # @return [Array<Symbol>] cached tiers in {TIER_PREFERENCE} order
      def cached_tiers(language_code)
        lang = language_code.to_s
        onnx_dir = File.join(@cache_path, lang, "models", "onnx")
        TIER_PREFERENCE.select do |tier|
          dir = tier == :full ? onnx_dir : File.join(onnx_dir, tier.to_s)
          File.exist?(File.join(dir, "metadata.json"))
        end
      end

      # Look up the registry entry for a (language, tier) model.
      #
      # Reads the cached registry.json; downloads it once (per cache
      # instance) when absent or stale — unless offline mode is active,
      # in which case a stale cached copy is reused and a missing one
      # raises instead of ever hitting the network.
      #
      # @param language_code [String] ISO 639-1 language code
      # @param tier [String, Symbol] one of {TIERS}
      # @param force [Boolean] re-fetch the registry first
      # @return [ModelRegistry::Resource, nil] nil when the registry has
      #   no entry for the pair
      # @raise [Kotoshu::Error] when offline with no cached registry
      def registry_entry_for(language_code, tier, force: false)
        registry(force: force)&.find(language_code.to_s, tier.to_s)
      end

      # Download and verify a tiered model from the registry.
      #
      # Downloads `urls.primary`, falling back to `urls.mirror`, plus the
      # vocab sibling; verifies the model's SHA-256 against the registry
      # entry before accepting it into the cache. Unlike {#get}, download
      # failures and checksum mismatches RAISE rather than degrading to
      # nil — setup callers rely on that to report :unavailable.
      #
      # @param language_code [String] ISO 639-1 language code
      # @param tier [String, Symbol] "mini" or "fluency" (":full" is
      #   delegated to the legacy download path)
      # @param force_download [Boolean] re-fetch the registry first
      # @return [Hash] { model_path:, metadata:, vocab_path? }
      # @raise [Kotoshu::Error] no registry entry / offline without cache
      # @raise [Kotoshu::IntegrityError] SHA-256 mismatch (corrupt bytes
      #   are removed before raising)
      def download_tiered_model(language_code, tier:, force_download: false)
        tier = self.class.normalize_tier(tier)
        lang = language_code.to_s
        return get("#{lang}:onnx", force_download: force_download) if tier == :full

        entry = registry_entry_for(lang, tier, force: force_download)
        unless entry
          raise Kotoshu::Error,
                "no registry entry for #{ModelRegistry::Resource.id_for(lang, tier)}"
        end

        resource_id = tier_resource_id(lang, tier)
        dest_path = resource_dir_for(resource_id)
        FileUtils.mkdir_p(dest_path)

        filename = filename_from_url(entry.urls.primary)
        model_file = File.join(dest_path, filename)
        used_url = download_primary_or_mirror!(entry, model_file)

        verify_registry_sha256!(entry, model_file, resource_id, used_url)

        vocab_path = download_tiered_vocab(entry, dest_path)

        metadata = {
          version: entry.version,
          url: used_url,
          language: lang,
          type: "onnx",
          tier: tier.to_s,
          file: filename,
          checksum: entry.sha256,
          registry_id: ModelRegistry::Resource.id_for(lang, tier),
          size_bytes: entry.size_bytes,
          cached_at: Time.now.utc.iso8601,
          source: "registry"
        }
        write_metadata(File.join(dest_path, "metadata.json"), metadata)

        result = { model_path: model_file, metadata: metadata }
        result[:vocab_path] = vocab_path if vocab_path
        result
      end

      # Get available model types for a language.
      #
      # @param language_code [String] ISO 639-1 language code
      # @return [Array<Symbol>] Available model types (:fasttext, :onnx)
      def available_models_for(language_code)
        lang = language_code.to_sym
        types = []
        types << :fasttext if AVAILABLE_MODELS[:fasttext][lang]
        types << :onnx if AVAILABLE_MODELS[:onnx][lang]
        types
      end

      # Get model info for a language and type.
      #
      # @param language_code [String] ISO 639-1 language code
      # @param model_type [Symbol] Model type (:fasttext, :onnx)
      # @return [Hash, nil] Model info or nil if not available
      def model_info(language_code, model_type)
        AVAILABLE_MODELS.dig(model_type, language_code.to_sym)
      end

      # List all available models across all languages.
      #
      # @return [Hash] Mapping of language to available model types
      def all_available_models
        AVAILABLE_MODELS
      end

      # Check if a resource type is supported.
      #
      # @param resource_id [String] The resource identifier (e.g., "en:fasttext")
      # @return [Boolean] True if supported
      def supports_resource?(resource_id)
        return true if tiered_resource_id?(resource_id)

        parts = resource_id.split(":")
        return false unless parts.size == 2

        language, type = parts
        AVAILABLE_MODELS[type.to_sym]&.key?(language.to_sym)
      end

      # List all cached resources.
      #
      # Tiered entries appear as "{lang}:onnx:{tier}"; the registry
      # storage directory is not a model resource and is skipped.
      #
      # @return [Array<String>] List of cached resource identifiers
      def cached_resources
        Dir.glob(File.join(@cache_path, "**", "metadata.json")).filter_map do |path|
          relative = Pathname.new(path).relative_path_from(Pathname.new(@cache_path))
          parts = relative.to_s.split("/")
          next if parts.first == "registry" # registry storage, not a model

          case parts.length
          when 4 then "#{parts[0]}:#{parts[2]}" # lang/models/type/metadata.json (full)
          when 5 then "#{parts[0]}:#{parts[2]}:#{parts[3]}" # lang/models/type/tier/metadata.json
          end
        end.uniq
      end

      protected

      # Download a specific resource (implements abstract method).
      #
      # @param resource_id [String] The resource identifier
      # @param dest_path [String] Destination directory
      # @return [Hash] Downloaded model info
      def download_resource(resource_id, dest_path)
        if tiered_resource_id?(resource_id)
          download_tiered_model(extract_language(resource_id),
                                tier: tier_from_resource_id(resource_id))
        else
          download_legacy_resource(resource_id, dest_path)
        end
      end

      # Download a legacy (untiered) resource: FastText .vec or the
      # full-tier ONNX from the pinned git tree. This is today's
      # behavior, unchanged.
      #
      # @param resource_id [String] The resource identifier
      # @param dest_path [String] Destination directory
      # @return [Hash] Downloaded model info
      def download_legacy_resource(resource_id, dest_path)
        language = extract_language(resource_id)
        type = extract_type(resource_id)
        return nil unless language && type

        model_info = AVAILABLE_MODELS[type.to_sym][language.to_sym]
        return nil unless model_info

        FileUtils.mkdir_p(dest_path)

        filename = model_info[:file]

        # Handle ONNX with try-download-first approach
        if type == "onnx"
          download_or_convert_onnx(language, dest_path, filename)
        else
          # Handle FastText download (existing logic)
          url = model_url(language, type, filename)

          # Remove .gz extension for final storage (we decompress gzip files)
          final_filename = filename.sub('.gz', '')
          model_file = File.join(dest_path, final_filename)

          # Download (and decompress if needed)
          if url.end_with?('.gz')
            download_and_decompress(url, model_file)
          else
            download_file(url, model_file)
          end

          # Save metadata
          metadata = build_model_metadata(language, type, final_filename, url, model_file)
          write_metadata(File.join(dest_path, "metadata.json"), metadata)

          { model_path: model_file, metadata: metadata }
        end
      end

      # Load cached resource data (implements abstract method).
      #
      # Verifies the cached model file's SHA-256 against the checksum
      # recorded at download time. A mismatch — truncated file, disk
      # corruption, manual edit — raises {Kotoshu::IntegrityError} with
      # a remediation hint pointing at the cache subcommand, matching
      # the Phase C contract of TODO.impl/38-onnx-semantic-gating.md.
      # Caches written before checksums were recorded are accepted as
      # "unverified" (graceful degradation).
      #
      # @param resource_id [String] The resource identifier
      # @return [Hash, nil] Loaded model info
      # @raise [Kotoshu::IntegrityError] if the cached file's checksum
      #   does not match the recorded checksum
      def load_cached(resource_id)
        return load_tiered_cached(resource_id) if tiered_resource_id?(resource_id)

        language = extract_language(resource_id)
        type = extract_type(resource_id)
        return nil unless language && type

        model_info = AVAILABLE_MODELS[type.to_sym][language.to_sym]
        return nil unless model_info

        metadata_path = metadata_path_for(resource_id)
        return nil unless File.exist?(metadata_path)

        metadata = read_metadata(metadata_path)
        return nil unless metadata

        # For .gz files, the decompressed version is stored without .gz extension
        filename = model_info[:file].sub('.gz', '')
        model_file = File.join(resource_dir_for(resource_id), filename)

        return nil unless File.exist?(model_file)

        verify_cached_integrity!(resource_id, metadata, model_file)

        { model_path: model_file, metadata: metadata }
      end

      # Load a cached tiered model. The file recorded in metadata.json is
      # verified against the checksum recorded at download time (which,
      # for registry downloads, is the registry's sha256).
      #
      # @param resource_id [String] Tiered resource identifier
      # @return [Hash, nil] Loaded model info
      def load_tiered_cached(resource_id)
        metadata_path = metadata_path_for(resource_id)
        return nil unless File.exist?(metadata_path)

        metadata = read_metadata(metadata_path)
        return nil unless metadata

        model_file = File.join(resource_dir_for(resource_id), metadata["file"].to_s)
        return nil unless File.exist?(model_file) && File.size(model_file).positive?

        verify_cached_integrity!(resource_id, metadata, model_file)

        result = { model_path: model_file, metadata: metadata }
        vocab = File.join(resource_dir_for(resource_id), "fasttext.#{extract_language(resource_id)}.#{tier_from_resource_id(resource_id)}.vocab.json")
        result[:vocab_path] = vocab if File.exist?(vocab)
        result
      end

      # Get metadata file path for a resource.
      #
      # @param resource_id [String] The resource identifier
      # @return [String] Metadata file path
      def metadata_path_for(resource_id)
        File.join(resource_dir_for(resource_id), "metadata.json")
      end

      # Get resource directory path. Tiered ids nest under the onnx dir
      # (`{lang}/models/onnx/{tier}`); everything else keeps today's
      # layout (`{lang}/models/{type}`).
      #
      # @param resource_id [String] The resource identifier
      # @return [String] Resource directory path
      def resource_dir_for(resource_id)
        if tiered_resource_id?(resource_id)
          language, _type, tier = resource_id.split(":")
          return File.join(@cache_path, language, "models", "onnx", tier)
        end

        language = extract_language(resource_id)
        type = extract_type(resource_id)
        File.join(@cache_path, language, "models", type)
      end

      # Check if all resource files exist.
      #
      # @param resource_id [String] The resource identifier
      # @return [Boolean] True if all files exist
      def resource_files_exist?(resource_id)
        if tiered_resource_id?(resource_id)
          metadata = read_metadata(metadata_path_for(resource_id))
          return false unless metadata

          model_file = File.join(resource_dir_for(resource_id), metadata["file"].to_s)
          return File.exist?(model_file) && File.size(model_file).positive?
        end

        language = extract_language(resource_id)
        type = extract_type(resource_id)
        return false unless language && type

        model_info = AVAILABLE_MODELS[type.to_sym][language.to_sym]
        return false unless model_info

        # For .gz files, check the decompressed version
        filename = model_info[:file].sub('.gz', '')
        model_file = File.join(resource_dir_for(resource_id), filename)
        File.exist?(model_file) && File.size(model_file).positive?
      end

      private

      # Parse resource identifier into components. Tiered model ids
      # carry a third segment ("en:onnx:mini"); all others stay
      # two-part. Overridden from BaseCache so {#extract_language}
      # works for tiered ids.
      #
      # @param resource_id [String] The resource identifier
      # @return [Array<String>, nil] Array of parts or nil if invalid
      def parse_resource_id(resource_id)
        parts = resource_id.to_s.split(":")
        return nil unless [2, 3].include?(parts.size)

        parts
      end

      # ---- Registry storage ----
      #
      # registry.json is downloaded ONCE per cache instance (and reused
      # across setups while fresh). Its bytes are stored under the cache
      # dir with a metadata.json recording their own sha256, so a
      # corrupted or tampered registry is detected and re-fetched rather
      # than trusted. Offline mode (KOTOSHU_OFFLINE=1) never fetches:
      # a cached copy — even a stale one — is used, and a missing one
      # raises. Resolve never reaches this code at all (cache-only).

      # The parsed registry, fetched from cache or network at most once
      # per cache instance.
      #
      # @param force [Boolean] re-fetch even if a fresh copy is cached
      # @return [ModelRegistry]
      # @raise [Kotoshu::Error] offline with no cached registry
      def registry(force: false)
        return @registry = load_registry(force: true) if force

        @registry ||= load_registry(force: false)
      end

      def load_registry(force:)
        cached = force ? nil : read_cached_registry
        return cached if cached && !expired?(registry_metadata_path)

        if offline?
          return cached if cached

          raise Kotoshu::Error,
                "offline mode (KOTOSHU_OFFLINE=1) and no cached registry at " \
                "#{registry_path}; run once online or copy registry.json there"
        end

        fetch_registry
      end

      # Read and sha-verify the cached registry. Returns nil when the
      # bytes are absent, unparsable, or fail their recorded checksum.
      def read_cached_registry
        return nil unless File.exist?(registry_path) && File.exist?(registry_metadata_path)

        bytes = File.read(registry_path)
        metadata = read_metadata(registry_metadata_path)
        expected = metadata && metadata["sha256"]
        return nil unless expected
        return nil unless Digest::SHA256.hexdigest(bytes) == expected

        ModelRegistry.from_json(bytes)
      rescue StandardError
        nil
      end

      def fetch_registry
        url = @source_registry.url_for(:model_registry)
        bytes = Kotoshu::Integrity::NetHTTP.get(url)
        raise Kotoshu::Error, "registry not found at #{url}" if bytes.nil?

        begin
          model = ModelRegistry.from_json(bytes)
        rescue StandardError => e
          raise Kotoshu::IntegrityError.new(
            "registry.json",
            expected: "<valid registry JSON>",
            actual: "<parse error: #{e.message}>",
            url: url
          )
        end

        FileUtils.mkdir_p(File.dirname(registry_path))
        File.write(registry_path, bytes)
        write_metadata(registry_metadata_path,
                       "url" => url,
                       "sha256" => Digest::SHA256.hexdigest(bytes),
                       "cached_at" => Time.now.utc.iso8601)
        model
      end

      def registry_path
        File.join(@cache_path, "registry", "registry.json")
      end

      def registry_metadata_path
        File.join(@cache_path, "registry", "metadata.json")
      end

      def offline?
        Kotoshu.configuration.offline
      end

      # ---- Tiered download helpers ----

      # Download from urls.primary, falling back to urls.mirror. Partial
      # bytes from a failed attempt are removed first. Returns the URL
      # that succeeded; re-raises the last error when both fail.
      def download_primary_or_mirror!(entry, model_file)
        urls = [entry.urls.primary, entry.urls.mirror].compact.uniq
        last_error = nil
        urls.each do |url|
          File.delete(model_file) if File.exist?(model_file)
          download_file(url, model_file)
          return url
        rescue StandardError => e
          last_error = e
          warn "  download failed (#{url}): #{e.message}" if $VERBOSE
        end

        File.delete(model_file) if File.exist?(model_file)
        raise last_error
      end

      # Whether a file is a Git LFS pointer stub rather than real content.
      # Reads only the first line's prefix, so it stays cheap on 120MB models.
      def lfs_pointer?(path)
        File.open(path, "rb") do |f|
          f.read(LFS_POINTER_PREFIX.bytesize) == LFS_POINTER_PREFIX
        end
      rescue StandardError
        false
      end

      # Verify downloaded model bytes against the registry's sha256.
      # Corrupt bytes are removed from disk before raising so the next
      # attempt re-downloads (same contract as BaseCache#verify_and_audit).
      def verify_registry_sha256!(entry, model_file, resource_id, url)
        actual = Digest::SHA256.file(model_file).hexdigest
        if actual == entry.sha256
          @audit_log.record(
            url: url, status: "verified", size: File.size(model_file),
            sha256: actual, manifest_sha256: entry.sha256, resource_id: resource_id
          )
          return
        end

        @audit_log.record(
          url: url, status: "mismatch", size: File.size(model_file),
          sha256: actual, manifest_sha256: entry.sha256, resource_id: resource_id
        )
        File.delete(model_file)
        raise Kotoshu::IntegrityError.new(
          resource_id,
          expected: entry.sha256,
          actual: actual,
          url: url,
          remediation: "Run `kotoshu setup #{extract_language(resource_id)} --model` to re-download."
        )
      end

      # Pull the vocab sibling for a tiered model. Missing vocab is a
      # warning, not a failure (mirrors the legacy full-tier behavior).
      def download_tiered_vocab(entry, dest_path)
        return nil if entry.vocab_url.to_s.empty?

        vocab_file = File.join(dest_path, filename_from_url(entry.vocab_url))
        begin
          download_file(entry.vocab_url, vocab_file)
          vocab_file
        rescue StandardError => e
          warn "  vocab.json unavailable: #{e.message}" if $VERBOSE
          nil
        end
      end

      # Basename of a URL's path, e.g.
      # "https://h/fasttext.en.mini.onnx" => "fasttext.en.mini.onnx".
      def filename_from_url(url)
        File.basename(URI.parse(url.to_s).path)
      end

      # Verify a cached model file's SHA-256 against the checksum
      # recorded in its metadata. Raises {Kotoshu::IntegrityError} on
      # mismatch so the caller surfaces a clear, actionable error.
      # Caches written without a checksum field are accepted silently
      # to preserve backward compatibility with pre-verification caches.
      #
      # @param resource_id [String] The resource identifier (e.g. "en:onnx")
      # @param metadata [Hash] Parsed metadata.json (string keys)
      # @param model_file [String] Path to the cached model file
      # @return [void]
      # @raise [Kotoshu::IntegrityError] if checksums do not match
      #
      def verify_cached_integrity!(resource_id, metadata, model_file)
        if lfs_pointer?(model_file)
          # Content, not checksum, betrays the stub: the legacy download
          # path recorded the pointer's own sha256. Purge both files so
          # the next get re-downloads (same contract as the tiered path).
          File.delete(model_file)
          metadata_file = metadata_path_for(resource_id)
          File.delete(metadata_file) if File.exist?(metadata_file)
          raise Kotoshu::Error,
                "Integrity verification failed for #{resource_id}: cached model " \
                "#{File.basename(model_file)} is a Git LFS pointer stub, not " \
                "model content (raw.githubusercontent.com serves pointer stubs " \
                "for LFS-tracked .onnx files). Run " \
                "`kotoshu cache download :#{extract_language(resource_id)} --model` to re-download."
        end

        expected = metadata["checksum"]
        return unless expected

        actual = Digest::SHA256.file(model_file).hexdigest
        return if actual == expected

        remediation = "Run `kotoshu cache download :#{extract_language(resource_id)} --model` to re-download."
        raise Kotoshu::IntegrityError.new(
          resource_id,
          expected: expected,
          actual: actual,
          url: metadata["url"],
          remediation: remediation
        )
      end

      # Build metadata hash for a model.
      #
      # @param language [String] Language code
      # @param type [String] Model type
      # @param filename [String] Model filename
      # @param url [String] Download URL
      # @param model_file [String] Path to downloaded model file
      # @return [Hash] Metadata hash
      def build_model_metadata(language, type, filename, url, model_file)
        {
          version: Time.now.utc.iso8601,
          url: url,
          language: language,
          type: type,
          file: filename,
          checksum: Digest::SHA256.file(model_file).hexdigest,
          cached_at: Time.now.utc.iso8601
        }
      end

      # Get URL for a model file.
      #
      # @param language [String] Language code
      # @param type [String] Model type
      # @param filename [String] Model filename
      # @return [String, nil] Download URL
      def model_url(language, type, filename)
        case type
        when "fasttext"
          # Download from FastText CDN (Facebook Research)
          # https://fasttext.cc/docs/en/english-vectors.html
          "https://dl.fbaipublicfiles.com/fasttext/vectors-crawl/#{filename}"
        when "onnx"
          # Download from models-fasttext-onnx GitHub repository.
          # SourceRegistry owns the per-repo pin so we never accidentally
          # fall back to the dictionaries pin.
          @source_registry.url_for(:model, lang: language)
        else
          "#{@url_base}/dictionaries/main/#{language}/models/#{type}/#{filename}"
        end
      end

      # URL for the vocab.json sibling file. The conversion script ships
      # vocabularies alongside the .onnx so OnnxModel.from_file can resolve
      # word→index without re-parsing the FastText .vec.
      #
      # @param language [String] Language code
      # @return [String]
      def vocab_url(language)
        @source_registry.url_for(:model_vocab, lang: language)
      end

      # Download and decompress gzip file.
      #
      # @param url [String] URL to gzip file
      # @param dest_path [String] Destination path (without .gz)
      def download_and_decompress(url, dest_path)
        # Download to temporary file first
        temp_gz = "#{dest_path}.gz"

        puts "  Downloading from #{url.split('/').last}..." if $VERBOSE

        downloaded_bytes = 0
        URI.open(url, open_timeout: 30, read_timeout: 300) do |uri|
          File.open(temp_gz, 'wb') do |f|
            downloaded_bytes = f.write(uri.read)
          end
        end

        puts "  Downloaded: #{(downloaded_bytes.to_f / 1024 / 1024).round(2)} MB" if $VERBOSE

        # Verify the download succeeded
        unless File.exist?(temp_gz) && File.size(temp_gz).positive?
          raise "Download failed: #{temp_gz} is empty or missing"
        end

        puts "  Decompressing..." if $VERBOSE

        # Remove existing file if present (handles partial downloads)
        File.delete(dest_path) if File.exist?(dest_path)

        # Decompress gzip with streaming
        File.open(temp_gz, 'rb') do |gz_file|
          Zlib::GzipReader.wrap(gz_file) do |gzip|
            # Stream in chunks to avoid memory issues with large files
            File.open(dest_path, 'wb') do |out_file|
              chunk_size = 65_536 # 64KB chunks
              while (chunk = gzip.read(chunk_size))
                out_file.write(chunk)
                # Print progress every 10MB
                if $VERBOSE && out_file.pos % (10 * 1024 * 1024) < chunk_size
                  puts "    Decompressed: #{(out_file.pos.to_f / 1024 / 1024).round(1)} MB..."
                end
              end
            end
          end
        end

        # Verify the decompression succeeded
        unless File.exist?(dest_path) && File.size(dest_path).positive?
          raise "Decompression failed: #{dest_path} is empty or missing"
        end

        # Clean up gz file
        File.delete(temp_gz)

        puts "  ✓ Downloaded and decompressed" if $VERBOSE
      end

      # Convert FastText .vec file to ONNX format.
      #
      # @param language [String] Language code
      # @param dest_path [String] Destination directory
      # @param onnx_filename [String] Output ONNX filename
      # @return [Hash] Converted model info
      def convert_to_onnx(language, dest_path, onnx_filename)
        puts "Converting FastText to ONNX for #{language}..." if $VERBOSE

        # First, ensure we have the FastText .vec file
        fasttext_resource_id = "#{language}:fasttext"
        fasttext_result = get(fasttext_resource_id, force_download: false)

        unless fasttext_result
          raise "Failed to get FastText model for #{language} needed for ONNX conversion"
        end

        vec_file = fasttext_result[:model_path]

        # Verify the .vec file exists
        unless File.exist?(vec_file)
          raise "FastText .vec file not found: #{vec_file}"
        end

        # Output ONNX file path
        onnx_file = File.join(dest_path, onnx_filename)

        # Get the conversion script path
        script_path = File.expand_path('../scripts/fasttext_to_onnx.py', __dir__)

        unless File.exist?(script_path)
          raise "ONNX conversion script not found: #{script_path}"
        end

        # Build conversion command
        # Use --vocab-size to limit vocabulary size and reduce conversion time
        vocab_size = fasttext_result.dig(:metadata, "vocab_size")&.to_i || 100_000

        cmd = [
          'python3',
          script_path,
          vec_file,
          onnx_file,
          '--vocab-size', vocab_size.to_s
        ]

        puts "  Running conversion: #{shell_join(cmd)}" if $VERBOSE

        # Run conversion
        require 'open3'
        stdout, stderr, status = Open3.capture3(*cmd)

        unless status.success?
          raise "ONNX conversion failed:\n#{stdout}\n#{stderr}"
        end

        puts stdout if $VERBOSE

        # Build metadata for the ONNX file
        metadata = {
          version: Time.now.utc.iso8601,
          url: "converted:#{vec_file}",
          language: language,
          type: "onnx",
          file: onnx_filename,
          checksum: Digest::SHA256.file(onnx_file).hexdigest,
          cached_at: Time.now.utc.iso8601,
          source_model: File.basename(vec_file),
          conversion_method: "fasttext_to_onnx.py"
        }

        # Save metadata
        write_metadata(File.join(dest_path, "metadata.json"), metadata)

        puts "  ✓ ONNX conversion complete" if $VERBOSE

        { model_path: onnx_file, metadata: metadata }
      end

      # Try to download ONNX from GitHub, fall back to conversion if download fails.
      #
      # @param language [String] Language code
      # @param dest_path [String] Destination directory
      # @param onnx_filename [String] ONNX filename
      # @return [Hash] Downloaded or converted model info
      def download_or_convert_onnx(language, dest_path, onnx_filename)
        url = model_url(language, "onnx", onnx_filename)
        onnx_file = File.join(dest_path, onnx_filename)

        puts "  Attempting download from GitHub..." if $VERBOSE

        # Try downloading from GitHub first
        begin
          download_file(url, onnx_file)

          # Verify the downloaded file
          unless File.exist?(onnx_file) && File.size(onnx_file).positive?
            raise "Download failed: empty file"
          end

          # raw.githubusercontent.com serves LFS pointer stubs for
          # LFS-tracked .onnx files; refuse one so the fallback path runs
          # instead of poisoning the cache with a stub.
          if lfs_pointer?(onnx_file)
            raise "downloaded a Git LFS pointer stub instead of model bytes from #{url}"
          end

          # Pull the matching vocab.json so OnnxModel.from_file can resolve
          # word→index without re-parsing the source FastText .vec.
          begin
            download_file(vocab_url(language),
                          File.join(dest_path, "fasttext.#{language}.vocab.json"))
          rescue StandardError => e
            warn "  vocab.json unavailable for #{language}: #{e.message}" if $VERBOSE
          end

          puts "  ✓ Downloaded from GitHub" if $VERBOSE

          # Build metadata for downloaded file
          metadata = {
            version: Time.now.utc.iso8601,
            url: url,
            language: language,
            type: "onnx",
            file: onnx_filename,
            checksum: Digest::SHA256.file(onnx_file).hexdigest,
            cached_at: Time.now.utc.iso8601,
            source: "github"
          }

          # Save metadata
          write_metadata(File.join(dest_path, "metadata.json"), metadata)

          { model_path: onnx_file, metadata: metadata }
        rescue StandardError => e
          puts "  GitHub download failed: #{e.message}" if $VERBOSE
          puts "  Falling back to local conversion..." if $VERBOSE

          # Remove partial download if any
          File.delete(onnx_file) if File.exist?(onnx_file)

          # Fall back to local conversion
          convert_to_onnx(language, dest_path, onnx_filename)
        end
      end

      # Join shell command arguments safely (for display purposes).
      #
      # @param args [Array<String>] Command arguments
      # @return [String] Joined command string
      def shell_join(args)
        args.map { |a| /\s/.match?(a) ? "'#{a}'" : a }.join(' ')
      end

      # Default cache path: $XDG_CACHE_HOME/kotoshu/models
      #
      # @return [String] Default cache path
      def default_cache_path
        File.join(Kotoshu::Paths.cache_path, "models")
      end

      # Default cache TTL (30 days for models).
      #
      # @return [Integer] Default TTL in seconds
      def default_cache_ttl
        2_592_000 # 30 days
      end
    end
  end
end
