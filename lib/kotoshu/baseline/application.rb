# frozen_string_literal: true

module Kotoshu
  module Baseline
    # Outcome of applying a {Store} to one check result. Plain data
    # (Struct) — not a serialized model.
    #
    # - +result+ — the new {Models::Result::DocumentResult}: errors
    #   are the ones NOT covered by the baseline; baseline-suppressed
    #   errors moved into `suppressed_errors` (marked with
    #   `suppressed_by: "baseline"`), joining any inline-suppressed
    #   entries produced by the checker.
    # - +suppressed_count+ — how many errors the baseline absorbed
    # - +stale_count+ — baseline entries for the checked file whose
    #   errors no longer exist
    Application = Struct.new(:result, :suppressed_count, :stale_count, keyword_init: true)
  end
end
