# frozen_string_literal: true

require_relative '../../../lib/kotoshu/keyboard'

RSpec.describe Kotoshu::Keyboard::Layout do
  # Test double for Layout to test abstract class behavior
  class TestLayout < described_class
    TEST_POSITIONS = {
      'a' => [0, 0], 'b' => [0, 1], 'c' => [1, 0],
      'd' => [1, 1], 'e' => [2, 0]
    }.freeze

    def initialize
      super(
        name: 'TestLayout',
        language_codes: %w[test],
        key_positions: TEST_POSITIONS
      )
    end
  end

  describe '#initialize' do
    it 'stores the layout name' do
      layout = TestLayout.new
      expect(layout.name).to eq('TestLayout')
    end

    it 'stores language codes' do
      layout = TestLayout.new
      expect(layout.language_codes).to eq(%w[test])
    end

    it 'freezes key_positions' do
      layout = TestLayout.new
      expect(layout.key_positions).to be_frozen
    end

    it 'freezes language_codes' do
      layout = TestLayout.new
      expect(layout.language_codes).to be_frozen
    end
  end

  describe '#position' do
    it 'returns position for existing key' do
      layout = TestLayout.new
      expect(layout.position('a')).to eq([0, 0])
      expect(layout.position('c')).to eq([1, 0])
    end

    it 'returns nil for non-existent key' do
      layout = TestLayout.new
      expect(layout.position('z')).to be_nil
    end

    it 'handles lowercase lookup' do
      layout = TestLayout.new
      expect(layout.position('A')).to eq([0, 0]) # Same as 'a'
      expect(layout.position('B')).to eq([0, 1]) # Same as 'b'
    end
  end

  describe '#distance' do
    it 'returns 0 for same key' do
      layout = TestLayout.new
      expect(layout.distance('a', 'a')).to eq(0)
    end

    it 'returns 1 for adjacent keys (horizontal)' do
      layout = TestLayout.new
      expect(layout.distance('a', 'b')).to eq(1) # [0,0] to [0,1]
    end

    it 'returns 1 for adjacent keys (vertical)' do
      layout = TestLayout.new
      expect(layout.distance('a', 'c')).to eq(1) # [0,0] to [1,0]
    end

    it 'returns 2 for diagonal keys' do
      layout = TestLayout.new
      expect(layout.distance('a', 'd')).to eq(2) # [0,0] to [1,1]
    end

    it 'returns Manhattan distance for distant keys' do
      layout = TestLayout.new
      expect(layout.distance('a', 'e')).to eq(2) # [0,0] to [2,0]
      expect(layout.distance('b', 'c')).to eq(2) # [0,1] to [1,0]
    end

    it 'returns Float::INFINITY for unknown keys' do
      layout = TestLayout.new
      expect(layout.distance('a', 'z')).to eq(Float::INFINITY)
      expect(layout.distance('z', 'a')).to eq(Float::INFINITY)
    end

    it 'handles case insensitivity' do
      layout = TestLayout.new
      expect(layout.distance('A', 'b')).to eq(1)
      expect(layout.distance('a', 'B')).to eq(1)
    end
  end

  describe '#supports_language?' do
    it 'returns true for supported language' do
      layout = TestLayout.new
      expect(layout.supports_language?('test')).to be true
    end

    it 'returns false for unsupported language' do
      layout = TestLayout.new
      expect(layout.supports_language?('en')).to be false
    end

    it 'handles case sensitivity' do
      layout = TestLayout.new
      expect(layout.supports_language?('TEST')).to be false # Exact match
    end
  end

  describe '#adjacent_keys' do
    it 'returns horizontally adjacent keys' do
      layout = TestLayout.new
      adjacent_to_a = layout.adjacent_keys('a')
      expect(adjacent_to_a).to include('b') # [0,1] is adjacent
    end

    it 'returns vertically adjacent keys' do
      layout = TestLayout.new
      adjacent_to_a = layout.adjacent_keys('a')
      expect(adjacent_to_a).to include('c') # [1,0] is adjacent
    end

    it 'does not include the key itself' do
      layout = TestLayout.new
      adjacent_to_a = layout.adjacent_keys('a')
      expect(adjacent_to_a).not_to include('a')
    end

    it 'returns empty array for unknown key' do
      layout = TestLayout.new
      adjacent_to_z = layout.adjacent_keys('z')
      expect(adjacent_to_z).to eq([])
    end
  end

  describe '#to_s' do
    it 'returns class name representation' do
      layout = TestLayout.new
      expect(layout.to_s).to eq('Keyboard::TestLayout')
    end
  end

  describe '#inspect' do
    it 'includes name and languages' do
      layout = TestLayout.new
      inspection = layout.inspect
      expect(inspection).to include('TestLayout')
      expect(inspection).to include('test')
    end
  end

  describe 'edge cases' do
    it 'handles empty key_positions' do
      empty_layout_class = Class.new(Kotoshu::Keyboard::Layout) do
        def initialize
          super(
            name: 'EmptyLayout',
            language_codes: [],
            key_positions: {}
          )
        end
      end

      layout = empty_layout_class.new
      expect(layout.position('a')).to be_nil
      expect(layout.distance('a', 'b')).to eq(Float::INFINITY)
      expect(layout.adjacent_keys('a')).to eq([])
    end

    it 'handles single key layout' do
      single_layout_class = Class.new(Kotoshu::Keyboard::Layout) do
        def initialize
          super(
            name: 'SingleLayout',
            language_codes: %w[test],
            key_positions: { 'x' => [5, 5] }
          )
        end
      end

      layout = single_layout_class.new
      expect(layout.position('x')).to eq([5, 5])
      expect(layout.adjacent_keys('x')).to eq([])
    end
  end
end
