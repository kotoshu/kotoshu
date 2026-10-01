# frozen_string_literal: true

module Kotoshu
  # Grammar rules infrastructure for Kotoshu.
  #
  # This module provides configuration-driven grammar checking
  # where all linguistic data is stored in YAML files.
  module Grammar
    autoload :Rule, "kotoshu/grammar/rule"
    autoload :PatternRule, "kotoshu/grammar/pattern_rule"
    autoload :RuleEngine, "kotoshu/grammar/rule_engine"
    autoload :RuleLoader, "kotoshu/grammar/rule_loader"
    autoload :PosTagger, "kotoshu/grammar/pos_tagger"
    autoload :Checker, "kotoshu/grammar/checker"
    autoload :ByteBpe, "kotoshu/grammar/byte_bpe"
    autoload :Morphology, "kotoshu/grammar/morphology"
    autoload :Tagger, "kotoshu/grammar/tagger"
    autoload :GectorDecoder, "kotoshu/grammar/gector_decoder"

    module PatternMatchers
      autoload :BaseMatcher, "kotoshu/grammar/pattern_matchers/base_matcher"
      autoload :VowelSoundMatcher, "kotoshu/grammar/pattern_matchers/vowel_sound_matcher"
      autoload :PossessiveContextMatcher, "kotoshu/grammar/pattern_matchers/possessive_context_matcher"
      autoload :PossessiveContractionMatcher, "kotoshu/grammar/pattern_matchers/possessive_contraction_matcher"
      autoload :DoubleNegativeMatcher, "kotoshu/grammar/pattern_matchers/double_negative_matcher"
      autoload :PhraseMatcher, "kotoshu/grammar/pattern_matchers/phrase_matcher"
      autoload :SentenceStartMatcher, "kotoshu/grammar/pattern_matchers/sentence_start_matcher"
      autoload :WordListMatcher, "kotoshu/grammar/pattern_matchers/word_list_matcher"
      autoload :PosSequenceMatcher, "kotoshu/grammar/pattern_matchers/pos_sequence_matcher"
    end
  end
end
