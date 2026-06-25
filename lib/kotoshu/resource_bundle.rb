# frozen_string_literal: true

module Kotoshu
  ResourceBundle = Struct.new(
    :language,
    :dictionary,
    :frequency,
    :model,
    :rules,
    :cached,
    :source_urls,
    keyword_init: true
  ) do
    def cached?
      cached ? true : false
    end

    def has_frequency?
      !frequency.nil?
    end

    def has_model?
      !model.nil?
    end

    def has_rules?
      !rules.nil?
    end
  end
end
