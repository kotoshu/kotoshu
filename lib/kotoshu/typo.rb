# frozen_string_literal: true

module Kotoshu
  # The hybrid typo-retrieval layer (plan 131): opt-in, native-only,
  # silent-degrade.
  module Typo
    autoload :Engine, "kotoshu/typo/engine"
  end
end
