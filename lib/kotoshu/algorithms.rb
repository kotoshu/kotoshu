# frozen_string_literal: true

module Kotoshu
  # Algorithms namespace for spell checking algorithms.
  #
  # Contains the core algorithms ported from Spylls:
  # - Lookup::Lookuper: word correctness checking with affix support
  # - Suggest::Suggester: main suggestion orchestration
  # - Permutations: edit-distance permutations
  # - NgramSuggest: n-gram based suggestion algorithm
  # - PhonetSuggest: phonetic suggestion algorithm
  # - Capitalization: capitalization handling
  module Algorithms
    autoload :Lookup, "kotoshu/algorithms/lookup"
    autoload :Suggest, "kotoshu/algorithms/suggest"
    autoload :Permutations, "kotoshu/algorithms/permutations"
    autoload :NgramSuggest, "kotoshu/algorithms/ngram_suggest"
    autoload :PhonetSuggest, "kotoshu/algorithms/phonet_suggest"
    autoload :Capitalization, "kotoshu/algorithms/capitalization"
    autoload :EditDistance, "kotoshu/algorithms/edit_distance"
  end
end
