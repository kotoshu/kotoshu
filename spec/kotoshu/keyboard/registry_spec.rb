# frozen_string_literal: true

require_relative '../../../lib/kotoshu/keyboard'

RSpec.describe Kotoshu::Keyboard::Registry do
  describe '.layout_for' do
    it 'returns QWERTY for English (en)' do
      layout = described_class.layout_for('en')
      expect(layout).to be_a(Kotoshu::Keyboard::Layouts::QWERTY)
      expect(layout.name).to eq('QWERTY')
    end

    it 'returns QWERTY for Spanish (es)' do
      layout = described_class.layout_for('es')
      expect(layout).to be_a(Kotoshu::Keyboard::Layouts::QWERTY)
    end

    it 'returns QWERTY for Portuguese (pt)' do
      layout = described_class.layout_for('pt')
      expect(layout).to be_a(Kotoshu::Keyboard::Layouts::QWERTY)
    end

    it 'returns QWERTZ for German (de)' do
      layout = described_class.layout_for('de')
      expect(layout).to be_a(Kotoshu::Keyboard::Layouts::QWERTZ)
      expect(layout.name).to eq('QWERTZ')
    end

    it 'returns AZERTY for French (fr)' do
      layout = described_class.layout_for('fr')
      expect(layout).to be_a(Kotoshu::Keyboard::Layouts::AZERTY)
      expect(layout.name).to eq('AZERTY')
    end

    it 'returns JCUKEN for Russian (ru)' do
      layout = described_class.layout_for('ru')
      expect(layout).to be_a(Kotoshu::Keyboard::Layouts::JCUKEN)
      expect(layout.name).to eq('JCUKEN')
    end

    it 'returns base language layout for variants' do
      # en-GB should use same layout as en
      layout = described_class.layout_for('en-GB')
      expect(layout).to be_a(Kotoshu::Keyboard::Layouts::QWERTY)
    end

    it 'returns QWERTY as fallback for unknown language' do
      layout = described_class.layout_for('unknown-language-code')
      expect(layout).to be_a(Kotoshu::Keyboard::Layouts::QWERTY)
    end
  end

  describe '.layout_by_name' do
    it 'returns QWERTY when requested by name' do
      layout = described_class.layout_by_name('QWERTY')
      expect(layout).to be_a(Kotoshu::Keyboard::Layouts::QWERTY)
    end

    it 'returns QWERTZ when requested by name' do
      layout = described_class.layout_by_name('QWERTZ')
      expect(layout).to be_a(Kotoshu::Keyboard::Layouts::QWERTZ)
    end

    it 'returns AZERTY when requested by name' do
      layout = described_class.layout_by_name('AZERTY')
      expect(layout).to be_a(Kotoshu::Keyboard::Layouts::AZERTY)
    end

    it 'returns JCUKEN when requested by name' do
      layout = described_class.layout_by_name('JCUKEN')
      expect(layout).to be_a(Kotoshu::Keyboard::Layouts::JCUKEN)
    end

    it 'returns Dvorak when requested by name' do
      layout = described_class.layout_by_name('Dvorak')
      expect(layout).to be_a(Kotoshu::Keyboard::Layouts::Dvorak)
    end

    it 'handles symbol input' do
      layout = described_class.layout_by_name(:qwerty)
      expect(layout).to be_a(Kotoshu::Keyboard::Layouts::QWERTY)
    end

    it 'returns QWERTY as fallback for unknown name' do
      layout = described_class.layout_by_name('UnknownLayout')
      expect(layout).to be_a(Kotoshu::Keyboard::Layouts::QWERTY)
    end
  end

  describe '.available_layouts' do
    it 'returns all registered layouts' do
      layouts = described_class.available_layouts
      expect(layouts.size).to eq(5) # QWERTY, QWERTZ, AZERTY, JCUKEN, Dvorak
    end

    it 'returns layout instances' do
      layouts = described_class.available_layouts
      expect(layouts).to all(be_a(Kotoshu::Keyboard::Layout))
    end

    it 'includes all expected layouts' do
      layouts = described_class.available_layouts
      layout_names = layouts.map(&:name).sort
      expect(layout_names).to eq(%w[AZERTY Dvorak JCUKEN QWERTY QWERTZ])
    end
  end

  describe '.supported_languages' do
    it 'returns all supported language codes' do
      languages = described_class.supported_languages
      expect(languages).to include('en', 'de', 'fr', 'ru', 'es', 'pt')
    end

    it 'returns unique languages' do
      languages = described_class.supported_languages
      expect(languages.uniq.size).to eq(languages.size)
    end

    it 'returns sorted list' do
      languages = described_class.supported_languages
      expect(languages).to eq(languages.sort)
    end
  end

  describe '.supports_language?' do
    it 'returns true for English' do
      expect(described_class.supports_language?('en')).to be true
    end

    it 'returns true for German' do
      expect(described_class.supports_language?('de')).to be true
    end

    it 'returns true for French' do
      expect(described_class.supports_language?('fr')).to be true
    end

    it 'returns true for Russian' do
      expect(described_class.supports_language?('ru')).to be true
    end

    it 'returns true for Spanish' do
      expect(described_class.supports_language?('es')).to be true
    end

    it 'returns true for Portuguese' do
      expect(described_class.supports_language?('pt')).to be true
    end

    it 'returns false for unsupported language' do
      expect(described_class.supports_language?('zh')).to be false
      expect(described_class.supports_language?('ja')).to be false
      expect(described_class.supports_language?('ko')).to be false
    end
  end

  describe 'language-to-layout mapping' do
    it 'maps German to QWERTZ (z/y swap)' do
      layout = described_class.layout_for('de')
      expect(layout.name).to eq('QWERTZ')
      # On QWERTY, distance('z', 'y') is 7 (far apart)
      # On QWERTZ, distance('z', 'y') should also be large (they're just swapped)
      qwerty_z_y = described_class.layout_by_name('QWERTY').distance('z', 'y')
      qwertz_z_y = layout.distance('z', 'y')
      # Both should have same distance since positions are just swapped
      expect(qwerty_z_y).to eq(qwertz_z_y)
    end

    it 'maps French to AZERTY (a/q, z/w swap)' do
      layout = described_class.layout_for('fr')
      expect(layout.name).to eq('AZERTY')
    end

    it 'maps Russian to JCUKEN (Cyrillic)' do
      layout = described_class.layout_for('ru')
      expect(layout.name).to eq('JCUKEN')
    end
  end

  describe 'registry behavior' do
    it 'auto-registers all layouts on load' do
      # Verify all layouts are registered
      expect(described_class.layout_by_name('QWERTY')).to be_a(Kotoshu::Keyboard::Layouts::QWERTY)
      expect(described_class.layout_by_name('QWERTZ')).to be_a(Kotoshu::Keyboard::Layouts::QWERTZ)
      expect(described_class.layout_by_name('AZERTY')).to be_a(Kotoshu::Keyboard::Layouts::AZERTY)
      expect(described_class.layout_by_name('JCUKEN')).to be_a(Kotoshu::Keyboard::Layouts::JCUKEN)
      expect(described_class.layout_by_name('Dvorak')).to be_a(Kotoshu::Keyboard::Layouts::Dvorak)
    end

    it 'returns same instance for layout_by_name' do
      layout1 = described_class.layout_by_name('QWERTY')
      layout2 = described_class.layout_by_name('QWERTY')
      expect(layout1.object_id).to eq(layout2.object_id)
    end

    it 'returns same instance for layout_for' do
      layout1 = described_class.layout_for('en')
      layout2 = described_class.layout_for('en')
      expect(layout1.object_id).to eq(layout2.object_id)
    end
  end
end
