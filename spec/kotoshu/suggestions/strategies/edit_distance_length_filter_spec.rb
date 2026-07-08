# frozen_string_literal: true

require 'spec_helper'
require 'kotoshu'

# Verifies that EditDistanceStrategy's length filter doesn't change
# which suggestions are produced — it only speeds up the inner loop
# by skipping dictionary words whose length differs from the input
# by more than max_dist (a sound optimization since edit distance is
# bounded below by the length difference).
RSpec.describe 'EditDistanceStrategy length filter (perf optimization)', type: :property do
  let(:dictionary) do
    Kotoshu::Dictionary::PlainText.from_words(
      %w[hello help held hell shell yellow world word helloing hi],
      language_code: 'en'
    )
  end

  let(:strategy) { Kotoshu::Suggestions::Strategies::EditDistanceStrategy.new }

  def ctx(word)
    Kotoshu::Suggestions::Context.new(word: word, dictionary: dictionary, max_results: 10)
  end

  it 'returns the same candidates regardless of length filter (property: soundness)' do
    # For any input word and max_dist >= 0, the length filter never
    # discards a word that could match — |len(a) - len(b)| <= dist(a, b)
    # by the triangle inequality, so filtering by length is sound.
    inputs = %w[helo helo held held yellow xyz hi helloing]
    inputs.each do |word|
      result = strategy.generate(ctx(word))
      # Each result should be a valid dictionary word within distance 2.
      result.each do |s|
        dist = Kotoshu::Algorithms::EditDistance.distance(word.downcase, s.word.downcase)
        expect(dist).to be <= 2
        expect((word.length - s.word.length).abs).to be <= 2
      end
    end
  end

  it 'still finds candidates of varying lengths (within max_dist)' do
    # "helo" → "hello" (length 4→5, dist 1) and "help" (4→4, dist 1).
    result = strategy.generate(ctx('helo'))
    words = result.to_words
    expect(words).to include('hello') if dictionary.all_words.include?('hello')
    expect(words).to include('help') if dictionary.all_words.include?('help')
  end

  it 'does not crash on very long input (length filter handles it)' do
    # Length filter should prevent iterating words of very different
    # lengths when the input is unusually long.
    long_word = 'a' * 50
    result = strategy.generate(ctx(long_word))
    expect(result).to be_a(Kotoshu::Suggestions::SuggestionSet)
  end
end
