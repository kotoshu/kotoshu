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
    autoload :Portuguese, "kotoshu/languages/pt/language"
    autoload :Russian, "kotoshu/languages/ru/language"
    autoload :Spanish, "kotoshu/languages/es/language"
  end
end
