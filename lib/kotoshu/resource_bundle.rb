# frozen_string_literal: true

module Kotoshu
  # The Stage-2 result: every resource {ResourceManager.resolve} found
  # for one language, ready to hand to `Spellchecker.new`.
  #
  # A member is nil for any resource that was not requested in the
  # `want:` list or is not set up. The bundle is cache-only data —
  # building one never touches the network.
  #
  # @example
  #   Kotoshu.setup(:en)
  #   bundle = Kotoshu::ResourceManager.resolve(language: "en")
  #   bundle.dictionary  # => #<Kotoshu::Dictionary::Hunspell ...>
  #   bundle.has_model?  # => false (model not requested)
  ResourceBundle = Struct.new(
    :language,     # [String] Language code the bundle was resolved for
    :dictionary,   # [Dictionary::Hunspell, nil] Spelling dictionary
    :frequency,    # [Object, nil] Frequency data (Kelly tiers)
    :model,        # [Object, nil] ONNX embedding model
    :rules,        # [Object, nil] Grammar rules (reserved; nil today)
    :cached,       # [Boolean] True — resolve is cache-only by contract
    :source_urls,  # [Array<String>] URLs the resources came from
    keyword_init: true
  ) do
    # Whether the bundle's data came from the cache (always true for
    # ResourceManager-resolved bundles; kept for forward compatibility).
    #
    # @return [Boolean]
    def cached?
      cached ? true : false
    end

    # Whether a frequency list is included.
    #
    # @return [Boolean]
    def has_frequency?
      !frequency.nil?
    end

    # Whether an ONNX model is included.
    #
    # @return [Boolean]
    def has_model?
      !model.nil?
    end

    # Whether grammar rules are included (reserved; false today).
    #
    # @return [Boolean]
    def has_rules?
      !rules.nil?
    end
  end
end
