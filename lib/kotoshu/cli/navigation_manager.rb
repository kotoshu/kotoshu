# frozen_string_literal: true

module Kotoshu
  module Cli
    # Manages navigation through errors in interactive review mode.
    #
    # Tracks current position, user decisions, and provides filtering
    # for efficient error review.
    #
    # @example Creating navigation for errors
    #   nav = NavigationManager.new(errors)
    #   nav.forward  # Move to next error
    #   nav.accept_suggestion(error.suggestions.first)
    class NavigationManager
      attr_reader :errors, :current_index, :history, :skipped, :modified

      # Create a new navigation manager.
      #
      # @param errors [Array<Models::SemanticError>] Sorted list of errors
      def initialize(errors)
        raise ArgumentError, "Errors cannot be nil" if errors.nil?
        raise ArgumentError, "Errors must be an Array" unless errors.is_a?(Array)

        @errors = errors.sort # Errors are Comparable
        @current_index = 0
        @history = []
        @skipped = Set.new
        @modified = Set.new
        @filters = {}
      end

      # Get the current error.
      #
      # @return [Models::SemanticError, nil] Current error or nil
      def current
        return nil if @current_index >= @errors.size

        @errors[@current_index]
      end

      # Check if there's a next error.
      #
      # @return [Boolean] True if there's a next error
      def next?
        @current_index < @errors.size - 1
      end

      # Check if there's a previous error.
      #
      # @return [Boolean] True if there's a previous error
      def previous?
        @current_index > 0
      end

      # Navigation methods

      # Move to next error.
      #
      # @return [Models::SemanticError, nil] Next error or nil
      def forward
        return nil unless next?

        @current_index += 1
        current
      end

      # Move to previous error.
      #
      # @return [Models::SemanticError, nil] Previous error or nil
      def backward
        return nil unless previous?

        @current_index -= 1
        current
      end

      # Jump to specific error by index.
      #
      # @param index [Integer] Error index (0-based)
      # @return [Models::SemanticError, nil] Error at index or nil
      def jump_to(index)
        return nil if index < 0 || index >= @errors.size

        @current_index = index
        current
      end

      # Jump to first error.
      #
      # @return [Models::SemanticError, nil] First error or nil
      def first
        jump_to(0)
      end

      # Jump to last error.
      #
      # @return [Models::SemanticError, nil] Last error or nil
      def last
        jump_to(@errors.size - 1)
      end

      # Skip the current error.
      #
      # @return [Models::SemanticError, nil] Next error or nil
      def skip_current
        @skipped.add(@current_index)
        forward
      end

      # Accept a suggestion for the current error.
      #
      # Records the decision and marks the error as modified.
      #
      # @param suggestion [Models::Suggestion] The suggestion to accept
      # @return [Models::SemanticError, nil] Next error or nil
      def accept_suggestion(suggestion)
        error = current
        return nil unless error

        record_decision(
          error_id: error.id,
          action: :accept,
          original: error.original,
          replacement: suggestion.word,
          confidence: error.confidence
        )

        @modified.add(@current_index)
        forward
      end

      # List all errors with their status.
      #
      # @return [Array<String>] Formatted error list
      def list_all
        @errors.each_with_index.map do |error, idx|
          status = status_for(idx)
          "#{idx + 1}. #{status} #{error.abbreviated}"
        end
      end

      # Filter errors by minimum confidence.
      #
      # @param min_confidence [Float] Minimum confidence threshold (0.0 to 1.0)
      # @return [Array<Models::SemanticError>] Filtered errors
      def filter_by_confidence(min_confidence: 0.0)
        @errors.select { |e| e.confidence >= min_confidence }
      end

      # Filter errors by type(s).
      #
      # @param types [Array<Symbol>] Error types to include
      # @return [Array<Models::SemanticError>] Filtered errors
      def filter_by_type(*types)
        @errors.select { |e| types.include?(e.error_type) }
      end

      # Get only pending errors (not skipped or modified).
      #
      # @return [Array<Models::SemanticError>] Pending errors
      def pending
        @errors.each_with_index.reject do |_, idx|
          @skipped.include?(idx) || @modified.include?(idx)
        end.map(&:last)
      end

      # Get statistics about the errors.
      #
      # @return [Hash] Statistics hash
      def statistics
        {
          total: @errors.size,
          skipped: @skipped.size,
          modified: @modified.size,
          pending: pending.size,
          by_type: @errors.group_by(&:error_type).transform_values(&:size),
          by_confidence: {
            high: @errors.count(&:high_confidence?),
            medium: @errors.count { |e| e.confidence > 0.5 && e.confidence <= 0.8 },
            low: @errors.count { |e| e.confidence <= 0.5 }
          }
        }
      end

      # Get all errors sorted by status (pending first).
      #
      # @return [Array<Models::SemanticError>] Errors sorted by status
      def by_status
        pending + @errors.each_with_index.select { |_, idx|
          @modified.include?(idx)
        }.map(&:last).reverse + @errors.each_with_index.select { |_, idx|
          @skipped.include?(idx)
        }.map(&:last).reverse
      end

      # Reset navigation state (clear all decisions).
      #
      # @return [void]
      def reset
        @current_index = 0
        @history.clear
        @skipped.clear
        @modified.clear
      end

      # Export corrections as a list of changes.
      #
      # @return [Array<Hash>] List of correction changes
      def export_corrections
        @modified.to_a.sort.map do |idx|
          error = @errors[idx]
          suggestion = error.recommended_suggestion

          {
            line: error.location.line,
            original: error.original,
            replacement: suggestion.word,
            error_type: error.error_type,
            confidence: error.confidence
          }
        end
      end

      # Get user decision history.
      #
      # @return [Array<Hash>] List of decisions made
      def history_summary
        @history.map.with_index.map do |decision, idx|
          {
            id: idx + 1,
            error_id: decision[:error_id],
            action: decision[:action],
            original: decision[:original],
            replacement: decision[:replacement],
            confidence: decision[:confidence],
            timestamp: decision[:timestamp]
          }
        end
      end

      private

      # Record a user decision.
      #
      # @param error_id [String] Error identifier
      # @param action [Symbol] Action taken (:accept, :skip, :edit)
      # @param original [String] Original text
      # @param replacement [String] Replacement text
      # @param confidence [Float] Confidence score
      def record_decision(error_id:, action:, original:, replacement:, confidence:)
        @history << {
          error_id: error_id,
          action: action,
          original: original,
          replacement: replacement,
          confidence: confidence,
          timestamp: Time.now
        }
      end

      # Get status string for an error index.
      #
      # @param idx [Integer] Error index
      # @return [String] Status string
      def status_for(idx)
        return "[DONE]" if @modified.include?(idx)
        return "[SKIP]" if @skipped.include?(idx)

        "[PENDING]"
      end
    end
  end
end
