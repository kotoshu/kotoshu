# frozen_string_literal: true

module Kotoshu
  module Checks
    # A typed quality-check finding. The payload is the check's native
    # result object (spelling carries a
    # Models::Result::WordResult; grammar a rule-error hash) - the
    # framework types WHO found it, the check owns WHAT it found.
    Finding = Struct.new(:check_kind, :payload) do
      def word
        payload.respond_to?(:word) ? payload.word : payload[:word]
      end

      def position
        payload.respond_to?(:position) ? payload.position : payload[:position]
      end
    end
  end
end
