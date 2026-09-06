# frozen_string_literal: true

require_relative '../../../../lib/kotoshu/suggestions/strategies/edit_distance_strategy'
require_relative '../../../../lib/kotoshu/suggestions/context'
require_relative '../../../../lib/kotoshu/dictionary/hunspell'
require_relative '../../../../lib/kotoshu/dictionary/plain_text'

# The edit-sweep path of EditDistanceStrategy: single-edit candidates
# (adjacent transposition, substitution, insertion, deletion) validated
# against the full dictionary lookup, so affixed and capitalization
# forms that are not dictionary stems can be suggested.
#
# Uses real dictionaries only (a real Hunspell fixture with a TRY
# string and a productive -ly suffix, and real PlainText dictionaries).
RSpec.describe 'EditDistanceStrategy edit sweep' do
  let(:fixture_base) { File.expand_path('../../../fixtures/dictionaries/hunspell/sweep', __dir__) }

  let(:dictionary) do
    Kotoshu::Dictionary::Hunspell.new(
      dic_path: "#{fixture_base}.dic", aff_path: "#{fixture_base}.aff",
      language_code: 'en'
    )
  end

  let(:strategy_class) { Kotoshu::Suggestions::Strategies::EditDistanceStrategy }

  def suggestions_for(word, dictionary: self.dictionary, **config)
    strategy = strategy_class.new(**config)
    context = Kotoshu::Suggestions::Context.new(word: word, dictionary: dictionary)
    strategy.generate(context).suggestions.map(&:word)
  end

  describe 'adjacent transposition (restricted Damerau, cost 1)' do
    it 'suggests the capitalization form "The" for "Teh" first' do
      expect(dictionary.lookup('The')).to be(true)
      expect(suggestions_for('Teh').first).to eq('The')
    end

    it 'suggests "receive" for "recieve"' do
      expect(suggestions_for('recieve').first).to eq('receive')
    end

    it 'suggests "world" for "wrold"' do
      expect(suggestions_for('wrold').first).to eq('world')
    end
  end

  describe 'substitution over the TRY string' do
    it 'suggests the suffix form "definitely" for "definately"' do
      # The fixture dictionary carries only the stem "definite/Y";
      # "definitely" is a valid lookup form but never a stem, so only
      # the edit sweep can surface it.
      expect(dictionary.words).not_to include('definitely')
      expect(dictionary.lookup('definitely')).to be(true)
      expect(suggestions_for('definately').first).to eq('definitely')
    end

    it 'skips substitutions when no TRY alphabet is available' do
      # An empty try_string config disables the substitution and
      # insertion alphabet; the suffix form "definitely" is reachable
      # only through the a -> i substitution, so nothing is suggested.
      expect(suggestions_for('definately', try_string: '')).to be_empty
    end

    it 'enumerates substitutions from an explicit try_string config' do
      expect(suggestions_for('definately', try_string: 'i')).to eq(['definitely'])
    end
  end

  describe 'insertion over the TRY string' do
    it 'suggests the suffix form "definitely" for "definitly"' do
      expect(dictionary.lookup('definitely')).to be(true)
      expect(suggestions_for('definitly').first).to eq('definitely')
    end
  end

  describe 'deletion' do
    it 'suggests the suffix form "definitely" for "definitelyy"' do
      expect(suggestions_for('definitelyy').first).to eq('definitely')
    end
  end

  describe 'case-variant deduplication' do
    it 'keeps only the best-scoring casing when stem and form both match' do
      # "Teh" finds both the stem "the" (headword path, distance 2:
      # case substitution plus transposition) and the INITCAP form
      # "The" (sweep path, distance 1). The sweep form wins and the
      # stem is not repeated alongside it.
      words = suggestions_for('Teh')
      expect(words).to include('The')
      expect(words).not_to include('the')
    end
  end

  describe 'dictionary TRY plumbing' do
    it 'exposes the TRY string on the Hunspell dictionary' do
      expect(dictionary.try_string).to eq('esianrtolcdugmphbyfvkwz')
    end

    it 'answers nil TRY on dictionaries without one' do
      plain = Kotoshu::Dictionary::PlainText.from_words(%w[hello], language_code: 'en')
      expect(plain.try_string).to be_nil
    end
  end

  describe 'Damerau distance across strategies' do
    it 'counts an adjacent transposition as one operation' do
      expect(Kotoshu::Algorithms::EditDistance.distance('teh', 'the')).to eq(1)
      expect(Kotoshu::Algorithms::EditDistance.distance('recieve', 'receive')).to eq(1)
    end
  end
end
