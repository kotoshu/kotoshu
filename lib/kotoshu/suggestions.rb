# frozen_string_literal: true

module Kotoshu
  # Suggestion generation system: strategies, generator, and result types.
  module Suggestions
    autoload :Context, "kotoshu/suggestions/context"
    autoload :Generator, "kotoshu/suggestions/generator"
    autoload :Pipeline, "kotoshu/suggestions/pipeline"
    autoload :Suggestion, "kotoshu/suggestions/suggestion"
    autoload :SuggestionSet, "kotoshu/suggestions/suggestion_set"

    # Strategies sub-namespace.
    module Strategies
      autoload :BaseStrategy, "kotoshu/suggestions/strategies/base_strategy"
      autoload :CompositeStrategy, "kotoshu/suggestions/strategies/composite_strategy"
      autoload :EditDistanceStrategy, "kotoshu/suggestions/strategies/edit_distance_strategy"
      autoload :KeyboardProximityStrategy, "kotoshu/suggestions/strategies/keyboard_proximity_strategy"
      autoload :NgramStrategy, "kotoshu/suggestions/strategies/ngram_strategy"
      autoload :PhoneticStrategy, "kotoshu/suggestions/strategies/phonetic_strategy"
      autoload :SemanticStrategy, "kotoshu/suggestions/strategies/semantic_strategy"
      autoload :SymspellStrategy, "kotoshu/suggestions/strategies/symspell_strategy"
    end
  end
end
