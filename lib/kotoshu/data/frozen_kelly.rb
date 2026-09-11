# frozen_string_literal: true

require "json"
require "set"

module Kotoshu
  module Suggestions
    # The frozen Kelly frequency tiers for English, read once per
    # process from the generated JSON beside this file (provenance and
    # the upstream sha256 live inside it). Both engines ship identical
    # membership - the Rust side embeds kotoshu-rs
    # kotoshu/src/suggest/frequency_data.rs, this file is generated
    # from those tables - so a cache-cold Ruby machine ranks
    # suggestions exactly like the frozen conformance vectors
    # (plan 119). Regeneration goes through
    # scripts/generate_frozen_tiers.rb, never by hand.
    module FrozenTiers
      DATA_PATH = File.expand_path("frozen_kelly/en.json", __dir__)

      # The tiers for +language_code+ in the Set shape the suggestion
      # strategies consume, or nil when no frozen table exists for the
      # language (the caller falls back further).
      #
      # @param language_code [String] ISO 639-1 code
      # @return [Hash{Symbol => Set}, nil]
      def self.tiers_for(language_code)
        return nil unless language_code.to_s == "en"

        @tiers ||= begin
          raw = JSON.parse(File.read(DATA_PATH), symbolize_names: true)
          raw.fetch(:tiers).to_h do |name, words|
            [name.to_sym, Set.new(words)]
          end
        end
      end
    end
  end
end
