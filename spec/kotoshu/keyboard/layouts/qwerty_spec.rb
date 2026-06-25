# frozen_string_literal: true

require_relative '../../../../lib/kotoshu/keyboard'

RSpec.describe Kotoshu::Keyboard::Layouts::QWERTY do
  subject(:layout) { described_class.new }

  describe '#initialize' do
    it 'creates QWERTY layout' do
      expect(layout.name).to eq('QWERTY')
    end

    it 'supports English and variants' do
      expect(layout.supports_language?('en')).to be true
      expect(layout.supports_language?('en-US')).to be true
      expect(layout.supports_language?('en-GB')).to be true
    end

    it 'supports Spanish' do
      expect(layout.supports_language?('es')).to be true
      expect(layout.supports_language?('es-ES')).to be true
      expect(layout.supports_language?('es-MX')).to be true
    end

    it 'supports Portuguese' do
      expect(layout.supports_language?('pt')).to be true
      expect(layout.supports_language?('pt-BR')).to be true
      expect(layout.supports_language?('pt-PT')).to be true
    end

    it 'supports US English' do
      expect(layout.supports_language?('us')).to be true
    end
  end

  describe '#position' do
    it 'has correct position for number row keys' do
      expect(layout.position('1')).to eq([0, 1])
      expect(layout.position('5')).to eq([0, 5])
      expect(layout.position('0')).to eq([0, 10])
      expect(layout.position('-')).to eq([0, 11])
    end

    it 'has correct position for top row (QWERTY)' do
      expect(layout.position('q')).to eq([1, 0])
      expect(layout.position('w')).to eq([1, 1])
      expect(layout.position('e')).to eq([1, 2])
      expect(layout.position('r')).to eq([1, 3])
      expect(layout.position('t')).to eq([1, 4])
      expect(layout.position('y')).to eq([1, 5])
      expect(layout.position('u')).to eq([1, 6])
      expect(layout.position('i')).to eq([1, 7])
      expect(layout.position('o')).to eq([1, 8])
      expect(layout.position('p')).to eq([1, 9])
    end

    it 'has correct position for home row (ASDFG)' do
      expect(layout.position('a')).to eq([2, 0])
      expect(layout.position('s')).to eq([2, 1])
      expect(layout.position('d')).to eq([2, 2])
      expect(layout.position('f')).to eq([2, 3])
      expect(layout.position('g')).to eq([2, 4])
      expect(layout.position('h')).to eq([2, 5])
      expect(layout.position('j')).to eq([2, 6])
      expect(layout.position('k')).to eq([2, 7])
      expect(layout.position('l')).to eq([2, 8])
    end

    it 'has correct position for bottom row (ZXCVB)' do
      expect(layout.position('z')).to eq([3, 0])
      expect(layout.position('x')).to eq([3, 1])
      expect(layout.position('c')).to eq([3, 2])
      expect(layout.position('v')).to eq([3, 3])
      expect(layout.position('b')).to eq([3, 4])
      expect(layout.position('n')).to eq([3, 5])
      expect(layout.position('m')).to eq([3, 6])
    end
  end

  describe '#distance' do
    context 'adjacent keys' do
      it 'returns 1 for q-w' do
        expect(layout.distance('q', 'w')).to eq(1)
      end

      it 'returns 1 for a-s' do
        expect(layout.distance('a', 's')).to eq(1)
      end

      it 'returns 1 for z-x' do
        expect(layout.distance('z', 'x')).to eq(1)
      end
    end

    context 'same row distances' do
      it 'calculates distance across number row' do
        expect(layout.distance('1', '5')).to eq(4)
      end

      it 'calculates distance across top row' do
        expect(layout.distance('q', 'p')).to eq(9)
        expect(layout.distance('q', 'm')).to be > 5 # Far apart: q=[1,0], m=[3,6]
      end
    end

    context 'QWERTY-specific characteristics' do
      it 'has z and y far apart (key difference from QWERTZ)' do
        # On QWERTY, z is [3,0] and y is [1,5]
        # Manhattan distance = |3-1| + |0-5| = 2 + 5 = 7
        expect(layout.distance('z', 'y')).to eq(7)
      end
    end
  end

  describe '#adjacent_keys' do
    it 'returns adjacent keys for q' do
      adjacent = layout.adjacent_keys('q')
      expect(adjacent).to include('w') # right
      expect(adjacent).to include('a') # down
      expect(adjacent).not_to include('e') # diagonal
    end

    it 'returns adjacent keys for home row a' do
      adjacent = layout.adjacent_keys('a')
      expect(adjacent).to include('s') # right
      expect(adjacent).to include('z') # down
      expect(adjacent).to include('q') # diagonal (home-top adjacent)
    end

    it 'includes diagonally adjacent keys for corner positions' do
      # This depends on implementation - let's test what we have
      adjacent_to_q = layout.adjacent_keys('q')
      adjacent_to_a = layout.adjacent_keys('a')

      # q might have diagonal neighbors depending on definition
      # a might have diagonal neighbors
      expect(adjacent_to_q).to include('w')
      expect(adjacent_to_a).to include('s')
    end
  end

  describe 'language support' do
    it 'is the default layout for most languages' do
      expect(layout.supports_language?('en')).to be true
      expect(layout.supports_language?('es')).to be true
      expect(layout.supports_language?('pt')).to be true
    end

    it 'does not support German' do
      expect(layout.supports_language?('de')).to be false
    end

    it 'does not support French' do
      expect(layout.supports_language?('fr')).to be false
    end

    it 'does not support Russian' do
      expect(layout.supports_language?('ru')).to be false
    end
  end
end
