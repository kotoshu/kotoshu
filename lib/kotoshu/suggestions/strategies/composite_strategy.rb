# frozen_string_literal: true

require_relative "base_strategy"

module Kotoshu
  module Suggestions
    module Strategies
      # Composite strategy that chains multiple suggestion strategies.
      # Implements the Composite Pattern for extensible suggestion generation.
      #
      # This is MORE OOP than Spylls which has a procedural suggestion pipeline.
      # Here, strategies are proper objects that can be added/removed/reordered.
      #
      # @example Using composite strategy
      #   pipeline = CompositeStrategy.new(name: :pipeline)
      #   pipeline.add(EditDistanceStrategy.new)
      #   pipeline.add(PhoneticStrategy.new)
      #   pipeline.add(NgramStrategy.new)
      #   suggestions = pipeline.generate(context)
      class CompositeStrategy < BaseStrategy
        attr_reader :strategies

        # @param name [String, Symbol] Name of the composite
        # @param strategies [Array<BaseStrategy>] Initial strategies
        # @param config [Hash] Configuration options
        def initialize(name:, strategies: [], **config)
          @strategies = strategies
          super(name: name, **config)
        end

        # Add a strategy to the pipeline.
        #
        # @param strategy [BaseStrategy] The strategy to add
        # @return [CompositeStrategy] Self for chaining
        def add(strategy)
          @strategies << strategy
          self
        end
        alias << add

        # Remove a strategy from the pipeline.
        #
        # @param strategy [BaseStrategy] The strategy to remove
        # @return [CompositeStrategy] Self for chaining
        def remove(strategy)
          @strategies.delete(strategy)
          self
        end

        # Clear all strategies.
        #
        # @return [CompositeStrategy] Self for chaining
        def clear
          @strategies.clear
          self
        end

        # Get strategies that can handle the given context.
        #
        # @param context [Context] The suggestion context
        # @return [Array<BaseStrategy>] Applicable strategies
        def applicable_strategies(context)
          @strategies.select { |s| s.handles?(context) }
        end

        # Generate suggestions by delegating to all child strategies.
        #
        # @param context [Context] The suggestion context
        # @return [SuggestionSet] Combined suggestions from all strategies
        def generate(context)
          # Create result set
          result = SuggestionSet.empty(max_size: context.max_results)

          # Process each applicable strategy
          applicable_strategies(context).each do |strategy|
            strategy_result = strategy.generate(context)
            result.merge!(strategy_result)
          end

          result
        end

        # Check if any strategy can handle the context.
        #
        # @param context [Context] The suggestion context
        # @return [Boolean] True if any strategy handles the context
        def handles?(context)
          applicable_strategies(context).any?
        end

        # Get the number of strategies.
        #
        # @return [Integer] Number of strategies
        def size
          @strategies.size
        end
        alias count size

        # Check if the composite has any strategies.
        #
        # @return [Boolean] True if there are strategies
        def any?
          @strategies.any?
        end

        # Iterate over strategies.
        #
        # @yield [strategy] Each strategy
        # @return [Enumerator] Enumerator if no block given
        def each_strategy(&block)
          return enum_for(:each_strategy) unless block_given?
          @strategies.each(&block)
        end

        # Sort strategies by priority.
        #
        # @return [CompositeStrategy] Self for chaining
        def sort_by_priority!
          @strategies.sort_by!(&:priority)
          self
        end

        # Convert to string.
        #
        # @return [String] String representation
        def to_s
          "#{self.class.name}(name: #{@name}, strategies: #{@strategies.map(&:name).join(', ')})"
        end
        alias inspect to_s

        # Create a composite strategy with default algorithms.
        #
        # @param config [Hash] Configuration
        # @return [CompositeStrategy] New composite with default strategies
        def self.with_defaults(**config)
          new(name: :default, **config)
        end
      end
    end
  end
end
