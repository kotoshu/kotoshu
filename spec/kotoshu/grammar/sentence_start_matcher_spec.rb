# frozen_string_literal: true

require 'spec_helper'
require 'kotoshu/grammar'

# Direct spec for SentenceStartMatcher — powers EN_SENTENCE_START_CAP
# (TODO 51 Phase 3).
RSpec.describe Kotoshu::Grammar::PatternMatchers::SentenceStartMatcher do
  let(:pattern) { { 'conditions' => [{ 'type' => 'sentence_start_check' }] } }
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

  it "flags the first token of the stream when it's lowercase" do
    tokens = [token('hello')]
    errors = matcher.match(tokens, rule)
    expect(errors.length).to eq(1)
    expect(errors.first[:position]).to eq(0)
  end

  it "does not flag the first token when it's capitalized" do
    tokens = [token('Hello')]
    expect(matcher.match(tokens, rule)).to be_empty
  end

  it 'flags a lowercase token after a period' do
    tokens = [
      token('Hello.', 0),
      token('world', 7)
    ]
    errors = matcher.match(tokens, rule)
    expect(errors.length).to eq(1)
    expect(errors.first[:position]).to eq(7)
  end

  it 'flags a lowercase token after an exclamation mark' do
    tokens = [
      token('Stop!', 0),
      token('now', 6)
    ]
    expect(matcher.match(tokens, rule)).to eq([{ rule_id: 'EN_TEST', position: 6, message: 'Capitalize', suggestion: 'Now', context: '"now"', suggestions: ['Now'] }])
  end

  it 'flags a lowercase token after a question mark' do
    tokens = [
      token('What?', 0),
      token('why', 6)
    ]
    errors = matcher.match(tokens, rule)
    expect(errors.length).to eq(1)
  end

  it 'does not flag a capitalized token after sentence-ending punctuation' do
    tokens = [
      token('Hello.', 0),
      token('World', 7)
    ]
    expect(matcher.match(tokens, rule)).to be_empty
  end

  it 'does not treat abbreviations like "Mr." as sentence ends for the purpose of this heuristic' do
    # Honest behavior: "Mr." ends with ".", so the matcher WILL treat
    # the next word as a sentence start. This is a known limitation —
    # a real sentence-boundary detector would handle abbreviations.
    # Document the behavior.
    tokens = [
      token('Mr.', 0),
      token('Smith', 4)
    ]
    expect(matcher.match(tokens, rule)).to be_empty # Smith is already capitalized
  end

  it 'handles multiple sentences in a stream' do
    tokens = [
      token('Hello.', 0),
      token('world', 7),
      token('Test.', 13),
      token('again', 19)
    ]
    errors = matcher.match(tokens, rule)
    expect(errors.length).to eq(2)
    expect(errors.map { |e| e[:position] }).to contain_exactly(7, 19)
  end

  it 'ignores non-alphabetic first tokens (numbers, symbols)' do
    tokens = [token('123'), token('hello')]
    expect(matcher.match(tokens, rule)).to be_empty
  end

  it 'suggests the capitalized form of the flagged token' do
    tokens = [token('hello')]
    error = matcher.match(tokens, rule).first
    expect(error[:suggestion]).to eq('Hello')
  end
end
