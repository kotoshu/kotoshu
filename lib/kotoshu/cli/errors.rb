# frozen_string_literal: true

require "thor"

module Kotoshu
  module Cli
    # Semantic error classes for the CLI. Subclass Thor::Error so the CLI's
    # top-level dispatcher can catch them and exit with the appropriate code.
    # Each class carries an `exit_status` that the dispatcher reads.
    module Errors
      # Base class for all CLI errors. Carries an exit_status.
      class CliError < Thor::Error
        attr_reader :exit_status

        def initialize(message, exit_status:)
          super(message)
          @exit_status = exit_status
        end
      end

      # Usage error: bad flags, missing argument, file not found (exit 2).
      class UsageError < CliError
        def initialize(message)
          super(message, exit_status: 2)
        end
      end

      # Resource unavailable: network down, offline+uncached, integrity failure (exit 3).
      class ResourceUnavailable < CliError
        def initialize(message)
          super(message, exit_status: 3)
        end
      end
    end
  end
end
