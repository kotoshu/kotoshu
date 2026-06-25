# frozen_string_literal: true

require_relative 'grammar/rule_engine'
require_relative 'grammar/rule_loader'
require_relative 'grammar/rule'
require_relative 'grammar/pattern_matchers/base_matcher'
require_relative 'grammar/pattern_matchers/vowel_sound_matcher'
require_relative 'grammar/pattern_matchers/possessive_context_matcher'
require_relative 'grammar/pattern_matchers/double_negative_matcher'

module Kotoshu
  # Grammar rules infrastructure for Kotoshu.
  #
  # This module provides configuration-driven grammar checking
  # where all linguistic data is stored in YAML files.
  module Grammar
  end
end
