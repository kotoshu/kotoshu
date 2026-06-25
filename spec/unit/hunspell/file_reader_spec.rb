# frozen_string_literal: true

RSpec.describe 'Unit: Hunspell FileReader' do
  include SpyllsTestHelper

  describe '#lines' do
    it 'reads lines from a basic UTF-8 file' do
      reader = Kotoshu::Readers::FileReader.new(unit_fixture('basic-utf8.txt'))
      result = reader.to_a
      # The actual fixture file contains comment lines which are read as-is
      expect(result).to eq([[1, 'line'], [3, '# empty, too'], [4, 'content # comment']])
    end
  end

  describe '#encodings' do
    it 'handles Windows-1251 encoding' do
      reader = Kotoshu::Readers::FileReader.new(unit_fixture('basic-win1251.txt'), 'Windows-1251')
      line_no, line = reader.next
      expect(line).to eq('set Windows-1251')
      expect(line_no).to eq(1)

      reader.reset_encoding('Windows-1251')
      # After reset_encoding, the file position is reset to the beginning
      # So we get all lines including the first one
      result = reader.to_a
      expect(result).to eq([[1, 'set Windows-1251'], [2, 'раз'], [3, 'два']])
    end
  end

  describe '#stringio' do
    it 'reads from a string' do
      content = <<~TEXT
        line

          # empty, too
          content # comment
      TEXT

      reader = Kotoshu::Readers::StringReader.new(content)
      result = reader.to_a
      # The file reader keeps all non-empty lines including comments
      expect(result).to eq([[1, 'line'], [3, '# empty, too'], [4, 'content # comment']])
    end
  end

  describe '#bom' do
    it 'handles UTF-8 BOM' do
      reader = Kotoshu::Readers::FileReader.new(unit_fixture('utf8_bom.txt'))
      result = reader.to_a
      # The actual fixture file contains a comment line after BOM
      expect(result).to eq([[1, 'SET UTF-8'], [3, '# removing byte order mark from affix file']])
    end
  end
end
