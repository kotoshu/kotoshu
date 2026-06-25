# frozen_string_literal: true

require_relative "../../../lib/kotoshu/plugins/plugin"
require_relative "../../../lib/kotoshu/plugins/registry"

RSpec.describe Kotoshu::Plugins::Plugin do
  describe "plugin definition" do
    it "has a plugin name" do
      plugin = Class.new(described_class) do
        def self.plugin_name
          :test_plugin
        end
      end

      expect(plugin.plugin_name).to eq(:test_plugin)
    end

    it "has dependencies" do
      plugin = Class.new(described_class) do
        def self.dependencies
          [:dictionary]
        end
      end

      expect(plugin.dependencies).to eq([:dictionary])
    end

    it "has provided services" do
      plugin = Class.new(described_class) do
        def self.provides
          [:suggestions]
        end
      end

      expect(plugin.provides).to eq([:suggestions])
    end
  end

  describe "dependency injection" do
    let(:registry) { Kotoshu::Plugins::Registry.new }

    it "resolves dependencies with keyword arguments" do
      # Register mock dictionary class
      mock_dict_class = Class.new do
        def initialize; end
      end
      registry.register(:dictionary, mock_dict_class)

      # Define plugin that inherits from Plugin
      plugin = Class.new(Kotoshu::Plugins::Plugin) do
        def self.dependencies
          [:dictionary]
        end

        def initialize(dictionary:)
          @dictionary = dictionary
        end
      end

      instance = registry.create_instance(plugin)
      expect(instance).to be_a(plugin)
    end
  end

  describe "lifecycle hooks" do
    it "calls before_start hook" do
      plugin = Class.new(described_class) do
        attr_accessor :started

        def before_start
          @started = true
        end
      end

      instance = plugin.new
      instance.before_start
      expect(instance.started).to be true
    end

    it "calls after_stop hook" do
      plugin = Class.new(described_class) do
        attr_accessor :stopped

        def after_stop
          @stopped = true
        end
      end

      instance = plugin.new
      instance.after_stop
      expect(instance.stopped).to be true
    end
  end
end
