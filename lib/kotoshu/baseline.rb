# frozen_string_literal: true

module Kotoshu
  # CI baselines (plan 82, Track B).
  #
  # `kotoshu check --baseline FILE` freezes existing spelling debt so
  # CI fails only on NEW errors: errors covered by the baseline pass,
  # anything else fails, and stale entries (whose errors no longer
  # exist) are reported so debt shrinks visibly.
  #
  # Matching is count-based, not position-based — an entry records how
  # often a word is misspelled in a file (`count`), which survives
  # reformatting that moves lines around. `line` is informational
  # (the first occurrence when the baseline was written).
  module Baseline
    autoload :Application, "kotoshu/baseline/application"
    autoload :Entry, "kotoshu/baseline/entry"
    autoload :Store, "kotoshu/baseline/store"
  end
end
