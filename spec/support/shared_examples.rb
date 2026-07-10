# frozen_string_literal: true

RSpec.shared_examples 'a language module' do
  it 'has a code' do
    expect(subject.code).to be_a(String)
    expect(subject.code).to match(/^[a-z]{2}$/)
  end

  it 'has a name' do
    expect(subject.name).to be_a(String)
    expect(subject.name).not_to be_empty
  end

  it 'has an identifier' do
    expect(subject.identifier).to be_a(String)
    expect(subject.identifier).not_to be_empty
  end

  it 'has a script type' do
    expect(subject.script_type).to be_in(%i[latin cjk rtl other])
  end

  it 'has a description' do
    expect(subject.description).to be_a(String)
    expect(subject.description).not_to be_empty
  end

  it 'can be converted to a string' do
    str = subject.to_s
    expect(str).to be_a(String)
    expect(str).not_to be_empty
  end

  it 'can be inspected' do
    inspect_str = subject.inspect
    expect(inspect_str).to include(subject.class.name)
  end

  it 'implements equality' do
    expect(subject).to eq(subject)
  end

  it 'has a hash value' do
    expect(subject.hash).to be_a(Integer)
  end
end

RSpec.shared_examples 'a tokenizer' do
  it 'tokenizes text' do
    result = subject.tokenize('hello world')
    expect(result).to be_an(Array)
    expect(result).not_to be_empty
  end

  it 'returns hashes with token, position, length' do
    result = subject.tokenize('hello')
    expect(result.first).to include(:token, :position, :length)
  end

  it 'can tokenize to strings' do
    result = subject.tokenize_to_strings('hello world')
    expect(result).to be_an(Array)
    expect(result).to all be_a(String)
  end

  it 'handles empty text' do
    result = subject.tokenize('')
    expect(result).to eq([])
  end

  it 'handles nil text' do
    result = subject.tokenize(nil)
    expect(result).to eq([])
  end

  it 'handles text with only whitespace' do
    result = subject.tokenize('   ')
    expect(result).to eq([])
  end
end

RSpec.shared_examples 'a spell checker' do
  it 'checks words' do
    result = subject.check('hello')
    expect(result).to include(:found)
  end

  it 'returns found flag as boolean' do
    result = subject.check('test')
    expect([true, false]).to include(result[:found])
  end

  it 'suggests corrections' do
    result = subject.suggest('test')
    expect(result).to be_an(Array)
  end

  it 'has a correct? convenience method' do
    expect(subject).to respond_to(:correct?)
  end

  it 'returns boolean from correct?' do
    result = subject.correct?('test')
    # For PassthroughSpellChecker, result is always true
    # For other spell checkers, result can be true or false
    expect([true, false]).to include(result)
  end
end

RSpec.shared_examples 'a POS tagger' do
  it 'tags tokens' do
    tokens = [{ token: 'test', position: 0, length: 4 }]
    result = subject.tag(tokens)
    expect(result).to be_an(Array)
    expect(result.length).to eq(tokens.length)
  end

  it 'adds pos_tag to tokens' do
    tokens = [{ token: 'test', position: 0, length: 4 }]
    result = subject.tag(tokens)
    expect(result.first).to have_key(:pos_tag)
  end

  it 'adds lemma to tokens' do
    tokens = [{ token: 'test', position: 0, length: 4 }]
    result = subject.tag(tokens)
    expect(result.first).to have_key(:lemma)
  end

  it 'handles empty token array' do
    result = subject.tag([])
    expect(result).to eq([])
  end

  it 'handles nil token array' do
    result = subject.tag(nil)
    expect(result).to eq([])
  end

  it 'can tag a single word' do
    result = subject.tag_word('test')
    expect(result).to be_a(Hash)
    expect(result).to have_key(:pos_tag)
    expect(result).to have_key(:lemma)
  end
end

