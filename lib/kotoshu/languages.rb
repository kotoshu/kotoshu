# frozen_string_literal: true

# Load all language-specific modules
require_relative 'languages/en/language'
require_relative 'languages/fr/language'
require_relative 'languages/de/language'
require_relative 'languages/ja/language'
require_relative 'languages/pt/language'
require_relative 'languages/ru/language'
require_relative 'languages/es/language'

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
  #
  # @example German components
  #   Kotoshu::Languages::German::Tokenizer
  #
  # @example Japanese components
  #   Kotoshu::Languages::Japanese::Tokenizer
  #
  # @example Portuguese components
  #   Kotoshu::Languages::Portuguese::Tokenizer
  #
  # @example Russian components
  #   Kotoshu::Languages::Russian::Tokenizer
  #
  # @example Spanish components
  #   Kotoshu::Languages::Spanish::Tokenizer
  module Languages
  end
end
