# frozen_string_literal: true

require_relative "plugin"

module Kotoshu
  module Plugins
    # Registry for managing plugins and their dependencies.
    #
    # @example Registering a plugin
    #   registry = Registry.new
    #   registry.register(:dictionary, MyDictionary)
    #   registry.register(:suggestions, MySuggestions)
    #
    # @example Creating an instance with DI
    #   suggestions = registry.create_instance(MySuggestions)
    class Registry
      # @return [Hash] Registered services
      attr_reader :services

      # @return [Hash] Registered plugins
      attr_reader :plugins

      # Create a new registry.
      def initialize
        @services = {}
        @plugins = {}
        @singletons = {}
      end

      # Register a service.
      #
      # @param name [Symbol] Service name
      # @param klass [Class] Service class or instance
      # @return [self] Self for chaining
      def register(name, klass)
        @services[name] = klass
        self
      end

      # Register a plugin.
      #
      # @param plugin [Class] Plugin class
      # @return [self] Self for chaining
      def register_plugin(plugin)
        @plugins[plugin.plugin_name] = plugin
        self
      end

      # Get a service instance.
      #
      # @param name [Symbol] Service name
      # @return [Object] Service instance
      def get_service(name)
        service = @services[name]

        raise DependencyError, "Unknown service: #{name}" unless service

        # Return singleton if already created
        return @singletons[name] if @singletons.key?(name)

        # Create new instance
        instance = service.is_a?(Class) ? service.new : service

        # Store singleton
        @singletons[name] = instance if service.is_a?(Class)
        instance
      end

      # Create an instance with dependency injection.
      #
      # @param klass [Class] Class to instantiate
      # @return [Object] Created instance
      def create_instance(klass)
        return klass.new unless klass.is_a?(Class)

        # Get dependencies if it's a Plugin
        if klass < Plugin
          dependencies = resolve_dependencies(klass)
          klass.new(**dependencies)
        else
          klass.new
        end
      rescue ArgumentError => e
        raise DependencyError, "Failed to create instance of #{klass}: #{e.message}"
      end

      # Check if a service is registered.
      #
      # @param name [Symbol] Service name
      # @return [Boolean] True if registered
      def registered?(name)
        @services.key?(name)
      end

      # Clear all singletons (force re-instantiation).
      #
      # @return [self] Self for chaining
      def clear_singletons
        @singletons.clear
        self
      end

      private

      # Resolve dependencies for a plugin.
      #
      # @param plugin [Class] Plugin class
      # @return [Hash] Keyword arguments for initialization
      def resolve_dependencies(plugin)
        deps = {}

        plugin.dependencies.each do |dep|
          deps[dep] = get_service(dep)
        end

        deps
      end
    end
  end
end