# Shared examples for suggestion strategies
#
# These examples define the expected behavior for any suggestion strategy,
# regardless of the underlying algorithm (edit distance, n-gram, phonetic, etc.)
RSpec.shared_examples 'a suggestion strategy' do
  describe '#initialize' do
    it 'creates a strategy with a name' do
      expect(subject.name).to be_a(Symbol)
      expect(subject.name).not_to be_empty
    end

    it 'has a config hash' do
      expect(subject.config).to be_a(Hash)
    end

    it 'can be disabled' do
      disabled_strategy = described_class.new(enabled: false)
      expect(disabled_strategy.enabled?).to be false
    end

    it 'respects max_results config' do
      strategy = described_class.new(max_results: 5)
      expect(strategy.max_results).to eq(5)
    end
  end

  describe '#generate' do
    let(:strategy) { described_class.new(dictionary: dictionary) }

    it 'returns a SuggestionSet' do
      result = strategy.generate(context)
      expect(result).to be_a(Kotoshu::Suggestions::SuggestionSet)
    end

    it 'generates suggestions for misspelled words' do
      result = strategy.generate(context)
      expect(result.size).to be > 0
    end

    it 'returns suggestions sorted by relevance' do
      result = strategy.generate(context)
      suggestions = result.suggestions

      expect(suggestions).not_to be_empty

      # First suggestion should have highest confidence
      first_confidence = suggestions.first.confidence
      last_confidence = suggestions.last.confidence
      expect(first_confidence).to be >= last_confidence
    end

    it 'respects max_results configuration' do
      limited_strategy = described_class.new(dictionary: dictionary, max_results: 3)
      result = limited_strategy.generate(context)
      expect(result.size).to be <= 3
    end

    it 'handles case-insensitive matching' do
      upper_context = Kotoshu::Suggestions::Context.new(
        word: context.word.upcase,
        dictionary: dictionary
      )
      result = strategy.generate(upper_context)
      expect(result.size).to be > 0
    end

    context 'when word has no close matches' do
      let(:no_match_word) { 'supercalifragilisticexpialidocious' }
      let(:no_match_context) do
        Kotoshu::Suggestions::Context.new(word: no_match_word, dictionary: dictionary)
      end

      it 'returns empty suggestion set' do
        result = strategy.generate(no_match_context)
        expect(result.size).to be_zero
      end
    end
  end

  describe '#handles?' do
    let(:strategy) { described_class.new(dictionary: dictionary) }

    it 'returns true when word is not in dictionary' do
      expect(strategy.handles?(context)).to be true
    end

    it 'returns false when word is in dictionary' do
      valid_context = Kotoshu::Suggestions::Context.new(
        word: 'hello',
        dictionary: dictionary
      )
      expect(strategy.handles?(valid_context)).to be false
    end

    it 'returns false when strategy is disabled' do
      disabled_strategy = described_class.new(dictionary: dictionary, enabled: false)
      expect(disabled_strategy.handles?(context)).to be false
    end
  end

  describe '#enabled?' do
    it 'returns true by default' do
      strategy = described_class.new(dictionary: dictionary)
      expect(strategy.enabled?).to be true
    end

    it 'returns false when explicitly disabled' do
      strategy = described_class.new(dictionary: dictionary, enabled: false)
      expect(strategy.enabled?).to be false
    end
  end

  describe '#to_s' do
    it 'returns a string representation' do
      strategy = described_class.new(dictionary: dictionary)
      str = strategy.to_s
      expect(str).to be_a(String)
      expect(str).to include(described_class.name)
    end
  end

  describe '#inspect' do
    it 'returns an inspection string' do
      strategy = described_class.new(dictionary: dictionary)
      inspect_str = strategy.inspect
      expect(inspect_str).to be_a(String)
      expect(inspect_str).to include(described_class.name)
    end
  end
end

