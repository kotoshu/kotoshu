# frozen_string_literal: true

module Kotoshu
  module Plugins
    # Base class for plugins.
    #
    # Plugins provide extensible functionality with dependency injection.
    #
    # @example Creating a plugin
    #   class MyPlugin < Kotoshu::Plugins::Plugin
    #     def self.plugin_name
    #       :my_plugin
    #     end
    #
    #     def self.dependencies
    #       [:dictionary]
    #     end
    #
    #     def self.provides
    #       [:suggestions]
    #     end
    #
    #     def initialize(dictionary:)
    #       @dictionary = dictionary
    #     end
    #   end
    class Plugin
      # @return [Symbol] Plugin name
      def self.plugin_name
        raise NotImplementedError, "#{name} must define .plugin_name"
      end

      # @return [Array<Symbol>] Dependencies
      def self.dependencies
        []
      end

      # @return [Array<Symbol>] Provided services
      def self.provides
        []
      end

      # Lifecycle hook called before plugin starts.
      #
      # Override in subclass to add startup logic.
      def before_start
        # Override in subclass
      end

      # Lifecycle hook called after plugin stops.
      #
      # Override in subclass to add cleanup logic.
      def after_stop
        # Override in subclass
      end
    end

    # Error raised when a dependency cannot be resolved.
    class DependencyError < StandardError; end
  end
end
