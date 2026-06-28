# frozen_string_literal: true

require "lutaml/model"
require_relative "../../../suggestions/suggestion"
require_relative "../../../suggestions/suggestion_set"

module Kotoshu
  module Models
    module Result
      # Result object for checking a single word.
      #
      # Serialized via lutaml-model. The +suggestions+ attribute is a
      # collection of {Suggestions::Suggestion}. For rich query semantics
      # (filtering by source, confidence, distance), wrap with
      # {Suggestions::SuggestionSet} via +#to_suggestion_set+.
      class WordResult < Lutaml::Model::Serializable
        attribute :word, :string, default: ""
        attribute :correct, :boolean, default: true
        attribute :position, :integer
        attribute :suggestions, Suggestions::Suggestion, collection: true
        attribute :metadata, :hash, default: {}

        def initialize(word = "", correct:, suggestions: nil, position: nil, metadata: {})
          suggestions_array =
            case suggestions
            when Suggestions::SuggestionSet then suggestions.suggestions
            when Array then suggestions
            when nil then []
            else raise ArgumentError, "suggestions must be SuggestionSet, Array, or nil"
            end

          super(
            word: word.to_s,
            correct: correct,
            position: position,
            suggestions: suggestions_array,
            metadata: metadata
          )
        end

        def correct?
          correct
        end

        def incorrect?
          !correct
        end

        def has_suggestions?
          !suggestions.empty?
        end

        def suggestion_count
          suggestions.size
        end

        def top_suggestions(n = 3)
          suggestions.first(n).map(&:word)
        end

        def first_suggestion
          suggestions.first&.word
        end

        # Wrap the suggestions array in a {Suggestions::SuggestionSet}
        # for rich query (filter by source, confidence, distance).
        #
        # @return [Suggestions::SuggestionSet]
        def to_suggestion_set
          Suggestions::SuggestionSet.new(suggestions)
        end

        def ==(other)
          return false unless other.is_a?(WordResult)

          word == other.word && correct == other.correct
        end
        alias eql? ==

        def hash
          [word, correct].hash
        end

        def to_s
          if correct
            word
          elsif has_suggestions?
            "#{word} (did you mean #{top_suggestions(3).join(', ')}?)"
          else
            "#{word} (no suggestions)"
          end
        end
        alias inspect to_s

        def self.correct(word, position: nil)
          new(word, correct: true, position: position)
        end

        def self.incorrect(word, suggestions: nil, position: nil)
          new(word, correct: false, suggestions: suggestions, position: position)
        end
      end
    end
  end
end