# Shared examples for edit distance calculation
#
# These examples test the core edit distance algorithm, which is
# language-agnostic and should work the same regardless of the
# keyboard layout or word frequency data.
RSpec.shared_examples 'an edit distance calculator' do
  let(:algorithm) { Kotoshu::Algorithms::EditDistance }

  describe '#edit_distance' do
    it 'calculates Levenshtein distance correctly' do
      # Identical words have distance 0
      expect(algorithm.distance('hello', 'hello')).to eq(0)

      # Single character difference
      expect(algorithm.distance('hello', 'hell')).to eq(1)
      expect(algorithm.distance('hello', 'hallo')).to eq(1)

      # Multiple character differences
      expect(algorithm.distance('hello', 'help')).to eq(2)
      expect(algorithm.distance('kitten', 'sitting')).to eq(3)
    end

    it 'handles empty strings' do
      expect(algorithm.distance('', 'hello')).to eq(5)
      expect(algorithm.distance('hello', '')).to eq(5)
      expect(algorithm.distance('', '')).to eq(0)
    end

    it 'handles transpositions correctly (Damerau-Levenshtein)' do
      # Transposition of adjacent characters counts as 1 operation
      expect(algorithm.distance('wrold', 'world')).to eq(1)
      expect(algorithm.distance('teh', 'the')).to eq(1)
    end

    it 'calculates distance for insertions' do
      expect(algorithm.distance('helo', 'hello')).to eq(1)
      expect(algorithm.distance('cat', 'coat')).to eq(1)
    end

    it 'calculates distance for deletions' do
      expect(algorithm.distance('hello', 'helo')).to eq(1)
      expect(algorithm.distance('book', 'boo')).to eq(1)
    end

    it 'calculates distance for substitutions' do
      expect(algorithm.distance('cat', 'cut')).to eq(1)
      expect(algorithm.distance('hello', 'hallo')).to eq(1)
    end
  end

  describe '#edit_distance_with_threshold' do
    it 'returns distance when within threshold' do
      result = algorithm.distance_with_threshold('hello', 'hallo', 2)
      expect(result).to eq(1)
    end

    it 'returns nil when exceeding threshold' do
      result = algorithm.distance_with_threshold('kitten', 'sitting', 2)
      expect(result).to be_nil
    end

    it 'returns 0 when threshold is 0 and words match' do
      result = algorithm.distance_with_threshold('hello', 'hello', 0)
      expect(result).to eq(0)
    end
  end
end

# Shared examples for typo pattern recognition
#
# These examples test the detection of common typo patterns,
# which vary by language but follow similar principles.
RSpec.shared_examples 'a typo pattern detector' do
  let(:strategy) { described_class.new(dictionary: dictionary) }

  describe '#typo_pattern_bonus' do
    context 'with missing double letters' do
      it 'detects missing double letter in middle of word' do
        # helo -> hello (missing second 'l')
        bonus = strategy.typo_pattern_bonus('helo', 'hello')
        expect(bonus).to be > 0
      end

      it 'detects missing double letter at end of word' do
        # see -> sees (missing 'e' is not a double letter pattern, but see -> see is)
        # Better example: wel -> well (missing second 'l' at end)
        bonus = strategy.typo_pattern_bonus('wel', 'well')
        expect(bonus).to be > 0
      end

      it 'does not give bonus when no double letter exists' do
        bonus = strategy.typo_pattern_bonus('hello', 'help')
        expect(bonus).to eq(0)
      end
    end

    context 'with extra double letters' do
      it 'detects extra double letter' do
        # hello -> helllo (extra 'l' inserted)
        bonus = strategy.typo_pattern_bonus('hello', 'helllo')
        expect(bonus).to be > 0
      end

      it 'does not give bonus for single deletions' do
        # hello -> hell is a deletion, not an extra double letter
        bonus = strategy.typo_pattern_bonus('hello', 'hell')
        expect(bonus).to eq(0)
      end
    end
  end

  describe '#transposition_bonus' do
    it 'detects single transposition' do
      # wrold -> world (r and o swapped)
      bonus = strategy.transposition_bonus('wrold', 'world')
      expect(bonus).to be > 0
    end

    it 'gives higher bonus for single transposition than multiple' do
      # Note: The transposition_bonus algorithm counts specific adjacent swap patterns.
      # A single adjacent swap gets 200 bonus.
      # Multiple swaps are counted differently (transpositions * 100).
      single_bonus = strategy.transposition_bonus('wrold', 'world')
      # 'ab' and 'ba' have no detected transpositions in this algorithm (too short)
      # Let's use a case where we get multiple transpositions
      multiple_bonus = strategy.transposition_bonus('wrodl', 'world')
      expect(single_bonus).to be >= multiple_bonus
    end

    it 'returns 0 when no transposition exists' do
      bonus = strategy.transposition_bonus('hello', 'help')
      expect(bonus).to eq(0)
    end
  end
