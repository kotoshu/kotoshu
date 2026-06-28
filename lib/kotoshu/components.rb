# frozen_string_literal: true

module Kotoshu
  # Pluggable linguistic components (tokenizer, POS tagger, spell checker, synthesizer).
  module Components
    autoload :SpellChecker, "kotoshu/components/spell_checker"
    autoload :PassthroughSpellChecker, "kotoshu/components/passthrough_spell_checker"
    autoload :PosTagger, "kotoshu/components/pos_tagger"
    autoload :Synthesizer, "kotoshu/components/synthesizer"
    autoload :Tokenizer, "kotoshu/components/tokenizer"
    autoload :WhitespaceTokenizer, "kotoshu/components/whitespace_tokenizer"
  end
end
