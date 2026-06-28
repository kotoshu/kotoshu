# frozen_string_literal: true

module Kotoshu
  class Configuration
    # Canon-style resolver for configuration values.
    #
    # Implements the priority order: CLI > ENV > Programmatic > Defaults
    #
    # This ensures that:
    # 1. CLI arguments have highest priority (explicit user intent)
    # 2. Environment variables override programmatic settings
    # 3. Programmatic/API settings override defaults
    # 4. Defaults are the fallback
    #
    # @example
    #   resolver = Configuration::Resolver.new(
    #     env: { "KOTOSHU_LANGUAGE" => "de" },
    #     programmatic: { language: "en-US" },
    #     cli: { language: "ja" },
    #     defaults: { language: "en-US" }
    #   )
    #
    #   resolver.get(:language)  # => "ja" (CLI wins)
    #
    class Resolver
      # @return [Hash] Environment variable overrides
      attr_reader :env

      # @return [Hash] Programmatic/API settings
      attr_reader :programmatic

      # @return [Hash] CLI argument settings
      attr_reader :cli

      # @return [Hash] Default values
      attr_reader :defaults

      # Create a new resolver.
      #
      # @param env [Hash] Environment variables (e.g., { "KOTOSHU_LANGUAGE" => "de" })
      # @param programmatic [Hash] Programmatic settings (e.g., { language: "en-US" })
      # @param cli [Hash] CLI argument settings (e.g., { language: "ja" })
      # @param defaults [Hash] Default values (e.g., { language: "en-US" })
      def initialize(env: {}, programmatic: {}, cli: {}, defaults: {})
        @env = env
        @programmatic = programmatic
        @cli = cli
        @defaults = defaults
      end

      # Resolve a configuration value using priority order.
      #
      # Priority: CLI > ENV > Programmatic > Defaults
      #
      # @param key [Symbol] The configuration key (e.g., :language)
      # @return [Object] The resolved value
      #
      # @example
      #   resolver.get(:language)  # => resolved language value
      def get(key)
        # CLI has highest priority when explicitly set
        return @cli[key] if @cli.key?(key)

        # Environment variables override programmatic
        env_key = env_key_for(key)
        return ENV[env_key] if ENV.key?(env_key)

        # Programmatic settings override defaults
        return @programmatic[key] if @programmatic.key?(key)

        @defaults[key]
      end

      # Check if a key has a value set at any priority level.
      #
      # @param key [Symbol] The configuration key
      # @return [Boolean] True if the key is set somewhere
      def key?(key)
        @cli.key?(key) ||
          ENV.key?(env_key_for(key)) ||
          @programmatic.key?(key) ||
          @defaults.key?(key)
      end

      # Get all values for a key across all priority levels.
      #
      # @param key [Symbol] The configuration key
      # @return [Hash] Hash with priority levels as keys
      def get_all(key)
        {
          cli: @cli[key],
          env: ENV.fetch(env_key_for(key), nil),
          programmatic: @programmatic[key],
          default: @defaults[key]
        }
      end

      # Create a new resolver with merged values.
      #
      # @param env [Hash] Additional environment overrides
      # @param programmatic [Hash] Additional programmatic settings
      # @param cli [Hash] Additional CLI settings
      # @return [Resolver] New resolver with merged values
      def merge(env: {}, programmatic: {}, cli: {})
        self.class.new(
          env: @env.merge(env),
          programmatic: @programmatic.merge(programmatic),
          cli: @cli.merge(cli),
          defaults: @defaults
        )
      end

      private

      # Convert configuration key to environment variable name.
      #
      # @param key [Symbol] The configuration key (e.g., :language)
      # @return [String] The env var name (e.g., "KOTOSHU_LANGUAGE")
      def env_key_for(key)
        "KOTOSHU_#{key.to_s.upcase}"
      end
    end
  end
end
