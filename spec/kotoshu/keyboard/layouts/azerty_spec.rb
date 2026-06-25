# frozen_string_literal: true

require_relative '../../../../lib/kotoshu/keyboard'

RSpec.describe Kotoshu::Keyboard::Layouts::AZERTY do
  subject(:layout) { described_class.new }

  describe '#initialize' do
    it 'creates AZERTY layout' do
      expect(layout.name).to eq('AZERTY')
    end

    it 'supports French and variants' do
      expect(layout.supports_language?('fr')).to be true
      expect(layout.supports_language?('fr-FR')).to be true
    end

    it 'supports Belgian (be)' do
      expect(layout.supports_language?('be')).to be true
    end
  end

  describe '#position' do
    context 'AZERTY-specific: a and q are swapped from QWERTY' do
      it 'places a in top row (position 0)' do
        expect(layout.position('a')).to eq([1, 0])
      end

      it 'places q in home row (position 0)' do
        expect(layout.position('q')).to eq([2, 0])
      end
    end

    context 'AZERTY-specific: z and w are swapped from QWERTY' do
      it 'places z in top row (position 1)' do
        expect(layout.position('z')).to eq([1, 1])
      end

      it 'places w in bottom row (position 0)' do
        expect(layout.position('w')).to eq([3, 0])
      end
    end
  end

  describe '#distance' do
    context 'AZERTY-specific characteristics' do
      it 'has a and q far apart (swapped from QWERTY)' do
        # On AZERTY: a=[1,0], q=[2,0], distance = |1-2| + |0-0| = 1
        expect(layout.distance('a', 'q')).to eq(1)
      end

      it 'has z and w far apart (swapped from QWERTY)' do
        # On AZERTY: z=[1,1], w=[3,0], distance = |1-3| + |1-0| = 2 + 1 = 3
        expect(layout.distance('z', 'w')).to eq(3)
      end
    end
  end

  describe '#adjacent_keys' do
    it 'returns adjacent keys for a (in top row)' do
      adjacent = layout.adjacent_keys('a')
      # a is at [1,0], adjacent to: z=[1,1]
      expect(adjacent).to include('z')
    end
  end

  describe 'French language support' do
    it 'is the default layout for French' do
      expect(layout.supports_language?('fr')).to be true
    end

    it 'does not support English' do
      expect(layout.supports_language?('en')).to be false
    end

    it 'does not support German' do
      expect(layout.supports_language?('de')).to be false
    end
  end
end
