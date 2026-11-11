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
        #
        # SymSpellStrategy is the ranking authority (frequency full_list
        # + distance, plan C6). Its slate leads; EditDistance fills the
        # rest. Hunspell junk (compound-split artifacts) never appears
        # in SymSpell's pool so the order is junk-free by construction.
        def generate_all(strategies, context)
          # SymSpell leads when configured (frequency full_list + distance
          # ranking, plan C6). When absent, fall back to the legacy
          # merged-and-ranked behavior.
          order = strategies.index do |s|
            s.class.name.end_with?("SymSpellStrategy") && s.frequency_ranked?
          end

          if order.nil?
            candidates = strategies.flat_map { |s| s.generate(context).suggestions }
            return SuggestionSet.new(candidates, max_size: context.max_results)
          end

          primary = strategies[order]
          tail = strategies[0...order] + strategies[(order + 1)..-1]
          primary_slate = primary ? primary.generate(context).suggestions : []
          # The primary slate leads verbatim (its order is the product
          # decision); the tail may only FILL remaining slots, so a tail
          # row for a word the slate already carries is dropped — the
          # zh-Hant-HK wave-2 probe showed edit_distance/phonetic
          # echoes of primary entries consuming half the limit
          # (['資產','資產','資產'] under a 5-suggestion limit).
          typed = context.word
          seen = primary_slate.map { |s| s.word.downcase }.to_set
          tail_slate = tail.flat_map { |s| s.generate(context).suggestions }
            .select { |s| seen.add?(s.word.downcase) }
          # The input word itself is never a suggestion: tail
          # strategies can echo it (StubStrategy/spec, phonetic
          # echoes), and the band sort would rank its true-dist-0
          # first.
          merged = (primary_slate + tail_slate)
            .reject { |s| s.word.casecmp?(typed) }
          # Distance-band merge with slate precedence: within each edit
          # distance the primary slate's (pattern, confusion, rank)
          # order stays authoritative, and tail entries — including
          # correct answers the compact frequency list missed
          # ("ommitted" -> "omitted" lost to slate-entry "committed")
          # — join at the END of their own distance band, ahead of the
          # NEXT distance. A full re-rank by combined_score is wrong
          # here: each strategy normalizes confidence inside its own
          # pool, so the scales are not comparable across strategies
          # (measured 87.5 -> 63.3 top-1 when they were mixed).
          slate_size = primary_slate.size
          typed = context.word
          ordered = merged.each_with_index.sort_by do |(s, i)|
            # TRUE edit distance recomputed per candidate: tail
            # strategies self-report distances on their own scales
            # (phonetic emits 0/1), so the Suggestion#distance of a
            # merged pool is not comparable across origins.
            true_dist = Algorithms::EditDistance.distance_with_threshold(
              typed, s.word, 3
            ) || 9
            # Band order: (1) true distance, (2) the corpus's dominant
            # single-edit class (missing/extra double letter), (3) the
            # channel op class — a dropped/extra keystroke explains the
            # typo better than a far-key substitution, so tail entries
            # the compact frequency list missed ("containing" for
            # "containg") interleave at the right position.
            # Morph candidates are lookup-verified inflections of the
            # typed stem ("trys"->"tries", "containg"->"containing"):
            # they form their own channel class between the
            # double-letter fix and plain edits — within a distance
            # band a verified inflection of the typed stem outranks
            # unrelated words of the same edit class, slate or tail.
            [true_dist,
             Patterns.double_letter_fix?(typed, s.word) ? 0 : 1,
             s.metadata[:morph] ? 1 : Patterns.single_edit_op(typed, s.word),
             i < slate_size ? 0 : 1, i]
          end.map(&:first)
          SuggestionSet.new(ordered, max_size: context.max_results, ranked: true)
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

require "set" if RUBY_VERSION < "3.0"
