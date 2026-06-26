# frozen_string_literal: true

require_relative "base_cache"
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
        parts = resource_id.split(":")
        return false unless parts.size == 2

        language, type = parts
        AVAILABLE_MODELS[type.to_sym]&.key?(language.to_sym)
      end

      # List all cached resources.
      #
      # @return [Array<String>] List of cached resource identifiers
      def cached_resources
        Dir.glob(File.join(@cache_path, "**", "metadata.json")).map do |path|
          relative = Pathname.new(path).relative_path_to(Pathname.new(@cache_path))
          parts = relative.to_s.split("/")
          "#{parts[0]}:#{parts[2]}" # language:model_type
        end.uniq
      end

      protected

      # Download a specific resource (implements abstract method).
      #
      # @param resource_id [String] The resource identifier
      # @param dest_path [String] Destination directory
      # @return [Hash] Downloaded model info
      def download_resource(resource_id, dest_path)
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
      # @param resource_id [String] The resource identifier
      # @return [Hash, nil] Loaded model info
      def load_cached(resource_id)
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

        { model_path: model_file, metadata: metadata }
      end

      # Get metadata file path for a resource.
      #
      # @param resource_id [String] The resource identifier
      # @return [String] Metadata file path
      def metadata_path_for(resource_id)
        language = extract_language(resource_id)
        type = extract_type(resource_id)
        File.join(@cache_path, language, "models", type, "metadata.json")
      end

      # Get resource directory path.
      #
      # @param resource_id [String] The resource identifier
      # @return [String] Resource directory path
      def resource_dir_for(resource_id)
        language = extract_language(resource_id)
        type = extract_type(resource_id)
        File.join(@cache_path, language, "models", type)
      end

      # Check if all resource files exist.
      #
      # @param resource_id [String] The resource identifier
      # @return [Boolean] True if all files exist
      def resource_files_exist?(resource_id)
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
          # Download from models-fasttext-onnx GitHub repository
          # Files are at: models-fasttext-onnx/{pin}/models/{lang}/{filename}
          "#{models_url_base}/models/#{language}/#{filename}"
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
        "#{models_url_base}/models/#{language}/fasttext.#{language}.vocab.json"
      end

      def models_url_base
        @models_url_base ||= begin
          cfg = Kotoshu::Configuration.instance
          "#{cfg.models_url.chomp('/').sub(%r{/main\z}, '')}/#{cfg.models_pin}"
        end
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
        args.map { |a| a =~ /\s/ ? "'#{a}'" : a }.join(' ')
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
