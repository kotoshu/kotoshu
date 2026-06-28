# frozen_string_literal: true

module Kotoshu
  # Languages module for language-specific implementations.
  #
  # Each language has its own namespace under this module,
  # allowing for clean organization and scalability.
  #
  # @example English components
  #   Kotoshu::Languages::English::SpellChecker
  #   Kotoshu::Languages::English::Tokenizer
  #   Kotoshu::Languages::English::POSTagger
  #   Kotoshu::Languages::English::GrammarRules
  #
  # @example French components
  #   Kotoshu::Languages::French::Tokenizer
  module Languages
    autoload :English, "kotoshu/languages/en/language"
    autoload :French, "kotoshu/languages/fr/language"
    autoload :German, "kotoshu/languages/de/language"
    autoload :Japanese, "kotoshu/languages/ja/language"
    autoload :Portuguese, "kotoshu/languages/pt/language"
    autoload :Russian, "kotoshu/languages/ru/language"
    autoload :Spanish, "kotoshu/languages/es/language"
  end
end

# Eagerly trigger autoloads: each language file calls Registry.register
# at file-load time, so all languages must be loaded for the registry
# to be fully populated.
Kotoshu::Languages.constants.each { |c| Kotoshu::Languages.const_get(c) }
