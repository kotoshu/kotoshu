# frozen_string_literal: true

require 'spec_helper'
require 'kotoshu/languages/en/language'
require 'kotoshu/grammar'

RSpec.describe Kotoshu::Grammar::RuleEngine do
  let(:rule_engine) { Kotoshu::Grammar::RuleEngine.new(language: 'en') }

  describe 'EN_A_VS_AN rule' do
    describe '#check' do
      it 'detects "a elephant" (should be "an elephant")' do
        tokens = [
          { token: 'a', pos_tag: 'DET', position: 0, length: 1 },
          { token: 'elephant', pos_tag: 'NOUN', position: 2, length: 8 }
        ]

        errors = rule_engine.check(tokens)

        expect(errors).not_to be_empty
        expect(errors.first[:suggestion]).to eq('an')
        expect(errors.first[:rule_id]).to eq('EN_A_VS_AN')
      end

      it 'detects "an dog" (should be "a dog")' do
        tokens = [
          { token: 'an', pos_tag: 'DET', position: 0, length: 2 },
          { token: 'dog', pos_tag: 'NOUN', position: 3, length: 3 }
        ]

        errors = rule_engine.check(tokens)

        expect(errors).not_to be_empty
        expect(errors.first[:suggestion]).to eq('a')
        expect(errors.first[:rule_id]).to eq('EN_A_VS_AN')
      end

      it 'accepts "an elephant"' do
        tokens = [
          { token: 'an', pos_tag: 'DET', position: 0, length: 2 },
          { token: 'elephant', pos_tag: 'NOUN', position: 3, length: 8 }
        ]

        errors = rule_engine.check(tokens)

        expect(errors).to be_empty
      end

      it 'accepts "a dog"' do
        tokens = [
          { token: 'a', pos_tag: 'DET', position: 0, length: 1 },
          { token: 'dog', pos_tag: 'NOUN', position: 2, length: 3 }
        ]

        errors = rule_engine.check(tokens)

        expect(errors).to be_empty
      end

      it 'handles "a one-time" correctly' do
        tokens = [
          { token: 'a', pos_tag: 'DET', position: 0, length: 1 },
          { token: 'one', pos_tag: 'NUM', position: 2, length: 3 }
        ]

        errors = rule_engine.check(tokens)

        expect(errors).to be_empty
      end

      it 'handles "an hour" correctly' do
        tokens = [
          { token: 'an', pos_tag: 'DET', position: 0, length: 2 },
          { token: 'hour', pos_tag: 'NOUN', position: 3, length: 4 }
        ]

        errors = rule_engine.check(tokens)

        expect(errors).to be_empty
      end

      it 'handles "a university" correctly' do
        tokens = [
          { token: 'a', pos_tag: 'DET', position: 0, length: 1 },
          { token: 'university', pos_tag: 'NOUN', position: 2, length: 10 }
        ]

        errors = rule_engine.check(tokens)

        expect(errors).to be_empty
      end
    end
  end

  describe 'EN_DOUBLE_NEGATIVE rule' do
    describe '#check' do
      it 'detects "I don\'t know nothing"' do
        tokens = [
          { token: 'I', position: 0, length: 1 },
          { token: 'don\'t', position: 2, length: 5 },
          { token: 'know', position: 8, length: 4 },
          { token: 'nothing', position: 13, length: 7 }
        ]

        errors = rule_engine.check(tokens)

        expect(errors).not_to be_empty
        expect(errors.any? { |e| e[:rule_id] == 'EN_DOUBLE_NEGATIVE' }).to be true
      end

      it 'does not flag "I don\'t know anything"' do
        tokens = [
          { token: 'I', position: 0, length: 1 },
          { token: 'don\'t', position: 2, length: 5 },
          { token: 'know', position: 8, length: 4 },
          { token: 'anything', position: 13, length: 8 }
        ]

        errors = rule_engine.check(tokens)

        expect(errors).to be_empty
      end

      it 'handles "not only... but also" correctly' do
        tokens = [
          { token: 'not', position: 0, length: 3 },
          { token: 'only', position: 4, length: 4 },
          { token: 'but', position: 9, length: 3 },
          { token: 'also', position: 13, length: 4 }
        ]

        errors = rule_engine.check(tokens)

        expect(errors).to be_empty
      end

      it 'finds double negatives within reasonable distance' do
        tokens = [
          { token: 'I', position: 0, length: 1 },
          { token: 'never', position: 2, length: 5 },
          { token: 'go', position: 8, length: 2 },
          { token: 'nowhere', position: 11, length: 7 }
        ]

        errors = rule_engine.check(tokens)

        expect(errors.any? { |e| e[:rule_id] == 'EN_DOUBLE_NEGATIVE' }).to be true
      end

      it 'does not flag distant negatives' do
        tokens = [
          { token: 'I', position: 0, length: 1 },
          { token: 'not', position: 2, length: 3 },
          { token: 'say', position: 6, length: 3 },
          { token: 'anything', position: 10, length: 8 },
          { token: 'never', position: 19, length: 5 }
        ]

        errors = rule_engine.check(tokens)

        # Distance is too large (19 - 2 = 17 > 15)
        expect(errors).to be_empty
      end
    end
  end

  describe 'EN_THERE_THEIR rule' do
    describe '#check' do
      it 'detects "there parents" (should be "their parents")' do
        tokens = [
          { token: 'there', position: 0, length: 5 },
          { token: 'parents', pos_tag: 'NOUN', position: 6, length: 8 }
        ]

        errors = rule_engine.check(tokens)

        expect(errors.any? { |e| e[:rule_id] == 'EN_THERE_THEIR' }).to be true
      end

      it 'accepts "there is" (location/existence)' do
        tokens = [
          { token: 'there', position: 0, length: 5 },
          { token: 'is', pos_tag: 'VERB', position: 6, length: 2 }
        ]

        errors = rule_engine.check(tokens)

        expect(errors).to be_empty
      end

      it 'accepts "there are"' do
        tokens = [
          { token: 'there', position: 0, length: 5 },
          { token: 'are', pos_tag: 'VERB', position: 6, length: 3 }
        ]

        errors = rule_engine.check(tokens)

        expect(errors).to be_empty
      end
    end
  end

  describe 'RuleEngine' do
    it 'loads rules from YAML configuration' do
      expect(rule_engine.rules).not_to be_empty
    end

    it 'returns rule IDs' do
      rule_names = rule_engine.rule_names

      expect(rule_names).to include('EN_A_VS_AN')
      expect(rule_names).to include('EN_THERE_THEIR')
      expect(rule_names).to include('EN_DOUBLE_NEGATIVE')
    end

    it 'can get specific rule by ID' do
      rule = rule_engine.get_rule('EN_A_VS_AN')

      expect(rule).not_to be_nil
      expect(rule.id).to eq('EN_A_VS_AN')
    end

    it 'returns nil for unknown rule ID' do
      rule = rule_engine.get_rule('UNKNOWN')

      expect(rule).to be_nil
    end

    it 'checks if rule exists' do
      expect(rule_engine.rule_exists?('EN_A_VS_AN')).to be true
      expect(rule_engine.rule_exists?('UNKNOWN')).to be false
    end
  end

  describe 'English language class integration' do
    it 'provides create_grammar_rules method' do
      lang = Kotoshu::Languages::English.new
      engine = lang.create_grammar_rules

      expect(engine).to be_a(Kotoshu::Grammar::RuleEngine)
    end
  end
end
