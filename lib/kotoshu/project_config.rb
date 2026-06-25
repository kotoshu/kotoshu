# frozen_string_literal: true

module Kotoshu
  # Project configuration for .kotoshu file.
  #
  # Auto-discovers .kotoshu file by searching up directory tree.
  class ProjectConfig
    CONFIG_FILE = ".kotoshu"

    class << self
      # Load project config for given path.
      #
      # @param start_path [String] Starting directory
      # @return [Hash, nil] Configuration hash or nil
      def load(start_path = Dir.pwd)
        path = find_config_file(start_path)
        return nil unless path

        parse_config_file(path)
      end

      # Check if project config exists.
      #
      # @param start_path [String] Starting directory
      # @return [Boolean] True if config exists
      def exists?(start_path = Dir.pwd)
        !find_config_file(start_path).nil?
      end

      # Get ignore patterns from project config.
      #
      # @param start_path [String] Starting directory
      # @return [Hash] Configuration with ignore patterns
      def ignore_patterns(start_path = Dir.pwd)
        config = load(start_path) || {}
        {
          words: config["ignore_words"] || [],
          patterns: (config["ignore_patterns"] || []).map { |p| Regexp.new(p) }
        }
      end

      private

      # Find .kotoshu file by searching up directory tree.
      #
      # @param start_path [String] Starting directory
      # @return [String, nil] Path to config file or nil
      def find_config_file(start_path)
        path = Pathname.new(start_path)

        while path
          config_file = path.join(CONFIG_FILE)
          return config_file.to_s if config_file.file?

          parent = path.parent
          break if parent == path # Reached root

          path = parent
        end

        nil
      end

      # Parse .kotoshu YAML file.
      #
      # @param path [String] Path to config file
      # @return [Hash] Parsed configuration
      def parse_config_file(path)
        require "yaml"
        YAML.load_file(path) || {}
      rescue ArgumentError, Psych::SyntaxError
        {}
      end
    end
  end
end
