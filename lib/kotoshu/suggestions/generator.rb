# frozen_string_literal: true

module Kotoshu
  module Suggestions
    # Generator for spelling suggestions.
    #
    # This class orchestrates multiple suggestion algorithms to generate
    # comprehensive spelling suggestions.
    #
    # @example Using default algorithms
    #   generator = Generator.new(dictionary)
    #   suggestions = generator.generate("helo")
    #
    # @example Using custom algorithms
    #   custom_strategy = MyStrategy.new
    #   generator = Generator.new(dictionary, algorithms: [custom_strategy])
    class Generator
      # Default suggestion algorithms.
      DEFAULT_ALGORITHMS = [
        Strategies::EditDistanceStrategy,
        Strategies::PhoneticStrategy,
        Strategies::KeyboardProximityStrategy,
        Strategies::NgramStrategy
      ].freeze

      # @return [Object] The dictionary (any dictionary backend)
      attr_reader :dictionary

      # @return [Strategies::CompositeStrategy] The composite strategy
      attr_reader :strategy

      # Create a new suggestion generator.
      #
      # @param dictionary [Object] The dictionary instance
      # @param algorithms [Array<Class, Strategies::BaseStrategy>, nil] Algorithm classes or instances
      # @param max_suggestions [Integer] Maximum suggestions to return
      # @param config [Hash] Configuration options
      def initialize(dictionary, algorithms: nil, max_suggestions: 10, **config)
        @dictionary = dictionary
        @max_suggestions = max_suggestions
        # Use default algorithms if none provided
        algorithms_to_use = algorithms || DEFAULT_ALGORITHMS
        @strategy = build_strategy(algorithms_to_use, config)
      end

      # Generate suggestions for a word.
      #
      # @param word [String] The misspelled word
      # @param max_suggestions [Integer] Maximum suggestions (optional)
      # @return [SuggestionSet] Generated suggestions
      #
      # @example
      #   generator.generate("helo")
      #   # => #<Kotoshu::Suggestions::SuggestionSet ...>
      def generate(word, max_suggestions: nil)
        return SuggestionSet.empty if word.nil? || word.empty?

        context = Context.new(
          word: word,
          dictionary: @dictionary,
          max_results: max_suggestions || @max_suggestions
        )

        @strategy.generate(context)
      end

      # Alias for generate for API consistency.
      #
      # @param word [String] The misspelled word
      # @param max_suggestions [Integer] Maximum suggestions (optional)
      # @return [SuggestionSet] Generated suggestions
      #
      # @example
      #   generator.suggest("helo")
      #   # => #<Kotoshu::Suggestions::SuggestionSet ...>
      alias suggest generate

      # Check if a word is correct.
      #
      # @param word [String] The word to check
      # @return [Boolean] True if the word is in the dictionary
      #
      # @example
      #   generator.correct?("hello")  # => true
      #   generator.correct?("helo")   # => false
      def correct?(word)
        return false if word.nil? || word.empty?

        dictionary_lookup(word)
      end

      # Check if a word is incorrect.
      #
      # @param word [String] The word to check
      # @return [Boolean] True if the word is not in the dictionary
      def incorrect?(word)
        !correct?(word)
      end
      alias misspelled? incorrect?

      # Get the default algorithms.
      #
      # @return [Array<Class>] Default algorithm classes
      #
      # @example
      #   Generator.default_algorithms
      def self.default_algorithms
        DEFAULT_ALGORITHMS.dup
      end

      # Set the default algorithms.
      #
      # @param algorithms [Array<Class>] Algorithm classes
      #
      # @example
      #   Generator.default_algorithms = [MyCustomStrategy]
      class << self
        attr_writer :default_algorithms
      end

      private

      # Build the composite strategy from algorithm classes.
      #
      # @param algorithms [Array<Class, Strategies::BaseStrategy>] Algorithm classes or instances
      # @param config [Hash] Configuration options
      # @return [Strategies::CompositeStrategy] The composite strategy
      def build_strategy(algorithms, config)
        composite = Strategies::CompositeStrategy.new(name: :default, **config)

        algorithms.each do |alg|
          strategy = if alg.is_a?(Strategies::BaseStrategy)
                       alg
                     elsif alg.is_a?(Class) && alg < Strategies::BaseStrategy
                       alg.new(**config)
                     else
                       raise ArgumentError, "Invalid algorithm: #{alg.inspect}"
                     end

          composite.add(strategy)
        end

        composite
      end

      # Look up a word in the dictionary.
      #
      # Dispatch is type-driven (no `respond_to?`): Hash and Array are
      # supported as ad-hoc dictionaries for tests and one-off scripts;
      # everything else is treated as a real dictionary backend that
      # implements the documented `lookup(word)` interface. Passing an
      # object that doesn't quack like a dictionary surfaces as a
      # NoMethodError on `lookup` — that's intentional; the caller
      # misconfigured the generator.
      #
      # @param word [String] The word
      # @return [Boolean] True if found
      def dictionary_lookup(word)
        case @dictionary
        when Hash
          @dictionary.key?(word)
        when Array
          @dictionary.include?(word)
        else
          @dictionary.lookup(word)
        end
      end
    end
  end
end
