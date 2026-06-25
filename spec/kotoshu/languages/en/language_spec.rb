# frozen_string_literal: true

require 'spec_helper'
require 'kotoshu/languages/en/language'

RSpec.describe Kotoshu::Languages::English do
  # Use the existing registered English class
  let(:english_us) { Kotoshu::Language.get('en-US')&.new || Kotoshu::Languages::English.new(code: 'en-US') }

  describe '#initialize' do
    it 'creates American English by default' do
      lang = described_class.new
      expect(lang.code).to eq('en')
    end

    it 'creates American English with en-US code' do
      lang = described_class.new(code: 'en-US')
      expect(lang.code).to eq('en-US')
      expect(lang.variant).to eq('US')
    end

    it 'creates British English with en-GB code' do
      lang = described_class.new(code: 'en-GB')
      expect(lang.code).to eq('en-GB')
      expect(lang.variant).to eq('GB')
    end
  end

  describe '#create_spell_checker' do
    it 'creates a Hunspell spell checker' do
      checker = english_us.create_spell_checker
      expect(checker).to be_a(Kotoshu::Languages::English::SpellChecker)
    end

    context 'with spell checking' do
      let(:checker) { english_us.create_spell_checker }

      it 'checks common words' do
        expect(checker.correct?('hello')).to be true
        expect(checker.correct?('world')).to be true
      end

      it 'detects misspelled words' do
        expect(checker.correct?('helo')).to be false
        expect(checker.correct?('wrld')).to be false
      end

      it 'provides suggestions for misspelled words' do
        suggestions = checker.suggest('helo')
        expect(suggestions).to be_an(Array)
        expect(suggestions.first).to include(:word)
      end
    end
  end

  describe '#create_tokenizer' do
    it 'creates an English tokenizer' do
      tokenizer = english_us.create_tokenizer
      expect(tokenizer).to be_a(Kotoshu::Languages::English::Tokenizer)
    end

    context 'with tokenization' do
      let(:tokenizer) { english_us.create_tokenizer }

      it 'tokenizes English text' do
        tokens = tokenizer.tokenize('Hello, world!')
        expect(tokens.map { |t| t[:token] }).to eq(['Hello', ',', 'world', '!'])
      end

      it 'handles contractions' do
        tokens = tokenizer.tokenize("I don't like it")
        expect(tokens.map { |t| t[:token] }).to include('do', 'n\'t')
      end
    end
  end

  describe '#create_pos_tagger' do
    it 'creates a Hunspell POS tagger' do
      tagger = english_us.create_pos_tagger
      expect(tagger).to be_a(Kotoshu::Languages::English::POSTagger)
    end

    context 'with POS tagging' do
      let(:tagger) { english_us.create_pos_tagger }

      it 'tags single words' do
        result = tagger.tag_word('hello')
        expect(result).to have_key(:pos_tag)
        expect(result).to have_key(:lemma)
      end
    end
  end

  describe '#valid_in_other_variant?' do
    # This would require multiple variant dictionaries
    # For now, we'll test that it returns nil when no other variants exist
    it 'returns nil for en-US when only en-US is available' do
      result = english_us.valid_in_other_variant?('colour')
      # Would return { variant: 'British', code: 'en-GB' } if en-GB existed
      expect(result).to be_nil
    end
  end

  describe '#description' do
    it 'returns full name with variant' do
      lang = described_class.new(code: 'en-US')
      expect(lang.description).to eq('English (American)')
    end

    it 'returns just name for base English' do
      lang = described_class.new(code: 'en')
      expect(lang.description).to eq('English')
    end
  end
end
