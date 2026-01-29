# frozen_string_literal: true

require_relative "../suggestion"

module Kotoshu
  module Suggestions
    module Strategies
      # Base class for suggestion strategies.
      #
      # Subclasses must implement the {#generate} method.
      #
      # @example Implementing a custom strategy
      #   class MyStrategy < BaseStrategy
      #     def generate(context)
      #       # Return suggestions based on context.word
      #       SuggestionSet.from_words(%w[word1 word2], source: :my_strategy)
      #     end
      #   end
      class BaseStrategy
        # @return [Symbol] Strategy name
        attr_reader :name

        # @return [Hash] Strategy configuration
        attr_reader :config

        # Create a new base strategy.
        #
        # @param name [String, Symbol] Strategy name
        # @param config [Hash] Configuration options
        # @option config [Integer] max_results Maximum results to return
        # @option config [Boolean] enabled Whether strategy is enabled
        def initialize(name: :base, **config)
          @name = name.to_sym
          @config = config
          @enabled = config.fetch(:enabled, true)
          @max_results = config.fetch(:max_results, 10)
        end

        # Generate suggestions for a word.
        #
        # @abstract Subclasses must implement this method.
        # @param context [Context] The suggestion context
        # @return [SuggestionSet] Generated suggestions
        # @raise [NotImplementedError] Subclass must implement
        def generate(context)
          raise NotImplementedError, "#{self.class} must implement #generate"
        end

        # Check if this strategy is enabled.
        #
        # @return [Boolean] True if enabled
        def enabled?
          @enabled
        end

        # Get the max results configuration.
        #
        # @param default [Integer] Default value if not set
        # @return [Integer] Max results
        def max_results(default = 10)
          @max_results || default
        end

        # Get a configuration value.
        #
        # @param key [Symbol] The config key
        # @param default [Object] Default value if not set
        # @return [Object] The config value
        def get_config(key, default = nil)
          @config.fetch(key, default)
        end

        # Check if a config value is present.
        #
        # @param key [Symbol] The config key
        # @return [Boolean] True if config has the key
        def has_config?(key)
          @config.key?(key)
        end

        # Get the priority for this strategy.
        #
        # @return [Integer] Priority (lower = higher priority)
        def priority
          @config.fetch(:priority, 100)
        end

        # Check if this strategy should handle the context.
        #
        # Default implementation checks if the word is not in the dictionary.
        # Subclasses can override for more specific logic.
        #
        # @param context [Context] The suggestion context
        # @return [Boolean] True if the strategy should handle this context
        def handles?(context)
          return false unless enabled?
          !dictionary_lookup(context, context.word)
        end

        # Create a suggestion from a word.
        #
        # @param word [String] The suggested word
        # @param distance [Integer] Edit distance
        # @param confidence [Float] Confidence score
        # @return [Suggestion] New suggestion
        def create_suggestion(word, distance: 0, confidence: 1.0)
          Suggestion.new(
            word: word,
            distance: distance,
            confidence: confidence,
            source: @name
          )
        end

        # Create a suggestion set from words.
        #
        # @param words [Array<String>] Array of words
        # @param distances [Hash] Optional word => distance mapping
        # @return [SuggestionSet] New suggestion set
        def create_suggestion_set(words, distances = {})
          suggestions = words.map do |word|
            distance = distances.fetch(word, 1)
            confidence = calculate_confidence(distance)
            create_suggestion(word, distance: distance, confidence: confidence)
          end
          SuggestionSet.new(suggestions, max_size: max_results)
        end

        # Convert strategy to string.
        #
        # @return [String] String representation
        def to_s
          "#{self.class.name}(name: #{@name}, enabled: #{enabled?})"
        end
        alias inspect to_s

        private

        # Look up a word in the dictionary.
        #
        # @param context [Context] The suggestion context
        # @param word [String] The word to look up
        # @return [Boolean] True if word exists
        def dictionary_lookup(context, word)
          dictionary = context.dictionary

          # Check if it's a dictionary backend with lookup method
          if dictionary.respond_to?(:lookup)
            dictionary.lookup(word)
          elsif dictionary.is_a?(Core::IndexedDictionary)
            dictionary.has_word?(word)
          elsif dictionary.respond_to?(:include?)
            dictionary.include?(word)
          elsif dictionary.is_a?(Hash)
            dictionary.key?(word)
          else
            false
          end
        end

        # Get all words from the dictionary.
        #
        # @param context [Context] The suggestion context
        # @return [Array<String>] All words
        def dictionary_words(context)
          dictionary = context.dictionary

          if dictionary.respond_to?(:words)
            dictionary.words
          elsif dictionary.is_a?(Array)
            dictionary
          elsif dictionary.is_a?(Hash)
            dictionary.keys
          elsif dictionary.is_a?(Core::IndexedDictionary)
            dictionary.words
          else
            []
          end
        end

        # Calculate confidence from distance.
        #
        # Higher distance = lower confidence.
        #
        # @param distance [Integer] Edit distance
        # @return [Float] Confidence score (0.0 to 1.0)
        def calculate_confidence(distance)
          return 1.0 if distance.zero?
          # Simple decay: confidence = 1 / (1 + distance)
          # Can be overridden by subclasses for more sophisticated calculations
          1.0 / (1.0 + distance)
        end
      end
    end
  end
end
