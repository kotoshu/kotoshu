# frozen_string_literal: true

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

        # Generate suggestions by delegating to all applicable strategies.
        #
        # Candidates are collected from every strategy first, then handed
        # to a single SuggestionSet so dedup and ranking run once over the
        # full pool (not as a side effect of each merge). TODO 56 T5.1.
        #
        # Strategies that declare themselves skippable by the confidence
        # cascade ({BaseStrategy#skip_when_confident?} — the semantic
        # rerank) run after the traditional ones and are skipped
        # entirely when the traditional pool already meets the
        # configured threshold ({SemanticCascade}). At the default
        # threshold (1.0, always rerank) the cascade is disarmed and
        # every strategy runs exactly as before.
        #
        # @param context [Context] The suggestion context
        # @return [SuggestionSet] Combined suggestions from all strategies
        def generate(context)
          cascade = semantic_cascade
          strategies = applicable_strategies(context)
          deferred = strategies.select(&:skip_when_confident?)

          if deferred.empty? || !cascade.armed?
            return generate_all(strategies, context)
          end

          traditional = strategies.reject(&:skip_when_confident?)
          pool = SuggestionSet.new(
            traditional.flat_map { |strategy| strategy.generate(context).suggestions },
            max_size: context.max_results
          )

          if cascade.skip?(pool.suggestions)
            record_cascade_skip(context, pool.first, cascade)
            return pool
          end

          pool.concat(deferred.flat_map { |strategy| strategy.generate(context).suggestions })
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
        def each_strategy(&)
          return enum_for(:each_strategy) unless block_given?

          @strategies.each(&)
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

        private

        # Run every strategy and merge into a single set — the
        # pre-cascade shape, byte-identical to the original pipeline.
        def generate_all(strategies, context)
          candidates = strategies.flat_map do |strategy|
            strategy.generate(context).suggestions
          end
          SuggestionSet.new(candidates, max_size: context.max_results)
        end

        # The cascade decision object. An explicit
        # +semantic_cascade_threshold+ in this composite's config wins;
        # otherwise the process Configuration applies (SCHEMA default
        # 1.0, KOTOSHU_SEMANTIC_CASCADE_THRESHOLD ENV).
        def semantic_cascade
          threshold = get_config(:semantic_cascade_threshold)
          if threshold.nil?
            SemanticCascade.from_configuration(Kotoshu.configuration)
          else
            SemanticCascade.new(threshold: threshold)
          end
        end

        # Count and (under debug/verbose) log a cascade skip.
        def record_cascade_skip(context, top, cascade)
          Kotoshu::Metrics.record_semantic_cascade_skip
          return unless Kotoshu::Debug.enabled?

          Kotoshu::Debug.logger&.verbose(
            "semantic cascade: skipped rerank for \"#{context.word}\" " \
            "(top confidence #{top.confidence.round(3)} >= #{cascade.threshold})"
          )
        end
      end
    end
  end
end
