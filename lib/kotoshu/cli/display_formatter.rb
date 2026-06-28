# frozen_string_literal: true

module Kotoshu
  module Cli
    # Formats output for interactive review mode.
    #
    # Provides methods to display errors, context, suggestions,
    # and navigation prompts in a user-friendly CLI format.
    #
    # @example Displaying an error
    #   formatter = DisplayFormatter.new(verbose: true)
    #   puts formatter.issue_screen(error, index: 1, total: 10)
    class DisplayFormatter
      # ANSI color codes for terminal output
      COLORS = {
        error: "\e[31m",      # Red
        warning: "\e[33m",    # Yellow
        success: "\e[32m",    # Green
        info: "\e[36m",       # Cyan
        dim: "\e[2m",         # Dim
        bold: "\e[1m",        # Bold
        reset: "\e[0m"        # Reset
      }.freeze

      # Confidence level indicators
      CONFIDENCE_LABELS = {
        high: '✓ High',
        medium: '~ Medium',
        low: '? Low'
      }.freeze

      attr_reader :verbose, :color_enabled

      # Create a new display formatter.
      #
      # @param verbose [Boolean] Enable verbose output
      # @param color_enabled [Boolean] Enable ANSI colors (default: true for TTY)
      def initialize(verbose: false, color_enabled: nil)
        @verbose = verbose
        @color_enabled = color_enabled.nil? ? $stdout.tty? : color_enabled
      end

      # Display summary screen for document review.
      #
      # Shows error breakdown by type and confidence, plus navigation hints.
      #
      # @param document [Document] The document being reviewed
      # @param navigation [NavigationManager] Navigation state
      # @return [String] Formatted summary screen
      def summary_screen(document, navigation)
        stats = navigation.statistics

        lines = []
        lines << ""
        lines << colorize("═══ Document Review Summary", :bold)
        lines << ""
        lines << "Document: #{document.name}"
        lines << "Format: #{Document::FORMATS[document.format]}"
        lines << "Language: #{document.language_code}"
        lines << ""
        lines << colorize("Error Summary", :bold)
        lines << ("─" * 40)

        # Total counts
        lines << "Total errors found: #{stats[:total]}"
        lines << "  • Pending: #{stats[:pending]}"
        lines << "  • Modified: #{stats[:modified]}"
        lines << "  • Skipped: #{stats[:skipped]}"
        lines << ""

        # Breakdown by type
        if stats[:by_type]&.any?
          lines << colorize("By Type", :bold)
          stats[:by_type].each do |type, count|
            label = SemanticError::ERROR_TYPES[type] || type.to_s.capitalize
            lines << "  • #{label}: #{count}"
          end
          lines << ""
        end

        # Breakdown by confidence
        if stats[:by_confidence]&.any?
          lines << colorize("By Confidence", :bold)
          lines << "  • High (>0.8): #{stats[:by_confidence][:high]}"
          lines << "  • Medium (0.5-0.8): #{stats[:by_confidence][:medium]}"
          lines << "  • Low (≤0.5): #{stats[:by_confidence][:low]}"
          lines << ""
        end

        # Navigation hints
        lines << colorize("Navigation", :bold)
        lines << "  [Enter] Next error    [s] Skip    [a] Accept suggestion"
        lines << "  [b] Back             [q] Quit    [l] List all errors"
        lines << "  [j] Jump to error    [h] Help    [?] Show this summary"
        lines << ""

        lines.join("\n")
      end

      # Display individual error screen.
      #
      # Shows the error with context, suggestions, and action prompt.
      #
      # @param error [SemanticError] The error to display
      # @param index [Integer] Current error index (1-based)
      # @param total [Integer] Total number of errors
      # @param show_context [Boolean] Show context window (default: true)
      # @return [String] Formatted error screen
      def issue_screen(error, index:, total:, show_context: true)
        lines = []
        lines << ""
        lines << colorize("═" * 70, :bold)
        lines << (colorize("Error #{index} of #{total}", :bold) + " — #{error_type_label(error.error_type)}")
        lines << colorize("═" * 70, :bold)
        lines << ""

        # Error location
        lines << (colorize("Location:", :bold) + " #{error.location}")
        lines << ""

        # Error with highlighting
        lines << (colorize("Found:", :error) + " #{highlight_in_context(error)}")
        lines << ""

        # Context window
        if show_context && error.context
          lines << colorize("Context:", :bold)
          lines << format_context(error.context)
          lines << ""
        end

        # Confidence indicator
        conf_label = confidence_label(error.confidence)
        lines << (colorize("Confidence:", :bold) + " #{conf_label} (#{(error.confidence * 100).round(1)}%)")
        lines << ""

        # Suggestions
        if error.suggestions&.any?
          lines << colorize("Suggestions:", :bold)
          lines << format_suggestions(error.suggestions)
          lines << ""
        end

        # Action prompt
        lines << (colorize("Actions:",
                           :bold) + " [Enter] Next [1-#{error.suggestions&.size || 0}] Accept [s] Skip [b] Back [q] Quit")
        lines << ""

        lines.join("\n")
      end

      # Highlight the error word within its context.
      #
      # @param error [SemanticError] The error to highlight
      # @return [String] Highlighted error with context
      def highlight_error(error)
        return error.original unless error.context

        ctx = error.context
        highlighted = ctx.current.gsub(/\b#{Regexp.escape(error.original)}\b/i) do |match|
          colorize(match, :error)
        end

        # Truncate if too long
        if highlighted.length > 100
          "..." + highlighted[-100..-1]
        else
          highlighted
        end
      end

      # Format suggestions list with confidence scores.
      #
      # @param suggestions [Array<Suggestion>] List of suggestions
      # @param max_display [Integer] Maximum suggestions to show (default: 5)
      # @return [String] Formatted suggestions
      def format_suggestions(suggestions, max_display: 5)
        return colorize("No suggestions", :dim) unless suggestions&.any?

        lines = []
        suggestions.first(max_display).each_with_index do |suggestion, idx|
          number = colorize((idx + 1).to_s + '.', :info)
          word = colorize(suggestion.word, suggestion.high_confidence? ? :success : :warning)
          confidence = "(#{(suggestion.confidence * 100).round(0)}%)"

          line = "  #{number} #{word} #{confidence}"
          line += " [#{suggestion.source}]" if suggestion.source && @verbose
          lines << line
        end

        if suggestions.size > max_display
          remaining = suggestions.size - max_display
          lines << colorize("  ... and #{remaining} more", :dim)
        end

        lines.join("\n")
      end

      # Display all errors with status indicators.
      #
      # @param navigation [NavigationManager] Navigation state
      # @return [String] Formatted error list
      def list_all_errors(navigation)
        lines = []
        lines << ""
        lines << colorize("All Errors (#{navigation.errors.size})", :bold)
        lines << ("─" * 70)

        navigation.list_all.each do |line|
          # Add color coding based on status
          colored_line = if line.include?('[DONE]')
                           colorize(line, :success)
                         elsif line.include?('[SKIP]')
                           colorize(line, :dim)
                         else
                           line
                         end
          lines << colored_line
        end

        lines << ""
        lines.join("\n")
      end

      # Display statistics summary.
      #
      # @param navigation [NavigationManager] Navigation state
      # @return [String] Formatted statistics
      def statistics(navigation)
        stats = navigation.statistics

        lines = []
        lines << ""
        lines << colorize("Review Statistics", :bold)
        lines << ("─" * 40)
        lines << "Total: #{stats[:total]}"
        lines << "Pending: #{stats[:pending]}"
        lines << colorize("Modified: #{stats[:modified]}", :success)
        lines << colorize("Skipped: #{stats[:skipped]}", :dim)
        lines << ""

        if stats[:by_type]&.any?
          lines << colorize("By Type:", :bold)
          stats[:by_type].each do |type, count|
            label = SemanticError::ERROR_TYPES[type] || type.to_s.capitalize
            lines << "  #{label}: #{count}"
          end
          lines << ""
        end

        lines.join("\n")
      end

      # Display help screen.
      #
      # @return [String] Formatted help text
      def help_screen
        lines = []
        lines << ""
        lines << colorize("═══ Interactive Review Help ═══", :bold)
        lines << ""
        lines << colorize("Navigation Commands:", :bold)
        lines << "  [Enter] or [n]    Move to next error"
        lines << "  [b]               Move to previous error"
        lines << "  [j] <number>      Jump to error by number"
        lines << "  [f]               Jump to first error"
        lines << "  [l]               Jump to last error"
        lines << ""
        lines << colorize("Error Actions:", :bold)
        lines << "  [1-9]             Accept suggestion by number"
        lines << "  [s]               Skip current error"
        lines << "  [e]               Edit custom replacement"
        lines << ""
        lines << colorize("Display Commands:", :bold)
        lines << "  [l]               List all errors with status"
        lines << "  [t]               Toggle show/hide context"
        lines << "  [v]               Toggle verbose mode"
        lines << "  [?]               Show this summary"
        lines << ""
        lines << colorize("Program Commands:", :bold)
        lines << "  [q]               Quit and save changes"
        lines << "  [Q]               Quit without saving"
        lines << "  [!]               Export corrections to file"
        lines << ""
        lines << colorize("Filter Commands:", :bold)
        lines << "  [c] <level>       Filter by confidence (high, medium, low)"
        lines << "  [y] <type>        Filter by error type"
        lines << "  [a]               Show all errors (clear filters)"
        lines << ""

        lines.join("\n")
      end

      # Display export summary.
      #
      # @param navigation [NavigationManager] Navigation state
      # @param export_path [String] Path to export file
      # @return [String] Formatted export summary
      def export_summary(navigation, export_path)
        corrections = navigation.export_corrections

        lines = []
        lines << ""
        lines << colorize("═══ Export Summary ═══", :bold)
        lines << ""
        lines << "Exported #{corrections.size} corrections to:"
        lines << colorize(export_path, :info)
        lines << ""

        if corrections.any? && @verbose
          lines << colorize("Corrections:", :bold)
          corrections.first(10).each do |corr|
            lines << "  Line #{corr[:line]}: #{corr[:original]} → #{corr[:replacement]}"
          end

          if corrections.size > 10
            lines << colorize("  ... and #{corrections.size - 10} more", :dim)
          end

          lines << ""
        end

        lines.join("\n")
      end

      # Format input prompt.
      #
      # @param text [String] Prompt text
      # @return [String] Formatted prompt
      def prompt(text)
        colorize("#{text} ", :info)
      end

      # Display warning message.
      #
      # @param message [String] Warning message
      # @return [String] Formatted warning
      def warning(message)
        colorize("Warning: #{message}", :warning)
      end

      # Display error message.
      #
      # @param message [String] Error message
      # @return [String] Formatted error
      def error(message)
        colorize("Error: #{message}", :error)
      end

      # Display success message.
      #
      # @param message [String] Success message
      # @return [String] Formatted success
      def success(message)
        colorize(message, :success)
      end

      private

      # Highlight error in context with visual markers.
      #
      # @param error [SemanticError] The error to highlight
      # @return [String] Error with context markers
      def highlight_in_context(error)
        # For now, just show the error word with color
        # In full implementation, would extract from context and add markers
        colorize(error.original, :error)
      end

      # Format context for display.
      #
      # @param context [Context] The context object
      # @return [String] Formatted context with line numbers
      def format_context(context)
        lines = []

        # Before context
        if context.before && !context.before.empty?
          lines << colorize(context.before.split("\n").last(2).join("\n"), :dim)
        end

        # Current line with marker
        current = "→ #{context.current}"
        lines << current

        # After context
        if context.after && !context.after.empty?
          lines << colorize(context.after.split("\n").first(2).join("\n"), :dim)
        end

        lines.join("\n")
      end

      # Get confidence label with indicator.
      #
      # @param confidence [Float] Confidence score (0.0 to 1.0)
      # @return [String] Confidence label
      def confidence_label(confidence)
        case confidence
        when 0.8..1.0 then colorize(CONFIDENCE_LABELS[:high], :success)
        when 0.5..0.8 then colorize(CONFIDENCE_LABELS[:medium], :warning)
        else colorize(CONFIDENCE_LABELS[:low], :dim)
        end
      end

      # Get human-readable error type label.
      #
      # @param error_type [Symbol] Error type symbol
      # @return [String] Human-readable label
      def error_type_label(error_type)
        SemanticError::ERROR_TYPES[error_type] || error_type.to_s.capitalize
      end

      # Apply color to text if colors are enabled.
      #
      # @param text [String] Text to colorize
      # @param color [Symbol] Color symbol
      # @return [String] Colorized text or original if colors disabled
      def colorize(text, color)
        return text unless @color_enabled

        code = COLORS[color]
        return text unless code

        "#{code}#{text}#{COLORS[:reset]}"
      end
    end
  end
end
