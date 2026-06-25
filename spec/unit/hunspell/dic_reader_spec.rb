# frozen_string_literal: true

RSpec.describe 'Unit: Hunspell DIC Reader' do
  describe '#load' do
    it 'loads a simple DIC file' do
      reader = Kotoshu::Readers::DicReader.new(unit_fixture('simple.dic'))
      words = reader.read

      expect(words.length).to eq(2)
      expect(words[0].stem).to eq('cat')
      expect(words[0].flags).to be_empty
      expect(words[1].stem).to eq('dog')
      expect(words[1].flags).to contain_exactly('S', 'M')
    end

    it 'handles encoding' do
      reader = Kotoshu::Readers::DicReader.new(
        unit_fixture('windows-1251.dic'),
        encoding: 'Windows-1251'
      )
      words = reader.read

      expect(words.length).to eq(1)
      expect(words[0].stem).to eq('кот')
      expect(words[0].flags).to contain_exactly('S', 'M')
    end

    it 'handles long flag format' do
      reader = Kotoshu::Readers::DicReader.new(
        unit_fixture('long_flags.dic'),
        flag_format: 'long'
      )
      words = reader.read

      expect(words.length).to eq(2)
      expect(words[0].stem).to eq('cat')
      expect(words[0].flags).to be_empty
      expect(words[1].stem).to eq('dog')
      expect(words[1].flags).to contain_exactly('So', 'Mx')
    end
  end
end
