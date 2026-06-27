# frozen_string_literal: true

require "io/console"

module Kotoshu
  module Cli
    # Interactive prompt that wraps the strict two-stage setup/resolve flow
    # for the human-facing CLI.
    #
    # The library API (`Kotoshu.correct?`, `Kotoshu.suggest`) still raises
    # `ResourceNotSetupError` strictly — no surprise downloads on metered
    # networks. This class catches that error in the CLI dispatcher, asks
    # the user once, and retries the original command. Programmatic users
    # never see it.
    #
    # Non-TTY contexts (pipes, CI) and offline mode never prompt. The caller
    # decides how to surface a nil result — the CLI dispatcher raises
    # Errors::ResourceUnavailable so scripts see stable exit codes.
    class AutoSetup
      # @param input [IO] Stdin (or override for tests)
      # @param output [IO] Stderr (or override for tests)
      def initialize(input: $stdin, output: $stderr)
        @input = input
        @output = output
      end

      # Prompt the user to set up the missing language.
      #
      # @param error [Kotoshu::ResourceNotSetupError] The error raised by resolve
      # @param want [Array<Symbol>] Resource types to fetch (default [:spelling])
      # @return [String, nil] Language code on success; nil when non-TTY,
      #   offline, or user declined.
      def call(error, want: %i[spelling])
        language = error.language
        return nil if skip_prompt?

        @output.puts prompt_message(language, error.resource_type, want)
        answer = @input.gets&.strip&.downcase
        return nil unless affirmative?(answer)

        Kotoshu.setup(language, want: want)
        language
      end

      private

      def skip_prompt?
        Kotoshu.configuration.offline || !@input.tty?
      end

      def prompt_message(language, resource, want)
        size_hint = size_hint_for(want)
        "Language '#{language}' is not set up (missing #{resource}).\n" \
          "Download now (~#{size_hint} from github.com/kotoshu/dictionaries)? [Y/n]"
      end

      def size_hint_for(want)
        case want
        when %i[spelling] then "5 MB"
        when %i[spelling frequency] then "6 MB"
        when %i[spelling frequency model] then "120 MB"
        else "unknown size"
        end
      end

      def affirmative?(answer)
        answer.nil? || answer.empty? || answer.start_with?("y")
      end
    end
  end
end
