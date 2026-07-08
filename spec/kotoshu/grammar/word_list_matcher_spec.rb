# frozen_string_literal: true

require 'spec_helper'
require 'kotoshu/grammar'

# Direct spec for WordListMatcher — powers EN_PROPER_NOUN_CAP
# (TODO 51 Phase 3).
RSpec.describe Kotoshu::Grammar::PatternMatchers::WordListMatcher do
  let(:pattern) do
    {
      'conditions' => [{
        'type' => 'word_list_check',
        'corrections' => {
          'monday' => 'Monday',
          'english' => 'English'
        }
      }]
    }
  end

  let(:rule) do
    Kotoshu::Grammar::Rule.new(
      id: 'EN_TEST', name: 'test', category: :capitalization, severity: :error,
      description: '', message: 'Capitalize', suggestion: 'Capitalize',
      patterns: [pattern], exceptions: {}
    )
  end

  let(:matcher) { described_class.new(pattern, {}) }

  def token(word, position = 0)
    { token: word, position: position, length: word.length }
  end

  it 'flags a lowercase proper noun and suggests the correction' do
    errors = matcher.match([token('monday')], rule)
    expect(errors.length).to eq(1)
    expect(errors.first[:suggestion]).to eq('Monday')
  end

  it 'does NOT flag the already-capitalized form' do
    expect(matcher.match([token('Monday')], rule)).to be_empty
  end

  it 'flags case-insensitively (MONDAY matches)' do
    errors = matcher.match([token('MONDAY')], rule)
    expect(errors.length).to eq(1)
    expect(errors.first[:suggestion]).to eq('Monday')
  end

  it 'does not flag words not in the corrections map' do
    expect(matcher.match([token('hello')], rule)).to be_empty
  end

  it 'flags multiple occurrences in a stream' do
    tokens = [
      token('monday', 0),
      token('is', 7),
      token('english', 10)
    ]
    errors = matcher.match(tokens, rule)
    expect(errors.length).to eq(2)
    expect(errors.first[:position]).to eq(0)
    expect(errors.last[:position]).to eq(10)
  end

  it 'returns no errors when the corrections map is empty' do
    empty_pattern = { 'conditions' => [{ 'type' => 'word_list_check', 'corrections' => {} }] }
    matcher = described_class.new(empty_pattern, {})
    expect(matcher.match([token('monday')], rule)).to be_empty
  end

  it 'returns no errors when the word_list_check condition is absent' do
    no_condition_pattern = { 'conditions' => [] }
    matcher = described_class.new(no_condition_pattern, {})
    expect(matcher.match([token('monday')], rule)).to be_empty
  end
end
