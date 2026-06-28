# frozen_string_literal: true

RSpec.describe 'Integrational Lookup Tests', :integrational do
  include SpyllsTestHelper

  # Helper method for lookup that handles multi-word expressions
  def lookup_word(dictionary, word)
    result = dictionary.lookup(word)
    return result if result

    # For multi-word expressions, check if all words are valid
    if word.include?(' ')
      word.split(' ').all? { |w| dictionary.lookup(w) }
    else
      result
    end
  end

  # Run lookup tests for a given dictionary name
  def run_lookup_tests(name, pending_comment: nil)
    dictionary = read_dictionary(name)
    good = read_list("#{name}.good")
    bad = read_list("#{name}.wrong")

    # Track results
    good_failures = []
    bad_failures = []

    # Test good words
    good.each do |word|
      next if word.nil? || word.empty?

      result = lookup_word(dictionary, word)
      good_failures << word unless result
    end

    # Test bad words
    bad.each do |word|
      result = lookup_word(dictionary, word)
      bad_failures << word if result
    end

    {
      good_count: good.length,
      good_failures:,
      bad_count: bad.length,
      bad_failures:,
      pending_comment:
    }
  end

  # Base Tests
  describe 'Base' do
    it 'passes base lookup tests' do
      result = run_lookup_tests('base')
      expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
      expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
    end

    it 'passes base_utf lookup tests' do
      result = run_lookup_tests('base_utf')
      expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
      expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
    end
  end

  # Flag Tests
  describe 'Flags' do
    %w[flag flaglong flagnum flagutf8].each do |name|
      it "passes #{name} lookup tests" do
        result = run_lookup_tests(name)
        expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
        expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
      end
    end

    %w[alias alias2 alias3].each do |name|
      it "passes #{name} lookup tests" do
        result = run_lookup_tests(name)
        expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
        expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
      end
    end

    %w[encoding utf8 utf8_bom utf8_bom2 right_to_left_mark].each do |name|
      it "passes #{name} lookup tests" do
        result = run_lookup_tests(name)
        expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
        expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
      end
    end
  end

  # Affixes
  describe 'Affixes' do
    it 'passes affixes lookup tests' do
      result = run_lookup_tests('affixes')
      expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
      expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
    end

    %w[complexprefixes complexprefixes2 complexprefixesutf].each do |name|
      it "passes #{name} lookup tests" do
        result = run_lookup_tests(name)
        expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
        expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
      end
    end

    %w[condition condition_utf conditionalprefix].each do |name|
      it "passes #{name} lookup tests" do
        result = run_lookup_tests(name)
        expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
        expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
      end
    end

    it 'passes circumfix lookup tests' do
      result = run_lookup_tests('circumfix')
      expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
      expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
    end
  end

  # Need Affix
  describe 'Need Affix' do
    %w[needaffix needaffix2 needaffix3 needaffix4 needaffix5].each do |name|
      it "passes #{name} lookup tests" do
        result = run_lookup_tests(name)
        expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
        expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
      end
    end

    it 'passes fullstrip lookup tests' do
      result = run_lookup_tests('fullstrip')
      expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
      expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
    end

    it 'passes zeroaffix lookup tests' do
      result = run_lookup_tests('zeroaffix')
      expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
      expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
    end
  end

  # Exclusion Flags
  describe 'Exclusion Flags' do
    %w[allcaps allcaps2 allcaps3 allcaps_utf].each do |name|
      it "passes #{name} lookup tests" do
        result = run_lookup_tests(name)
        expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
        expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
      end
    end

    %w[forbiddenword keepcase nosuggest].each do |name|
      it "passes #{name} lookup tests" do
        result = run_lookup_tests(name)
        expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
        expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
      end
    end
  end

  # Break
  describe 'Break' do
    %w[breakdefault break breakoff].each do |name|
      it "passes #{name} lookup tests" do
        result = run_lookup_tests(name)
        expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
        expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
      end
    end
  end

  # Input/Output
  describe 'Input/Output' do
    %w[iconv iconv2 oconv oconv2].each do |name|
      it "passes #{name} lookup tests" do
        result = run_lookup_tests(name)
        expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
        expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
      end
    end
  end

  # Compounding
  describe 'Compounding' do
    %w[compoundflag onlyincompound].each do |name|
      it "passes #{name} lookup tests" do
        result = run_lookup_tests(name)
        expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
        expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
      end
    end

    it 'passes onlyincompound2 lookup tests', pending: 'replacement in pattern' do
      result = run_lookup_tests('onlyincompound2')
      expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
      expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
    end

    %w[compoundaffix compoundaffix2 compoundaffix3].each do |name|
      it "passes #{name} lookup tests" do
        result = run_lookup_tests(name)
        expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
        expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
      end
    end

    %w[compoundrule compoundrule2 compoundrule3 compoundrule4 compoundrule5 compoundrule6 compoundrule7
       compoundrule8].each do |name|
      it "passes #{name} lookup tests" do
        result = run_lookup_tests(name)
        expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
        expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
      end
    end

    %w[checkcompoundcase checkcompoundcase2 checkcompoundcaseutf checkcompounddup checkcompoundpattern].each do |name|
      it "passes #{name} lookup tests" do
        result = run_lookup_tests(name)
        expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
        expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
      end
    end

    %w[checkcompoundpattern2 checkcompoundpattern3 checkcompoundpattern4].each do |name|
      it "passes #{name} lookup tests", pending: 'replacement in pattern' do
        result = run_lookup_tests(name)
        expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
        expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
      end
    end

    %w[checkcompoundrep checkcompoundtriple compoundforbid simplifiedtriple wordpair forceucase
       utfcompound].each do |name|
      it "passes #{name} lookup tests" do
        result = run_lookup_tests(name)
        expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
        expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
      end
    end

    it 'passes fogemorpheme lookup tests' do
      result = run_lookup_tests('fogemorpheme')
      expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
      expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
    end

    %w[opentaal_cpdpat opentaal_cpdpat2 opentaal_forbiddenword1 opentaal_forbiddenword2].each do |name|
      it "passes #{name} lookup tests" do
        result = run_lookup_tests(name)
        expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
        expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
      end
    end
  end

  # Misc
  describe 'Misc' do
    it 'passes ngram_utf_fix lookup tests' do
      result = run_lookup_tests('ngram_utf_fix')
      expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
      expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
    end

    it 'passes opentaal_keepcase lookup tests' do
      result = run_lookup_tests('opentaal_keepcase')
      expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
      expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
    end

    it 'passes ph2 lookup tests' do
      result = run_lookup_tests('ph2')
      expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
      expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
    end

    it 'passes morph lookup tests' do
      result = run_lookup_tests('morph')
      expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
      expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
    end

    it 'passes utf8_nonbmp lookup tests' do
      result = run_lookup_tests('utf8_nonbmp')
      expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
      expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
    end

    it 'passes warn lookup tests' do
      result = run_lookup_tests('warn')
      expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
      expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
    end
  end

  # Specific Languages
  describe 'Specific Languages' do
    %w[ignore ignoresug ignoreutf].each do |name|
      it "passes #{name} lookup tests" do
        result = run_lookup_tests(name)
        expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
        expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
      end
    end

    %w[checksharps checksharpsutf].each do |name|
      it "passes #{name} lookup tests" do
        result = run_lookup_tests(name)
        expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
        expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
      end
    end

    %w[dotless_i IJ].each do |name|
      it "passes #{name} lookup tests" do
        result = run_lookup_tests(name)
        expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
        expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
      end
    end

    it 'passes nepali lookup tests' do
      result = run_lookup_tests('nepali')
      expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
      expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
    end

    it 'passes korean lookup tests' do
      result = run_lookup_tests('korean')
      expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
      expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
    end

    %w[germancompounding germancompoundingold].each do |name|
      it "passes #{name} lookup tests" do
        result = run_lookup_tests(name)
        expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
        expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
      end
    end

    it 'passes hu lookup tests', pending: 'Hungarian is hard!' do
      result = run_lookup_tests('hu')
      expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
      expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
    end
  end

  # Edge Cases and Bugs
  describe 'Edge Cases and Bugs' do
    it 'passes slash lookup tests' do
      result = run_lookup_tests('slash')
      expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
      expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
    end

    it 'passes timelimit lookup tests' do
      result = run_lookup_tests('timelimit')
      expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
      expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
    end

    # Bug report tests
    %w[1592880 1975530 2970240 2970242 2999225 i35725 i53643 i54633 i54980 i58202].each do |name|
      it "passes #{name} lookup tests" do
        result = run_lookup_tests(name)
        expect(result[:good_failures]).to be_empty, "Good words not found: #{result[:good_failures].join(', ')}"
        expect(result[:bad_failures]).to be_empty, "Bad words found: #{result[:bad_failures].join(', ')}"
      end
    end
  end
end
