# frozen_string_literal: true

module Kotoshu
  # Dictionary backends for different formats (Hunspell, CSpell, plain text, etc.).
  module Dictionary
    autoload :Base, "kotoshu/dictionary/base"
    autoload :CSpell, "kotoshu/dictionary/cspell"
    autoload :Custom, "kotoshu/dictionary/custom"
    autoload :Hunspell, "kotoshu/dictionary/hunspell"
    autoload :PlainText, "kotoshu/dictionary/plain_text"
    autoload :Repository, "kotoshu/dictionary/repository"
    autoload :Unified, "kotoshu/dictionary/unified"
    autoload :UnixWords, "kotoshu/dictionary/unix_words"
  end
end
