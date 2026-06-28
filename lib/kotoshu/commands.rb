# frozen_string_literal: true

module Kotoshu
  # Thor-based CLI command classes (cache, model, check).
  # These are the wired-up commands; cli.rb is the dispatcher.
  module Commands
    # Note: lib/kotoshu/commands/cache_command.rb defines Kotoshu::CacheCommand
    # at the top level (historical), not Kotoshu::Commands::CacheCommand.
    autoload :CheckCommand, "kotoshu/commands/check_command"
    autoload :ModelCommand, "kotoshu/commands/model_command"
  end
end
