# frozen_string_literal: true

module Kotoshu
  # The Checks framework: kotoshu is a content-quality checker, and a
  # spell check is one check among many (plan 148). Each check is a
  # first-class class with one contract ({Checks::Base}); the registry
  # composes the checks whose dependencies are satisfied for the active
  # language. A new check is a registration, not surgery.
  module Checks
    autoload :Base, "kotoshu/checks/base"
    autoload :Finding, "kotoshu/checks/finding"
    autoload :GrammarCheck, "kotoshu/checks/grammar_check"
    autoload :Registry, "kotoshu/checks/registry"
    autoload :SpellingCheck, "kotoshu/checks/spelling_check"
  end
end
