# frozen_string_literal: true

require_relative '../../../../lib/kotoshu/keyboard'

RSpec.describe Kotoshu::Keyboard::Layouts::Dvorak do
  subject(:layout) { described_class.new }

  describe '#initialize' do
    it 'creates Dvorak layout' do
      expect(layout.name).to eq('Dvorak')
    end

    it 'supports English (alternative layout)' do
      expect(layout.supports_language?('en')).to be true
      expect(layout.supports_language?('en-US')).to be true
    end
  end

  describe '#position' do
    context 'Dvorak-specific: vowels on home row left' do
      it 'places a, o, e, u, i on home row left' do
        expect(layout.position('a')).to eq([2, 0])
        expect(layout.position('o')).to eq([2, 1])
        expect(layout.position('e')).to eq([2, 2])
        expect(layout.position('u')).to eq([2, 3])
        expect(layout.position('i')).to eq([2, 4])
      end
    end

    context 'Dvorak-specific: high-frequency consonants on home row right' do
      it 'places d, h, t, n, s on home row right' do
        expect(layout.position('d')).to eq([2, 5])
        expect(layout.position('h')).to eq([2, 6])
        expect(layout.position('t')).to eq([2, 7])
        expect(layout.position('n')).to eq([2, 8])
        expect(layout.position('s')).to eq([2, 9])
      end
    end
  end

  describe '#distance' do
    context 'Dvorak-specific characteristics' do
      it 'has vowels close together on home row' do
        expect(layout.distance('a', 'o')).to eq(1)
        expect(layout.distance('o', 'e')).to eq(1)
        expect(layout.distance('e', 'u')).to eq(1)
      end

      it 'has home row optimized for typing efficiency' do
        # Most common letters should be on home row (row 2)
        home_row_keys = %w[a o e u d h t n s]
        home_row_keys.each do |key|
          position = layout.position(key)
          expect(position).to be_a(Array)
          expect(position.first).to eq(2), "#{key} should be on home row"
        end
      end
    end
  end

  describe 'English language support' do
    it 'supports English as alternative layout' do
      expect(layout.supports_language?('en')).to be true
    end

    it 'is not the default for English (QWERTY is)' do
      # QWERTY is returned by default for 'en'
      qwerty = Kotoshu::Keyboard::Registry.layout_for('en')
      expect(qwerty.name).to eq('QWERTY')
    end
  end

  describe 'layout efficiency' do
    it 'places punctuation on top row for easy access' do
      expect(layout.position("'")).to eq([1, 0])  # Single quote
      expect(layout.position(',')).to eq([1, 1])  # Comma
      expect(layout.position('.')).to eq([1, 2])  # Period
    end
  end
end
