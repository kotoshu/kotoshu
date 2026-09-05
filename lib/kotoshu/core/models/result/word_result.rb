# frozen_string_literal: true

require "lutaml/model"

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
        # What absorbed a suppressed misspelling (plan 82): an inline
        # `kotoshu:disable-*` directive or a baseline entry.
        SUPPRESSED_BY_INLINE = "inline"
        SUPPRESSED_BY_BASELINE = "baseline"
        attribute :word, :string, default: ""
        attribute :correct, :boolean, default: true
        attribute :position, :integer
        attribute :suggestions, Suggestions::Suggestion, collection: true
        attribute :metadata, :hash, default: {}
        # Suppression bookkeeping: a suppressed word is a real misspelling
        # absorbed by an inline ignore directive or a baseline entry.
        # Suppressed errors leave DocumentResult#errors and surface via
        # DocumentResult#suppressed_errors.
        attribute :suppressed, :boolean, default: false
        attribute :suppressed_by, :string

        # lutaml-model calls +new(**attrs)+ when deserializing via
        # +from_hash+. The signature accepts every attribute as a
        # keyword plus a splat for framework-private keywords (e.g.
        # +lutaml_register+) so the round-trip works without lutaml
        # having to poke ivars directly.
        #
        # +suggestions+ accepts a {Suggestions::SuggestionSet},
        # an Array, or nil for ergonomic construction; the SuggestionSet
        # case is unwrapped to its underlying Array.
        def initialize(word: "", correct: true, suggestions: nil, position: nil, metadata: {}, suppressed: false, suppressed_by: nil, **kwargs)
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
            metadata: metadata,
            suppressed: suppressed,
            suppressed_by: suppressed_by,
            **kwargs
          )
        end

        def correct?
          correct
        end

        def incorrect?
          !correct
        end

        # True when an inline directive or a baseline absorbed this
        # misspelling (see +suppressed_by+).
        def suppressed?
          suppressed
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
          new(word: word, correct: true, position: position)
        end

        def self.incorrect(word, suggestions: nil, position: nil)
          new(word: word, correct: false, suggestions: suggestions, position: position)
        end
      end
    end
  end
end
