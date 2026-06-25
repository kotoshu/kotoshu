# frozen_string_literal: true

RSpec.describe 'Unit: Hunspell read_aff' do
  describe '#directives' do
    def read_aff_string(content)
      reader = Kotoshu::Readers::AffReader.new('')
      source = Kotoshu::Readers::StringReader.new(content)
      allow(reader).to receive(:path).and_return('')
      reader.read
    end

    it 'parses REP directive' do
      aff_content = <<~AFF
        REP 5
        REP ^Ca$ Ça
        REP ^l l'
        REP ^d d'
        REP ^n n'
        REP ^s s'
      AFF

      result = read_aff_string(aff_content)
      expect(result['REP']).to be_an(Array)
      expect(result['REP'].length).to eq(5)
      expect(result['REP'][0].pattern).to eq('^Ca$')
      expect(result['REP'][0].replacement).to eq('Ça')
      expect(result['REP'][1].pattern).to eq('^l')
      expect(result['REP'][1].replacement).to eq("l'")
    end

    it 'parses MAP directive' do
      aff_content = <<~AFF
        MAP 3
        MAP uúü
        MAP öóo
        MAP ß(ss)
      AFF

      result = read_aff_string(aff_content)
      expect(result['MAP']).to be_an(Array)
      expect(result['MAP'].length).to eq(3)
      expect(result['MAP'][0]).to contain_exactly('u', 'ú', 'ü')
      expect(result['MAP'][1]).to contain_exactly('ö', 'ó', 'o')
      expect(result['MAP'][2]).to contain_exactly('ß', 'ss')
    end

    it 'parses PFX directive' do
      aff_content = <<~AFF
        PFX A Y 1
        PFX A 0 re .
      AFF

      result = read_aff_string(aff_content)
      expect(result['PFX']).to be_a(Hash)
      expect(result['PFX']['A']).to be_an(Array)
      expect(result['PFX']['A'].length).to eq(1)
      expect(result['PFX']['A'][0].add).to eq('re')
    end
  end

  describe '#long_flags' do
    it 'parses long flag format' do
      aff_content = <<~AFF
        FLAG long

        SFX zx Y 1
        SFX zx 0 s/g?1G09 .

        NOSUGGEST 1G

        AF 2
        AF AB
        AF BC
      AFF

      result = read_aff_string(aff_content)
      expect(result['FLAG']).to eq('long')
      expect(result['SFX']['zx'][0].flag).to eq('zx')
      expect(result['SFX']['zx'][0].flags).to contain_exactly('g?', '1G', '09')
      expect(result['NOSUGGEST']).to eq('1G')
      expect(result['AF']['1']).to contain_exactly('A', 'B')
      expect(result['AF']['2']).to contain_exactly('B', 'C')
    end
  end

  describe '#numeric_flags' do
    it 'parses numeric flag format' do
      aff_content = <<~AFF
        FLAG num

        SFX 999 Y 1
        SFX 999 0 s/214,216,54321 .

        NOSUGGEST 348
      AFF

      result = read_aff_string(aff_content)
      expect(result['FLAG']).to eq('num')
      expect(result['SFX']['999'][0].flag).to eq('999')
      expect(result['SFX']['999'][0].flags).to contain_exactly('214', '216', '54321')
      expect(result['NOSUGGEST']).to eq('348')
    end
  end

  describe '#utf_flags' do
    it 'parses UTF-8 flag format' do
      aff_content = <<~AFF
        FLAG UTF-8

        SFX A Y 1
        SFX A 0 s/ÖüÜ .

        NOSUGGEST ю
      AFF

      result = read_aff_string(aff_content)
      expect(result['FLAG']).to eq('UTF-8')
      expect(result['SFX']['A'][0].flag).to eq('A')
      expect(result['SFX']['A'][0].flags).to contain_exactly('Ö', 'ü', 'Ü')
      expect(result['NOSUGGEST']).to eq('ю')
    end
  end

  describe '#flag_aliases' do
    it 'parses flag aliases (AF directive)' do
      aff_content = <<~AFF
        AF 2
        AF AB
        AF BC

        SFX z Y 1
        SFX z 0 s/1 .
      AFF

      result = read_aff_string(aff_content)
      expect(result['SFX']['z'][0].flags).to contain_exactly('A', 'B')
    end
  end
end
