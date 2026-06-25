# frozen_string_literal: true

module Kotoshu
  module Suggestions
    # Pipeline for composable suggestion strategies.
    #
    # Allows chaining multiple suggestion strategies that execute in sequence,
    # with optional early termination when a stage produces no results.
    #
    # @example Creating a pipeline
    #   pipeline = Pipeline.new do |p|
    #     p.add :sym_spell
    #     p.add :phonetic
    #     p.add :ngram
    #   end
    #
    # @example Executing a pipeline
    #   result = pipeline.execute(context, strategies)
    class Pipeline
      # @return [Array<Symbol>] Ordered stage names
      attr_reader :stages

      # Create a new pipeline.
      #
      # @yield [pipeline] Optional block to add stages
      # @return [Pipeline] New pipeline
      #
      # @example With block
      #   pipeline = Pipeline.new do |p|
      #     p.add :sym_spell
      #     p.add :phonetic
      #   end
      def initialize
        @stages = []
        yield self if block_given?
      end

      # Add a stage to the pipeline.
      #
      # @param stage_name [Symbol] Name of the stage
      # @return [Pipeline] Self for chaining
      #
      # @example
      #   pipeline.add(:sym_spell)
      def add(stage_name)
        @stages << stage_name
        self
      end

      # Remove a stage from the pipeline.
      #
      # @param stage_name [Symbol] Name of the stage to remove
      # @return [Pipeline] Self for chaining
      #
      # @example
      #   pipeline.remove(:phonetic)
      def remove(stage_name)
        @stages.delete(stage_name)
        self
      end

      # Execute strategies through the pipeline.
      #
      # Strategies are executed in sequence. If a strategy returns
      # an empty SuggestionSet, subsequent strategies are still executed
      # unless early_termination is enabled.
      #
      # @param context [Context] The suggestion context
      # @param strategies [Hash] Hash of stage_name => strategy_instance
      # @param early_termination [Boolean] Whether to stop on empty result
      # @return [SuggestionSet] Combined results from all stages
      #
      # @example
      #   strategies = { sym_spell: sym_spell_strategy, phonetic: phonetic_strategy }
      #   result = pipeline.execute(context, strategies)
      def execute(context, strategies = nil, early_termination: false)
        combined = SuggestionSet.empty

        @stages.each do |stage_name|
          strategy = if strategies.is_a?(Hash)
                       strategies[stage_name]
                     else
                       strategies
                     end

          next unless strategy

          result = strategy.generate(context)

          # Combine results
          combined = combine_results(combined, result)

          # Early termination on empty result
          break if early_termination && result.empty?
        end

        combined
      end

      # Check if pipeline has a stage.
      #
      # @param stage_name [Symbol] Stage name
      # @return [Boolean] True if stage exists
      def has_stage?(stage_name)
        @stages.include?(stage_name)
      end

      # Clear all stages.
      #
      # @return [Pipeline] Self for chaining
      def clear
        @stages.clear
        self
      end

      # Clone the pipeline.
      #
      # @return [Pipeline] New pipeline with same stages
      def clone
        self.class.new.tap { |p| @stages.each { |s| p.add(s) } }
      end

      private

      # Combine two suggestion sets.
      #
      # @param combined [SuggestionSet] Current combined results
      # @param new_result [SuggestionSet] New results to add
      # @return [SuggestionSet] Combined suggestion set
      def combine_results(combined, new_result)
        combined.concat(new_result.suggestions).unique
      end
    end
  end
end
