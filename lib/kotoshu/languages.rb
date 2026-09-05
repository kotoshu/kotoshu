# frozen_string_literal: true

module Kotoshu
  # Per-language implementations (English, German, French, etc.).
  #
  # Sibling module to {Language} (the framework). Each per-language file
  # calls Language::Registry.register at load time; {Language::Registry.ensure_languages_loaded}
  # triggers these autoloads on first registry access.
  module Languages
    autoload :Arabic, "kotoshu/languages/ar/language"
    autoload :English, "kotoshu/languages/en/language"
    autoload :French, "kotoshu/languages/fr/language"
    autoload :German, "kotoshu/languages/de/language"
    autoload :Hebrew, "kotoshu/languages/he/language"
    autoload :Japanese, "kotoshu/languages/ja/language"
    autoload :Persian, "kotoshu/languages/fa/language"
    autoload :Portuguese, "kotoshu/languages/pt/language"
    autoload :Russian, "kotoshu/languages/ru/language"
    autoload :Spanish, "kotoshu/languages/es/language"

    # Shared base for the thin wave-1 modules (plan 84).
    autoload :LatinBase, "kotoshu/languages/latin_base"
    # Wave-1 modules (plan 84, Track B): ca cs da el hu it nl pl ro
    # sv tr uk vi.
    autoload :Catalan, "kotoshu/languages/ca/language"
    autoload :Czech, "kotoshu/languages/cs/language"
    autoload :Danish, "kotoshu/languages/da/language"
    autoload :Greek, "kotoshu/languages/el/language"
    autoload :Hungarian, "kotoshu/languages/hu/language"
    autoload :Italian, "kotoshu/languages/it/language"
    autoload :Dutch, "kotoshu/languages/nl/language"
    autoload :Polish, "kotoshu/languages/pl/language"
    autoload :Romanian, "kotoshu/languages/ro/language"
    autoload :Swedish, "kotoshu/languages/sv/language"
    autoload :Turkish, "kotoshu/languages/tr/language"
    autoload :Ukrainian, "kotoshu/languages/uk/language"
    autoload :Vietnamese, "kotoshu/languages/vi/language"
  end
end
