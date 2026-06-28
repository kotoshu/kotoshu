# frozen_string_literal: true

require_relative 'navigation_manager'
require_relative 'display_formatter'
require_relative '../analyzers/semantic_analyzer'

module Kotoshu
  module Cli
    # Interactive review session for spell/grammar checking.
    #
    # Provides a user-friendly terminal interface for reviewing errors
    # with full navigation support (forward, backward, jump, skip, accept).
    #
    # @example Starting an interactive session
    #   reviewer = InteractiveReviewer.new(document, analyzer)
    #   reviewer.run  # Enters interactive loop
    #
    # @example Batch mode (non-interactive)
    #   reviewer = InteractiveReviewer.new(document, analyzer)
    #   reporter = reviewer.run_batch  # Returns BatchReporter
    class InteractiveReviewer
      attr_reader :document, :analyzer, :navigation, :formatter

      # Create a new interactive reviewer.
      #
      # @param document [Object] Document to review (responds to #content)
      # @param analyzer [Analyzers::SemanticAnalyzer] Error analyzer
      # @param formatter [DisplayFormatter, nil] Display formatter (default: new instance)
      def initialize(document, analyzer, formatter: nil)
        raise ArgumentError, "Document required" unless document
        raise ArgumentError, "Analyzer required" unless analyzer

        @document = document
        @analyzer = analyzer

        # Analyze document for errors
        errors = @analyzer.analyze(@document)

        # Create navigation manager
        @navigation = NavigationManager.new(errors)

        # Create display formatter
        @formatter = formatter || DisplayFormatter.new

        @running = false
        @show_context = true
      end

      # Run the interactive review loop.
      #
      # @return [Hash] Session summary with statistics
      def run
        @running = true

        # Show welcome message
        show_welcome

        # Show summary screen
        puts @formatter.summary_screen(@document, @navigation)

        # Main interactive loop
        while @running && @navigation.current
          show_current_error
          process_input(get_user_input)
        end

        # Show exit message
        show_exit_summary

        # Return session summary
        session_summary
      end

      # Run in batch mode (non-interactive).
      #
      # @return [BatchReporter] Reporter with results
      def run_batch
        # Analyze all errors without user interaction
        errors = @navigation.errors

        # Apply all high-confidence corrections automatically
        errors.each do |error|
          if error.high_confidence? && error.suggestions&.any?
            @navigation.accept_suggestion(error.recommended_suggestion)
          end
        end

        # Return batch reporter
        require_relative 'batch_reporter'
        BatchReporter.new(@document, @navigation, @formatter)
      end

      # Check if session has errors.
      #
      # @return [Boolean] True if there are errors to review
      def has_errors?
        @navigation.errors.any?
      end

      # Get session statistics.
      #
      # @return [Hash] Statistics hash
      def statistics
        @navigation.statistics
      end

      private

      # Show welcome message.
      def show_welcome
        puts ""
        puts @formatter.colorize("╔═══════════════════════════════════════════════════════════════╗", :bold)
        puts @formatter.colorize("║           Kotoshu Interactive Spell/Grammar Review          ║", :bold)
        puts @formatter.colorize("╚═══════════════════════════════════════════════════════════════╝", :bold)
        puts ""
        puts "Document: #{@document.name}"
        puts "Language: #{@document.language_code}"
        puts "Errors found: #{@navigation.errors.size}"
        puts ""
        puts "Type 'h' for help, 'q' to quit"
        puts ""
      end

      # Show current error screen.
      def show_current_error
        error = @navigation.current
        return unless error

        index = @navigation.current_index + 1
        total = @navigation.errors.size

        puts @formatter.issue_screen(error, index: index, total: total, show_context: @show_context)
      end

      # Get user input from terminal.
      #
      # @return [String] User input
      def get_user_input
        print @formatter.prompt("Action>")
        $stdin.gets&.chomp || 'q'
      end

      # Process user input command.
      #
      # @param input [String] User input
      def process_input(input)
        return if input.nil? || input.empty?

        case input
        when '', 'n', 'enter'
          # Move to next error
          @navigation.forward

        when 'b', 'back'
          # Move to previous error
          @navigation.backward

        when 's', 'skip'
          # Skip current error
          @navigation.skip_current

        when /^(\d+)$/
          # Accept suggestion by number
          suggestion_number = $1.to_i - 1 # Convert to 0-based index
          accept_suggestion_by_number(suggestion_number)

        when 'j', 'jump'
          # Jump to error
          jump_to_error

        when 'f', 'first'
          @navigation.first

        when 'l', 'last'
          @navigation.last

        when 'l', 'list'
          # List all errors
          puts @formatter.list_all_errors(@navigation)
          puts @formatter.prompt("Press Enter to continue...")
          $stdin.gets

        when 't', 'toggle'
          # Toggle context display
          @show_context = !@show_context

        when 'v', 'verbose'
          # Toggle verbose mode
          @formatter.verbose = !@formatter.verbose
          puts @formatter.success("Verbose mode: #{@formatter.verbose ? 'ON' : 'OFF'}")

        when '?'
          # Show summary
          puts @formatter.summary_screen(@document, @navigation)

        when 'h', 'help'
          # Show help
          puts @formatter.help_screen
          puts @formatter.prompt("Press Enter to continue...")
          $stdin.gets

        when 'q', 'quit'
          # Quit and save
          quit_with_save

        when 'Q', 'QUIT'
          # Quit without saving
          quit_without_save

        when '!', 'export'
          # Export corrections
          export_corrections

        else
          # Unknown command
          puts @formatter.warning("Unknown command: #{input}. Type 'h' for help.")
        end
      end

      # Accept suggestion by number.
      #
      # @param number [Integer] Suggestion number (0-based)
      def accept_suggestion_by_number(number)
        error = @navigation.current
        return unless error

        suggestions = error.suggestions || []
        if number < 0 || number >= suggestions.size
          puts @formatter.warning("Invalid suggestion number: #{number + 1}")
          return
        end

        suggestion = suggestions[number]
        @navigation.accept_suggestion(suggestion)
        puts @formatter.success("Accepted: #{error.original} → #{suggestion.word}")
      end

      # Jump to specific error.
      def jump_to_error
        print @formatter.prompt("Jump to error number>")
        input = $stdin.gets&.chomp

        return unless input

        number = input.to_i - 1 # Convert to 0-based
        if number >= 0 && number < @navigation.errors.size
          @navigation.jump_to(number)
        else
          puts @formatter.warning("Invalid error number: #{input}")
        end
      end

      # Quit and save changes.
      def quit_with_save
        @running = false
        puts @formatter.success("Changes saved!")
      end

      # Quit without saving.
      def quit_without_save
        @running = false
        puts @formatter.warning("Quit without saving. No changes were made.")
      end

      # Export corrections to file.
      def export_corrections
        print @formatter.prompt("Export to file (default: corrections.json)>")
        filepath = $stdin.gets&.chomp || 'corrections.json'

        # Export corrections
        corrections = @navigation.export_corrections

        # Write to file
        require 'json'
        File.write(filepath, JSON.pretty_generate(corrections))

        puts @formatter.export_summary(@navigation, filepath)
        puts @formatter.prompt("Press Enter to continue...")
        $stdin.gets
      end

      # Show exit summary.
      def show_exit_summary
        puts ""
        puts @formatter.statistics(@navigation)
        puts ""

        if @navigation.modified.any?
          puts @formatter.success("#{@navigation.modified.size} corrections applied")
        end

        if @navigation.skipped.any?
          puts "#{@navigation.skipped.size} errors skipped"
        end

        pending = @navigation.errors.size - @navigation.modified.size - @navigation.skipped.size
        if pending > 0
          puts "#{pending} errors remaining"
        end
      end

      # Get session summary.
      #
      # @return [Hash] Session summary
      def session_summary
        {
          document: {
            name: @document.name,
            format: @document.format,
            language: @document.language_code
          },
          statistics: @navigation.statistics,
          corrections: @navigation.export_corrections,
          history: @navigation.history_summary
        }
      end
    end
  end
end
