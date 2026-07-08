# frozen_string_literal: true

require 'spec_helper'
require 'kotoshu/grammar'

# Direct spec for the PossessiveContractionMatcher — the data-driven
# pattern matcher that powers EN_ITS_IT_S, EN_YOUR_YOURE, and
# EN_WHOSE_WHOS (TODO 51 Phase 1).
RSpec.describe Kotoshu::Grammar::PatternMatchers::PossessiveContractionMatcher do
  let(:pattern) do
    {
      'context' => {
        'target_token' => 'its',
        'trigger_when_followed_by' => {
          'tags' => %w[ADJ ADV],
          'words' => %w[been going]
        }
      },
      'conditions' => [{ 'type' => 'possessive_contraction_check' }]
    }
  end

  let(:rule) do
    Kotoshu::Grammar::Rule.new(
      id: 'EN_TEST', name: 'test', category: :confusion, severity: :warning,
      description: '', message: 'msg', suggestion: 'it\'s',
      patterns: [pattern],
      exceptions: {}
    )
  end

  let(:matcher) { described_class.new(pattern, {}) }

  def token(word, pos, position = 0)
    { token: word, pos_tag: pos, position: position, length: word.length }
  end

  it 'emits an error when target is followed by a trigger tag' do
    tokens = [token('its', 'PRON'), token('cold', 'ADJ', 4)]
    errors = matcher.match(tokens, rule)
    expect(errors.length).to eq(1)
    expect(errors.first[:suggestion]).to eq("it's")
    expect(errors.first[:position]).to eq(0)
  end

  it 'emits an error when target is followed by a trigger word' do
    tokens = [token('its', 'PRON'), token('been', 'VERB', 4)]
    errors = matcher.match(tokens, rule)
    expect(errors.length).to eq(1)
  end

  it 'does not emit when the target is followed by a non-trigger token' do
    tokens = [token('its', 'PRON'), token('color', 'NOUN', 4)]
    expect(matcher.match(tokens, rule)).to be_empty
  end

  it 'does not emit when the target token is absent' do
    tokens = [token('the', 'DET'), token('cold', 'ADJ', 4)]
    expect(matcher.match(tokens, rule)).to be_empty
  end

  it 'handles case-insensitively (Its/ITS match target "its")' do
    tokens = [token('Its', 'PRON'), token('cold', 'ADJ', 4)]
    expect(matcher.match(tokens, rule).length).to eq(1)
  end

  it 'does not emit when target is the last token' do
    tokens = [token('its', 'PRON')]
    expect(matcher.match(tokens, rule)).to be_empty
  end

  it 'emits once per occurrence (multiple "its" in stream)' do
    tokens = [
      token('its', 'PRON'),
      token('cold', 'ADJ', 4),
      token('today', 'ADV', 9),
      token('its', 'PRON', 15),
      token('been', 'VERB', 20)
    ]
    expect(matcher.match(tokens, rule).length).to eq(2)
  end
end
