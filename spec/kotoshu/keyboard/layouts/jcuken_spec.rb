# frozen_string_literal: true

require_relative '../../../../lib/kotoshu/keyboard'

RSpec.describe Kotoshu::Keyboard::Layouts::JCUKEN do
  subject(:layout) { described_class.new }

  describe '#initialize' do
    it 'creates JCUKEN layout' do
      expect(layout.name).to eq('JCUKEN')
    end

    it 'supports Russian and variants' do
      expect(layout.supports_language?('ru')).to be true
      expect(layout.supports_language?('ru-RU')).to be true
    end

    it 'supports Ukrainian (uk)' do
      expect(layout.supports_language?('uk')).to be true
    end

    it 'supports Belarusian (be)' do
      expect(layout.supports_language?('be')).to be true
    end

    it 'supports Bulgarian (bg)' do
      expect(layout.supports_language?('bg')).to be true
    end
  end

  describe '#position' do
    it 'has correct position for Cyrillic letters' do
      expect(layout.position('й')).to eq([1, 0])  # J
      expect(layout.position('ц')).to eq([1, 1])  # C
      expect(layout.position('у')).to eq([1, 2])  # U
      expect(layout.position('к')).to eq([1, 3])  # K
      expect(layout.position('е')).to eq([1, 4])  # E
      expect(layout.position('н')).to eq([1, 5])  # N
    end

    it 'has correct position for ё (yo) in number row' do
      expect(layout.position('ё')).to eq([0, 0])
    end

    it 'has hard and soft signs' do
      expect(layout.position('ъ')).to eq([1, 11]) # Hard sign
      expect(layout.position('ь')).to eq([3, 6]) # Soft sign
    end
  end

  describe '#distance' do
    context 'JCUKEN-specific characteristics' do
      it 'measures distance correctly for Cyrillic' do
        # й=[1,0] to ц=[1,1] = 1
        expect(layout.distance('й', 'ц')).to eq(1)
        # й=[1,0] to у=[1,2] = 2
        expect(layout.distance('й', 'у')).to eq(2)
      end
    end
  end

  describe 'Russian language support' do
    it 'is the default layout for Russian' do
      expect(layout.supports_language?('ru')).to be true
    end

    it 'does not support Latin languages' do
      expect(layout.supports_language?('en')).to be false
      expect(layout.supports_language?('de')).to be false
      expect(layout.supports_language?('fr')).to be false
    end
  end

  describe 'Cyrillic character support' do
    it 'includes all Russian letters' do
      russian_letters = 'йцукенгшщзхъфывапролджэячсмитьбю'.chars
      russian_letters.each do |letter|
        position = layout.position(letter)
        expect(position).to be_a(Array), "Letter #{letter} should have a position"
        expect(position.size).to eq(2), "Position for #{letter} should be [row, col]"
      end
    end

    it 'has ё separate from е' do
      expect(layout.position('ё')).to eq([0, 0])
      expect(layout.position('е')).to eq([1, 4])
    end
  end
end
