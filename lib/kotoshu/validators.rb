# frozen_string_literal: true

module Kotoshu
  # Validation-layer integrations (plan 89). Soft dependency on
  # ActiveModel — see Validators::SpellingValidator.
  module Validators
    autoload :SpellingValidator, "kotoshu/validators/spelling_validator"
  end
end