end

# Shared examples for keyboard proximity detection
#
# These examples test the keyboard layout awareness, which varies
# significantly by language (QWERTY, QWERTZ, AZERTY, etc.).
RSpec.shared_examples 'a keyboard proximity detector' do
  let(:strategy) { described_class.new(dictionary: dictionary) }

  describe '#keyboard_penalty' do
    context 'with QWERTY layout' do
      it 'gives low penalty for adjacent key substitutions' do
        # o -> p substitution (adjacent on QWERTY)
        penalty = strategy.keyboard_penalty('helo', 'help')
        expect(penalty).to be < 100
      end

      it 'gives high penalty for distant key substitutions' do
        # a -> m substitution (far apart on keyboard)
        penalty = strategy.keyboard_penalty('cat', 'mat')
        expect(penalty).to be >= 100
      end

      it 'returns 0 when no substitutions exist' do
        penalty = strategy.keyboard_penalty('hello', 'hello')
        expect(penalty).to eq(0)
      end
    end
  end
end

# Contract for dictionaries whose contents can change after construction.
# Including contexts must define `build_dictionary(words)` returning a
# case-insensitive dictionary instance containing exactly +words+.
RSpec.shared_examples 'a mutable dictionary backend' do
  describe '#remove_word' do
    it 'removes exactly the requested word across sequential removals' do
      dict = build_dictionary(%w[apple berry cherry])

      expect(dict.remove_word('apple')).to be true
      expect(dict.remove_word('berry')).to be true

      expect(dict.words).to contain_exactly('cherry')
    end

    it 'keeps words and include? consistent when removing in reverse order' do
      dict = build_dictionary(%w[apple berry cherry])

      expect(dict.remove_word('cherry')).to be true
      expect(dict.remove_word('berry')).to be true

      expect(dict.words).to contain_exactly('apple')
      expect(dict.include?('apple')).to be true
      expect(dict.include?('berry')).to be false
      expect(dict.include?('cherry')).to be false
    end

    it 'returns false and leaves state untouched for an unknown word' do
      dict = build_dictionary(%w[apple berry])

      expect(dict.remove_word('durian')).to be false
      expect(dict.words).to contain_exactly('apple', 'berry')
    end

    it 'removes case-insensitively' do
      dict = build_dictionary(%w[apple])

      expect(dict.remove_word('Apple')).to be true
      expect(dict.include?('apple')).to be false
      expect(dict.words).to be_empty
    end

    it 'removes every duplicate copy of a word' do
      dict = build_dictionary(%w[apple apple berry])

      expect(dict.remove_word('apple')).to be true
      expect(dict.words).to contain_exactly('berry')
      expect(dict.include?('apple')).to be false
    end
  end

  describe '#find_by_length_range after mutation' do
    it 'includes words added after construction' do
      dict = build_dictionary(%w[cat dog])
      dict.add_word('bird')

      expect(dict.find_by_length_range(min_length: 4, max_length: 4))
        .to include('bird')
    end

    it 'excludes words removed after construction' do
      dict = build_dictionary(%w[cat dog bird])
      dict.remove_word('bird')

      expect(dict.find_by_length_range(min_length: 4, max_length: 4))
        .not_to include('bird')
    end
  end

  describe '#add_word after #remove_word' do
    it 're-adds a previously removed word' do
      dict = build_dictionary(%w[apple berry])
      dict.remove_word('apple')

      expect(dict.add_word('apple')).to be true
      expect(dict.include?('apple')).to be true
      expect(dict.words).to contain_exactly('apple', 'berry')
    end

    it 'stays consistent across interleaved add/remove sequences' do
      dict = build_dictionary(%w[alpha beta gamma delta])

      dict.remove_word('beta')
      dict.add_word('epsilon')
      dict.remove_word('delta')

      expect(dict.words).to contain_exactly('alpha', 'gamma', 'epsilon')
      %w[alpha gamma epsilon].each { |w| expect(dict.include?(w)).to be true }
      %w[beta delta].each { |w| expect(dict.include?(w)).to be false }
    end
  end
end
