# frozen_string_literal: true

module Kotoshu
  module Cli
    # Pure data model describing what the `kotoshu status` command reports.
    #
    # Knows nothing about presentation — the CLI command formats it as
    # text or JSON. Construction is split from presentation so both
    # outputs share one source of truth (MECE).
    class StatusReport
      ResourceStatus = Struct.new(:language, :resource, :available, :size_bytes, :cached_at, keyword_init: true)

      attr_reader :version, :languages_setup, :resources, :cache_path,
                  :cache_size_bytes, :audit_log_path, :audit_log_size_bytes,
                  :onnx_loaded, :default_language, :offline

      def initialize(version:, languages_setup:, resources:, cache_path:, cache_size_bytes:,
                     audit_log_path:, audit_log_size_bytes:, onnx_loaded:, default_language:, offline:)
        @version = version
        @languages_setup = languages_setup
        @resources = resources
        @cache_path = cache_path
        @cache_size_bytes = cache_size_bytes
        @audit_log_path = audit_log_path
        @audit_log_size_bytes = audit_log_size_bytes
        @onnx_loaded = onnx_loaded
        @default_language = default_language
        @offline = offline
      end

      def languages_with_model
        resources.select { |r| r.resource == :model && r.available }.map(&:language).uniq.sort
      end

      # Probe the live system and produce a report. Each collaborator is
      # injectable for tests; defaults pull from the live configuration.
      def self.build(version:, resource_manager: Kotoshu::ResourceManager,
                     paths: Kotoshu::Paths, configuration: Kotoshu.configuration,
                     onnx_loaded: Kotoshu::Models::OnnxModel::ONNX_LOADED)
        langs = resource_manager.languages_setup
        cache_path = paths.cache_path
        cache_size = directory_size(cache_path)
        audit = audit_info(paths.audit_log_path)

        new(
          version: version,
          languages_setup: langs,
          resources: langs.flat_map { |lang| statuses_for(lang, resource_manager, cache_path) },
          cache_path: cache_path,
          cache_size_bytes: cache_size,
          audit_log_path: audit[:path],
          audit_log_size_bytes: audit[:size],
          onnx_loaded: onnx_loaded,
          default_language: configuration.default_language,
          offline: configuration.offline
        )
      end

      # Sum every regular file's size under `dir`. Returns 0 if missing.
      def self.directory_size(dir)
        return 0 unless File.directory?(dir)

        Dir.glob(File.join(dir, "**", "*"))
          .select { |path| File.file?(path) }
          .sum { |path| File.size(path) }
      end

      # Human-readable byte format (KB / MB / GB).
      # @param bytes [Integer, nil]
      # @return [String]
      def self.format_bytes(bytes)
        return "0 B" if bytes.nil? || bytes.zero?

        units = %w[B KB MB GB TB]
        size = bytes.to_f
        i = 0
        while size >= 1024 && i < units.length - 1
          size /= 1024
          i += 1
        end
        template = i.zero? ? "%.0f" : "%.1f"
        "#{template % size} #{units[i]}"
      end

      class << self
        private

        def statuses_for(lang, rm, cache_root)
          %i[spelling frequency model].map do |res|
            available = rm.setup?(lang, resource: res)
            ResourceStatus.new(
              language: lang,
              resource: res,
              available: available,
              size_bytes: available ? resource_size(cache_root, lang, res) : nil,
              cached_at: available ? resource_mtime(cache_root, lang, res) : nil
            )
          end
        end

        def resource_size(cache_root, lang, resource)
          dir = resource_dir(cache_root, lang, resource)
          directory_size(dir)
        end

        def resource_mtime(cache_root, lang, resource)
          dir = resource_dir(cache_root, lang, resource)
          paths = Dir.glob(File.join(dir, "**", "*")).select { |p| File.file?(p) }
          return nil if paths.empty?

          paths.map { |p| File.mtime(p) }.max
        end

        def resource_dir(cache_root, lang, resource)
          case resource
          when :spelling then File.join(cache_root, "languages", lang, "spelling")
          when :frequency then File.join(cache_root, "frequency-lists", lang)
          when :model then File.join(cache_root, "models", lang)
          end
        end

        def audit_info(path)
          return { path: nil, size: nil } unless File.exist?(path)

          { path: path, size: File.size(path) }
        end
      end
    end
  end
end
