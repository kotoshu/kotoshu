# frozen_string_literal: true

RSpec.describe 'Unit: Hunspell Flags' do
  describe 'Affix flags' do
    it 'tests affix flag processing' do
      # The original Spylls test checks _affix_flags method.
      # Kotoshu uses AffixRule class with different flag handling — these
      # behaviors are covered by spec/integrational/lookup_spec.rb instead.
      skip 'Different architecture in Kotoshu — covered by integrational lookup specs'
    end
  end

  describe 'Compound flags' do
    it 'tests compound flag processing' do
      skip 'Different architecture in Kotoshu — covered by integrational lookup specs'
    end
  end
end
