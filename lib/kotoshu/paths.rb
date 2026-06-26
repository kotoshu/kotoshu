# frozen_string_literal: true

require "fileutils"

module Kotoshu
  # Centralized XDG Base Directory paths.
  #
  # Resolves cache, config, and data paths per the XDG Base Directory
  # Specification. Kotoshu-specific env vars (KOTOSHU_CACHE_PATH etc.)
  # take precedence over the generic XDG_*_HOME vars, which take
  # precedence over the hardcoded defaults.
  #
  # Default layout:
  #   ~/.cache/kotoshu/         downloaded dicts, models, frequency lists
  #   ~/.config/kotoshu/        user-edited config, personal dictionary
  #   ~/.local/share/kotoshu/   append-only data (audit log)
  module Paths
    class << self
      def cache_path
        ENV.fetch("KOTOSHU_CACHE_PATH", nil) || xdg("CACHE", "cache")
      end

      def config_path
        ENV.fetch("KOTOSHU_CONFIG_PATH", nil) || xdg("CONFIG", "config")
      end

      def data_path
        ENV.fetch("KOTOSHU_DATA_PATH", nil) || xdg("DATA", "local/share")
      end

      def audit_log_path
        ENV.fetch("KOTOSHU_AUDIT_LOG", nil) || File.join(data_path, "audit.log")
      end

      def personal_dictionary_path
        ENV.fetch("KOTOSHU_PERSONAL_DIC", nil) || File.join(config_path, "personal.dic")
      end

      def ensure_exist!
        FileUtils.mkdir_p(cache_path)
        FileUtils.mkdir_p(config_path)
        FileUtils.mkdir_p(data_path)
      end

      private

      def xdg(suffix, default_subdir)
        base = ENV.fetch("XDG_#{suffix}_HOME", nil) || File.join(Dir.home, ".#{default_subdir}")
        File.join(base, "kotoshu")
      end
    end
  end
end
