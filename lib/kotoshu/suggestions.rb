# frozen_string_literal: true

module Kotoshu
  # Suggestion generation system: strategies, generator, and result types.
  module Suggestions
    autoload :Context, "kotoshu/suggestions/context"
    autoload :FrequencyProvider, "kotoshu/suggestions/frequency_provider"
    autoload :FrozenTiers, "kotoshu/data/frozen_kelly"
    autoload :Generator, "kotoshu/suggestions/generator"
    autoload :Pipeline, "kotoshu/suggestions/pipeline"
    autoload :SemanticCascade, "kotoshu/suggestions/semantic_cascade"
    autoload :Suggestion, "kotoshu/suggestions/suggestion"
    autoload :ConfusionSet, "kotoshu/suggestions/confusion_set"
    autoload :SuggestionSet, "kotoshu/suggestions/suggestion_set"
    autoload :SweepIndex, "kotoshu/suggestions/sweep_index"
    autoload :TypoMerge, "kotoshu/suggestions/typo_merge"

    # Vowelless-script marks (interscript P0): Arabic haraqat and
    # Hebrew niqqud are combining marks the unvocalized dictionaries
    # never carry. They fold away (SymSpellStrategy#fold_word) and are
    # stripped at the Generator ingress before any distance — like
    # downcasing, not scoring. Inert for scripts without these marks.
    # Escapes-only on one line with no /x flag: an extended-mode
    # reformat once folded a literal newline+space INTO the class,
    # which made the ingress strip spaces from every input.
    # Presentation-form ligatures (U+FEF5-FEFB) are NOT handled:
    # keyboards emit the decomposed pair; noted for a later pass.
    # rubocop:disable Layout/LineLength -- a wrapped/multiline class once
    # folded literal whitespace INTO the ranges (space got stripped
    # from every input); this literal stays on one line.
    VOWELLESS_MARKS = /[\u0591-\u05bd\u05bf\u05c1\u05c2\u05c4\u05c5\u05c7\u064b-\u065f\u0670]/
    # rubocop:enable Layout/LineLength

    # Strategies sub-namespace.
    module Strategies
      autoload :BaseStrategy, "kotoshu/suggestions/strategies/base_strategy"
      autoload :CompositeStrategy, "kotoshu/suggestions/strategies/composite_strategy"
      autoload :EditDistanceStrategy, "kotoshu/suggestions/strategies/edit_distance_strategy"
      autoload :KeyboardProximityStrategy, "kotoshu/suggestions/strategies/keyboard_proximity_strategy"
      autoload :NgramStrategy, "kotoshu/suggestions/strategies/ngram_strategy"
      autoload :PhoneticStrategy, "kotoshu/suggestions/strategies/phonetic_strategy"
      autoload :SemanticStrategy, "kotoshu/suggestions/strategies/semantic_strategy"
      autoload :SymSpellStrategy, "kotoshu/suggestions/strategies/symspell_strategy"
      autoload :TypoRetrievalStrategy, "kotoshu/suggestions/strategies/typo_retrieval_strategy"
      autoload :WordIndex, "kotoshu/suggestions/strategies/word_index"
    end
  end
end
