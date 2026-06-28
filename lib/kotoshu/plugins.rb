# frozen_string_literal: true

module Kotoshu
  # Plugin system for extending Kotoshu (document parsers, custom strategies, etc.).
  module Plugins
    autoload :Plugin, "kotoshu/plugins/plugin"
    autoload :Registry, "kotoshu/plugins/registry"
  end
end
