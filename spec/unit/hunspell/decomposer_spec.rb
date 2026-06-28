# frozen_string_literal: true

RSpec.describe 'Unit: Hunspell Decomposer' do
  describe 'Compound decomposer tests' do
    it 'tests word decomposition for compounding' do
      # The original Spylls test uses:
      # - Compounder class from spyll.hunspell.algo.compounder
      # - Part and Position classes for decomposition results
      # Kotoshu handles compound word decomposition via Lookup::Lookuper
      # (see spec/integrational/lookup_spec.rb for end-to-end coverage).
      skip 'Compounder class not ported — covered by integrational lookup specs'
    end
  end
end
