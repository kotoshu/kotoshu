# frozen_string_literal: true

require_relative '../../../../lib/kotoshu/keyboard'

RSpec.describe Kotoshu::Keyboard::Layouts::QWERTZ do
  subject(:layout) { described_class.new }

  describe '#initialize' do
    it 'creates QWERTZ layout' do
      expect(layout.name).to eq('QWERTZ')
    end

    it 'supports German and variants' do
      expect(layout.supports_language?('de')).to be true
      expect(layout.supports_language?('de-DE')).to be true
      expect(layout.supports_language?('de-AT')).to be true
      expect(layout.supports_language?('de-CH')).to be true
    end

    it 'supports Austrian (at)' do
      expect(layout.supports_language?('at')).to be true
    end

    it 'supports Swiss (ch)' do
      expect(layout.supports_language?('ch')).to be true
    end
  end

  describe '#position' do
    it 'has correct position for umlaut keys' do
      # On German QWERTZ: a s d f g h j k l ö ä
      # Position indices: 0 1 2 3 4 5 6 7 8 9  10
      expect(layout.position('ä')).to eq([2, 10]) # In home row
      expect(layout.position('ö')).to eq([2, 9])
      expect(layout.position('ü')).to eq([1, 10])
    end

    it 'has ß (Eszett) in number row' do
      expect(layout.position('ß')).to eq([0, 11])
    end
  end

  describe '#distance' do
    context 'QWERTZ-specific: z and y are swapped from QWERTY' do
      it 'places z in top row (position 5)' do
        expect(layout.position('z')).to eq([1, 5])
      end

      it 'places y in bottom row (position 0)' do
        expect(layout.position('y')).to eq([3, 0])
      end

      it 'has same distance between z and y as QWERTY (just swapped)' do
        # On QWERTZ: z=[1,5], y=[3,0], distance = |1-3| + |5-0| = 2 + 5 = 7
        expect(layout.distance('z', 'y')).to eq(7)
      end
    end
  end

  describe '#adjacent_keys' do
    it 'returns adjacent keys for z (in top row)' do
      adjacent = layout.adjacent_keys('z')
      # z is at [1,5], adjacent to: t=[1,4], u=[1,6]
      expect(adjacent).to include('t')
      expect(adjacent).to include('u')
    end
  end

  describe 'German language support' do
    it 'is the default layout for German' do
      expect(layout.supports_language?('de')).to be true
    end

    it 'does not support English' do
      expect(layout.supports_language?('en')).to be false
    end

    it 'does not support French' do
      expect(layout.supports_language?('fr')).to be false
    end
  end

  describe 'character support' do
    it 'includes German umlauts' do
      expect(layout.position('ä')).to eq([2, 10])
      expect(layout.position('ö')).to eq([2, 9])
      expect(layout.position('ü')).to eq([1, 10])
    end

    it 'includes Eszett (ß)' do
      expect(layout.position('ß')).to eq([0, 11])
    end
  end
end
