# frozen_string_literal: true

require 'spec_helper'
require 'kotoshu/languages/en/language'
require 'kotoshu/components/whitespace_tokenizer'

RSpec.describe 'Foundation Component Integration' do
  # This spec demonstrates how the foundation components work together

  let(:aff_path) { File.expand_path('../integrational/fixtures/en_US.aff', __dir__) }
  let(:dic_path) { File.expand_path('../integrational/fixtures/en_US.dic', __dir__) }
  let(:fixtures_exist) { File.exist?(aff_path) && File.exist?(dic_path) }

  describe 'EnglishSpellChecker' do
    context 'when dictionary files exist' do
      before do
        skip 'Dictionary fixtures not found' unless fixtures_exist
      end

      let(:checker) do
        Kotoshu::Languages::English::SpellChecker.new(aff_path: aff_path, dic_path: dic_path, script: :latin)
      end

      it_behaves_like 'a spell checker' do
        subject { checker }
      end

      describe '#check' do
        it 'returns found: true for correct words' do
          result = checker.check('hello')

          expect(result[:found]).to be true
          expect(result[:stem]).to be_a(String)
          expect(result[:flags]).to be_an(Array)
        end

        it 'returns found: false for misspelled words' do
          result = checker.check('helo')

          expect(result[:found]).to be false
          expect(result[:stem]).to be_nil
        end
      end

      describe '#suggest' do
        it 'returns suggestions for misspelled words' do
          result = checker.suggest('helo')

          expect(result).to be_an(Array)
          expect(result.first).to include(:word, :distance, :score)
        end
      end

      describe '#correct?' do
        it 'returns true for correct words' do
          expect(checker.correct?('hello')).to be true
        end

        it 'returns false for misspelled words' do
          expect(checker.correct?('helo')).to be false
        end
      end
    end

    context 'when dictionary files do not exist' do
      it 'raises an error when creating checker' do
        expect do
          Kotoshu::Languages::English::SpellChecker.new(
            aff_path: '/nonexistent/file.aff',
            dic_path: '/nonexistent/file.dic'
          )
        end.to raise_error(Errno::ENOENT)
      end
    end
  end

  describe 'WhitespaceTokenizer' do
    let(:tokenizer) { Kotoshu::Components::WhitespaceTokenizer.new }

    it_behaves_like 'a tokenizer' do
      subject { tokenizer }
    end

    it 'can be used standalone' do
      tokens = tokenizer.tokenize("The quick brown fox")

      expect(tokens.map { |t| t[:token] }).to eq(['The', 'quick', 'brown', 'fox'])
    end
  end

  describe 'EnglishPosTagger' do
    context 'when dictionary files exist' do
      before do
        skip 'Dictionary fixtures not found' unless fixtures_exist
      end

      let(:tagger) do
        Kotoshu::Languages::English::POSTagger.new(
          aff_path: aff_path,
          dic_path: dic_path,
          script: :latin
        )
      end

      it_behaves_like 'a POS tagger' do
        subject { tagger }
      end

      it 'tags a single token' do
        result = tagger.tag_word('hello')

        expect(result).to have_key(:pos_tag)
        expect(result).to have_key(:lemma)
      end

      it 'caches lookup results' do
        tokens = [{ token: 'hello', position: 0, length: 5 }]

        # First call
        tagger.tag(tokens)

        # Second call should use cache
        expect { tagger.tag(tokens) }.not_to(change { tagger.instance_variable_get(:@lookup_cache).size })
      end
    end
  end

  describe 'Component Integration' do
    context 'when dictionary files exist' do
      before do
        skip 'Dictionary fixtures not found' unless fixtures_exist
      end

      let(:checker) do
        Kotoshu::Languages::English::SpellChecker.new(aff_path: aff_path, dic_path: dic_path, script: :latin)
      end

      let(:tokenizer) { Kotoshu::Components::WhitespaceTokenizer.new }

      let(:tagger) do
        Kotoshu::Languages::English::POSTagger.new(
          aff_path: aff_path,
          dic_path: dic_path,
          script: :latin
        )
      end

      it 'can tokenize, tag, and check text end-to-end' do
        text = 'The quick brown fox jump over the lazy dog'

        # Tokenize
        tokens = tokenizer.tokenize(text)
        expect(tokens).not_to be_empty

        # Tag
        tagged = tagger.tag(tokens)
        expect(tagged.first).to have_key(:pos_tag)

        # Check each word
        checked_words = tagged.map do |token|
          word = token[:token]
          result = checker.check(word)
          { word: word, correct: result[:found] }
        end

        expect(checked_words).to be_an(Array)
      end

      it 'finds misspelled words and suggests corrections' do
        text = 'The quik brown fox'

        # Tokenize
        tokens = tokenizer.tokenize(text)

        # Check each word
        misspelled = tokens.select do |token|
          word = token[:token]
          !checker.correct?(word)
        end

        expect(misspelled.map { |t| t[:token] }).to include('quik')

        # Get suggestions for misspelled word
        misspelled.each do |token|
          word = token[:token]
          suggestions = checker.suggest(word)

          expect(suggestions).to be_an(Array)
        end
      end
    end
  end
end
