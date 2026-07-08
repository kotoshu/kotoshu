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

        expect(errors.none? { |e| e[:rule_id] == "EN_A_VS_AN" }).to be true
      end

      it 'accepts "a dog"' do
        tokens = [
          { token: 'a', pos_tag: 'DET', position: 0, length: 1 },
          { token: 'dog', pos_tag: 'NOUN', position: 2, length: 3 }
        ]

        errors = rule_engine.check(tokens)

        expect(errors.none? { |e| e[:rule_id] == "EN_A_VS_AN" }).to be true
      end

      it 'handles "a one-time" correctly' do
        tokens = [
          { token: 'a', pos_tag: 'DET', position: 0, length: 1 },
          { token: 'one', pos_tag: 'NUM', position: 2, length: 3 }
        ]

        errors = rule_engine.check(tokens)

        expect(errors.none? { |e| e[:rule_id] == "EN_A_VS_AN" }).to be true
      end

      it 'handles "an hour" correctly' do
        tokens = [
          { token: 'an', pos_tag: 'DET', position: 0, length: 2 },
          { token: 'hour', pos_tag: 'NOUN', position: 3, length: 4 }
        ]

        errors = rule_engine.check(tokens)

        expect(errors.none? { |e| e[:rule_id] == "EN_A_VS_AN" }).to be true
      end

      it 'handles "a university" correctly' do
        tokens = [
          { token: 'a', pos_tag: 'DET', position: 0, length: 1 },
          { token: 'university', pos_tag: 'NOUN', position: 2, length: 10 }
        ]

        errors = rule_engine.check(tokens)

        expect(errors.none? { |e| e[:rule_id] == "EN_A_VS_AN" }).to be true
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

        expect(errors.none? { |e| e[:rule_id] == "EN_DOUBLE_NEGATIVE" }).to be true
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

        expect(errors.none? { |e| e[:rule_id] == "EN_THERE_THEIR" }).to be true
      end

      it 'accepts "there are"' do
        tokens = [
          { token: 'there', position: 0, length: 5 },
          { token: 'are', pos_tag: 'VERB', position: 6, length: 3 }
        ]

        errors = rule_engine.check(tokens)

        expect(errors.none? { |e| e[:rule_id] == "EN_THERE_THEIR" }).to be true
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

  describe 'Phrase confusion rules (EN_*_OF)' do
    describe '#check' do
      it 'detects "could of" and suggests "could have"' do
        tokens = [
          { token: 'I', position: 0, length: 1 },
          { token: 'could', position: 2, length: 5 },
          { token: 'of', position: 8, length: 2 },
          { token: 'gone', position: 11, length: 4 }
        ]
        errors = rule_engine.check(tokens)
        of_errors = errors.select { |e| e[:rule_id] == 'EN_COULD_OF' }
        expect(of_errors).not_to be_empty
        expect(of_errors.first[:suggestion]).to eq('could have')
      end

      it 'detects "should of"' do
        tokens = [
          { token: 'You', position: 0, length: 3 },
          { token: 'should', position: 4, length: 6 },
          { token: 'of', position: 11, length: 2 },
          { token: 'called', position: 14, length: 6 }
        ]
        errors = rule_engine.check(tokens)
        expect(errors.any? { |e| e[:rule_id] == 'EN_SHOULD_OF' }).to be true
      end

      it 'detects "would of"' do
        tokens = [
          { token: 'It', position: 0, length: 2 },
          { token: 'would', position: 3, length: 5 },
          { token: 'of', position: 9, length: 2 },
          { token: 'worked', position: 12, length: 6 }
        ]
        errors = rule_engine.check(tokens)
        expect(errors.any? { |e| e[:rule_id] == 'EN_WOULD_OF' }).to be true
      end

      it 'detects "must of" and "might of"' do
        tokens = [
          { token: 'She', position: 0, length: 3 },
          { token: 'must', position: 4, length: 4 },
          { token: 'of', position: 9, length: 2 },
          { token: 'left', position: 12, length: 4 },
          { token: 'They', position: 17, length: 4 },
          { token: 'might', position: 22, length: 5 },
          { token: 'of', position: 28, length: 2 },
          { token: 'arrived', position: 31, length: 7 }
        ]
        errors = rule_engine.check(tokens)
        ids = errors.map { |e| e[:rule_id] }
        expect(ids).to include('EN_MUST_OF', 'EN_MIGHT_OF')
      end

      it 'does not flag "could have"' do
        tokens = [
          { token: 'I', position: 0, length: 1 },
          { token: 'could', position: 2, length: 5 },
          { token: 'have', position: 8, length: 4 },
          { token: 'gone', position: 13, length: 4 }
        ]
        errors = rule_engine.check(tokens)
        expect(errors.none? { |e| e[:rule_id] == 'EN_COULD_OF' }).to be true
      end
    end

    describe 'rule loading' do
      it 'loads all five phrase-confusion rules' do
        %w[EN_COULD_OF EN_SHOULD_OF EN_WOULD_OF EN_MUST_OF EN_MIGHT_OF].each do |id|
          expect(rule_engine.rule_exists?(id)).to be true
        end
      end
    end
  end

  describe 'Possessive / contraction rules (TODO 51 Phase 1)' do
    describe 'EN_ITS_IT_S rule' do
      it 'flags "its cold" (should be "it\'s cold")' do
        tokens = [
          { token: 'its', pos_tag: 'PRON', position: 0, length: 3 },
          { token: 'cold', pos_tag: 'ADJ', position: 4, length: 4 }
        ]
        errors = rule_engine.check(tokens)
        expect(errors.any? { |e| e[:rule_id] == 'EN_ITS_IT_S' }).to be true
      end

      it 'flags "its been" (should be "it\'s been")' do
        tokens = [
          { token: 'its', pos_tag: 'PRON', position: 0, length: 3 },
          { token: 'been', pos_tag: 'VERB', position: 4, length: 4 }
        ]
        errors = rule_engine.check(tokens)
        expect(errors.any? { |e| e[:rule_id] == 'EN_ITS_IT_S' }).to be true
      end

      it 'does not flag "its color" (possessive is correct)' do
        tokens = [
          { token: 'its', pos_tag: 'PRON', position: 0, length: 3 },
          { token: 'color', pos_tag: 'NOUN', position: 4, length: 5 }
        ]
        errors = rule_engine.check(tokens)
        expect(errors.none? { |e| e[:rule_id] == 'EN_ITS_IT_S' }).to be true
      end
    end

    describe 'EN_YOUR_YOURE rule' do
      it 'flags "your going" (should be "you\'re going")' do
        tokens = [
          { token: 'your', pos_tag: 'PRON', position: 0, length: 4 },
          { token: 'going', pos_tag: 'VERB', position: 5, length: 5 }
        ]
        errors = rule_engine.check(tokens)
        expect(errors.any? { |e| e[:rule_id] == 'EN_YOUR_YOURE' }).to be true
      end

      it 'does not flag "your jacket" (possessive is correct)' do
        tokens = [
          { token: 'your', pos_tag: 'PRON', position: 0, length: 4 },
          { token: 'jacket', pos_tag: 'NOUN', position: 5, length: 6 }
        ]
        errors = rule_engine.check(tokens)
        expect(errors.none? { |e| e[:rule_id] == 'EN_YOUR_YOURE' }).to be true
      end
    end

    describe 'EN_WHOSE_WHOS rule' do
      it 'flags "whose coming" (should be "who\'s coming")' do
        tokens = [
          { token: 'whose', pos_tag: 'PRON', position: 0, length: 5 },
          { token: 'coming', pos_tag: 'VERB', position: 6, length: 6 }
        ]
        errors = rule_engine.check(tokens)
        expect(errors.any? { |e| e[:rule_id] == 'EN_WHOSE_WHOS' }).to be true
      end

      it 'does not flag "whose book" (possessive is correct)' do
        tokens = [
          { token: 'whose', pos_tag: 'PRON', position: 0, length: 5 },
          { token: 'book', pos_tag: 'NOUN', position: 6, length: 4 }
        ]
        errors = rule_engine.check(tokens)
        expect(errors.none? { |e| e[:rule_id] == 'EN_WHOSE_WHOS' }).to be true
      end
    end

    describe 'rule loading' do
      it 'loads all three possessive/contraction rules' do
        %w[EN_ITS_IT_S EN_YOUR_YOURE EN_WHOSE_WHOS].each do |id|
          expect(rule_engine.rule_exists?(id)).to be true
        end
      end
    end
  end

  describe 'Capitalization rules (TODO 51 Phase 3)' do
    describe 'EN_SENTENCE_START_CAP rule' do
      it 'flags a lowercase first word of a stream' do
        tokens = [
          { token: 'hello', pos_tag: 'X', position: 0, length: 5 }
        ]
        errors = rule_engine.check(tokens)
        expect(errors.any? { |e| e[:rule_id] == 'EN_SENTENCE_START_CAP' }).to be true
      end

      it 'does not flag a capitalized first word' do
        tokens = [
          { token: 'Hello', pos_tag: 'X', position: 0, length: 5 }
        ]
        errors = rule_engine.check(tokens)
        expect(errors.none? { |e| e[:rule_id] == 'EN_SENTENCE_START_CAP' }).to be true
      end

      it 'flags a lowercase word after a period' do
        tokens = [
          { token: 'Hello.', pos_tag: 'X', position: 0, length: 6 },
          { token: 'world', pos_tag: 'X', position: 7, length: 5 }
        ]
        errors = rule_engine.check(tokens)
        capital_errors = errors.select { |e| e[:rule_id] == 'EN_SENTENCE_START_CAP' }
        expect(capital_errors.length).to eq(1)
        expect(capital_errors.first[:position]).to eq(7)
      end

      it 'flags lowercase sentence starts across multiple sentences' do
        tokens = [
          { token: 'Go.', pos_tag: 'X', position: 0, length: 3 },
          { token: 'now.', pos_tag: 'X', position: 4, length: 4 },
          { token: 'hurry', pos_tag: 'X', position: 9, length: 5 }
        ]
        errors = rule_engine.check(tokens)
        capital_errors = errors.select { |e| e[:rule_id] == 'EN_SENTENCE_START_CAP' }
        expect(capital_errors.length).to eq(2)
      end

      it 'suggests the capitalized form' do
        tokens = [
          { token: 'hello', pos_tag: 'X', position: 0, length: 5 }
        ]
        errors = rule_engine.check(tokens)
        capital_error = errors.find { |e| e[:rule_id] == 'EN_SENTENCE_START_CAP' }
        expect(capital_error[:suggestion]).to eq('Hello')
      end
    end

    describe 'EN_PROPER_NOUN_CAP rule' do
      it 'flags "monday" and suggests "Monday"' do
        tokens = [{ token: 'monday', pos_tag: 'NOUN', position: 0, length: 6 }]
        errors = rule_engine.check(tokens)
        proper_errors = errors.select { |e| e[:rule_id] == 'EN_PROPER_NOUN_CAP' }
        expect(proper_errors.length).to eq(1)
        expect(proper_errors.first[:suggestion]).to eq('Monday')
      end

      it 'flags "english" and suggests "English"' do
        tokens = [{ token: 'english', pos_tag: 'NOUN', position: 0, length: 7 }]
        errors = rule_engine.check(tokens)
        expect(errors.any? { |e| e[:rule_id] == 'EN_PROPER_NOUN_CAP' && e[:suggestion] == 'English' }).to be true
      end

      it 'does NOT flag "Monday" (already capitalized)' do
        tokens = [{ token: 'Monday', pos_tag: 'NOUN', position: 0, length: 6 }]
        errors = rule_engine.check(tokens)
        expect(errors.none? { |e| e[:rule_id] == 'EN_PROPER_NOUN_CAP' }).to be true
      end

      it 'does NOT flag common nouns like "apple"' do
        tokens = [{ token: 'apple', pos_tag: 'NOUN', position: 0, length: 5 }]
        errors = rule_engine.check(tokens)
        expect(errors.none? { |e| e[:rule_id] == 'EN_PROPER_NOUN_CAP' }).to be true
      end

      it 'flags multiple proper nouns in a stream' do
        tokens = [
          { token: 'monday', pos_tag: 'NOUN', position: 0, length: 6 },
          { token: 'is', pos_tag: 'VERB', position: 7, length: 2 },
          { token: 'january', pos_tag: 'NOUN', position: 10, length: 7 }
        ]
        errors = rule_engine.check(tokens)
        proper_errors = errors.select { |e| e[:rule_id] == 'EN_PROPER_NOUN_CAP' }
        expect(proper_errors.length).to eq(2)
      end
    end
  end

  describe 'Confusion-phrase rules (TODO 51 Phase 2 subset)' do
    describe 'then/than phrases' do
      it 'flags "more then" → "more than"' do
        tokens = [
          { token: 'more', position: 0, length: 4 },
          { token: 'then', position: 5, length: 4 }
        ]
        errors = rule_engine.check(tokens)
        expect(errors.any? { |e| e[:rule_id] == 'EN_MORE_THEN' }).to be true
      end

      it 'flags "less then" → "less than"' do
        tokens = [
          { token: 'less', position: 0, length: 4 },
          { token: 'then', position: 5, length: 4 }
        ]
        errors = rule_engine.check(tokens)
        expect(errors.any? { |e| e[:rule_id] == 'EN_LESS_THEN' }).to be true
      end

      it 'flags "rather then" → "rather than"' do
        tokens = [
          { token: 'rather', position: 0, length: 6 },
          { token: 'then', position: 7, length: 4 }
        ]
        errors = rule_engine.check(tokens)
        expect(errors.any? { |e| e[:rule_id] == 'EN_RATHER_THEN' }).to be true
      end

      it 'flags "other then" → "other than"' do
        tokens = [
          { token: 'other', position: 0, length: 5 },
          { token: 'then', position: 6, length: 4 }
        ]
        errors = rule_engine.check(tokens)
        expect(errors.any? { |e| e[:rule_id] == 'EN_OTHER_THEN' }).to be true
      end

      it 'does NOT flag "more than" (correct usage)' do
        tokens = [
          { token: 'more', position: 0, length: 4 },
          { token: 'than', position: 5, length: 4 }
        ]
        errors = rule_engine.check(tokens)
        expect(errors.none? { |e| e[:rule_id] == 'EN_MORE_THEN' }).to be true
      end
    end

    describe 'common phrase confusions' do
      it 'flags "could care less" → "couldn\'t care less"' do
        tokens = [
          { token: 'could', position: 0, length: 5 },
          { token: 'care', position: 6, length: 4 },
          { token: 'less', position: 11, length: 4 }
        ]
        errors = rule_engine.check(tokens)
        expect(errors.any? { |e| e[:rule_id] == 'EN_COULD_CARE_LESS' }).to be true
      end

      it 'flags "for free" → "free"' do
        tokens = [
          { token: 'for', position: 0, length: 3 },
          { token: 'free', position: 4, length: 4 }
        ]
        errors = rule_engine.check(tokens)
        expect(errors.any? { |e| e[:rule_id] == 'EN_FOR_FREE' }).to be true
      end

      it 'flags "alot" → "a lot"' do
        tokens = [
          { token: 'alot', position: 0, length: 4 }
        ]
        errors = rule_engine.check(tokens)
        expect(errors.any? { |e| e[:rule_id] == 'EN_ALOT' }).to be true
      end
    end

    describe 'rule loading' do
      it 'loads all seven confusion-phrase rules' do
        %w[EN_MORE_THEN EN_LESS_THEN EN_RATHER_THEN EN_OTHER_THEN EN_COULD_CARE_LESS EN_FOR_FREE EN_ALOT].each do |id|
          expect(rule_engine.rule_exists?(id)).to be true
        end
      end
    end
  end
end
