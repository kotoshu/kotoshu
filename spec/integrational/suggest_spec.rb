# frozen_string_literal: true

RSpec.describe 'Integrational Suggestion Tests', :integrational do
  include SpyllsTestHelper

  # Run suggestion tests for a given dictionary name
  def run_suggestion_tests(name, pending_words: [])
    dictionary = read_dictionary(name)
    bad = read_list("#{name}.wrong")

    # Parse suggestions from .sug file
    sug = parse_suggestions("#{name}.sug")

    results = []
    bad.each_with_index do |word, i|
      expected = sug[i] || []
      got = dictionary.suggest(word).to_a

      match = expected == got
      pending = pending_words.include?(word)

      results << {
        word:,
        expected:,
        got:,
        match:,
        pending:
      }
    end

    {
      results:,
      good_count: results.count { |r| r[:match] },
      bad_count: results.count { |r| !r[:match] },
      pending_count: results.count { |r| r[:pending] }
    }
  end

  # Parse suggestions from file
  def parse_suggestions(name)
    path = File.join(SpyllsTestHelper::BASE_FOLDER, name)
    return [] unless File.file?(path)

    File.read(path).split("\n").filter_map do |line|
      next if line.empty?
      next if line.strip == '.'
      # Split by comma, handling the special case for ph.sug
      # which contains "Oh, my gosh!" and "OH, MY GOSH!"
      if line.include?(', ') && line.split(', ').length == 2
        # This could be "Oh, my gosh!" or a real suggestion list
        # For now, treat it as a single line if it looks like a phrase
        if line =~ /^[A-Z][a-z]+, [a-z]+ [a-z]+!$/
          [line.strip]
        else
          line.split(', ').map(&:strip)
        end
      else
        line.split(', ').map(&:strip)
      end
    end
  end

  # Base Tests
  describe 'Base' do
    it 'passes base suggestion tests' do
      result = run_suggestion_tests('base')
      failures = result[:results].reject { |r| r[:match] || r[:pending] }
      expect(failures).to be_empty, lambda {
        failures.map { |f| "#{f[:word]}: expected #{f[:expected]}, got #{f[:got]}" }.join("\n")
      }
    end

    it 'passes base_utf suggestion tests' do
      result = run_suggestion_tests('base_utf')
      failures = result[:results].reject { |r| r[:match] || r[:pending] }
      expect(failures).to be_empty, lambda {
        failures.map { |f| "#{f[:word]}: expected #{f[:expected]}, got #{f[:got]}" }.join("\n")
      }
    end
  end

  # All Caps Tests
  describe 'All Caps' do
    %w[allcaps allcaps2 allcaps_utf].each do |name|
      it "passes #{name} suggestion tests" do
        result = run_suggestion_tests(name)
        failures = result[:results].reject { |r| r[:match] || r[:pending] }
        expect(failures).to be_empty, lambda {
          failures.map { |f| "#{f[:word]}: expected #{f[:expected]}, got #{f[:got]}" }.join("\n")
        }
      end
    end
  end

  # Break Default
  describe 'Break' do
    it 'passes breakdefault suggestion tests' do
      result = run_suggestion_tests('breakdefault')
      failures = result[:results].reject { |r| r[:match] || r[:pending] }
      expect(failures).to be_empty, lambda {
        failures.map { |f| "#{f[:word]}: expected #{f[:expected]}, got #{f[:got]}" }.join("\n")
      }
    end
  end

  # Suggest Base
  describe 'Suggest Base' do
    it 'passes sug suggestion tests', pending: ['permanent.Vacation'] do
      result = run_suggestion_tests('sug', pending_words: ['permanent.Vacation'])
      failures = result[:results].reject { |r| r[:match] || r[:pending] }
      expect(failures).to be_empty, lambda {
        failures.map { |f| "#{f[:word]}: expected #{f[:expected]}, got #{f[:got]}" }.join("\n")
      }
    end

    it 'passes sugutf suggestion tests', pending: ['permanent.Vacation'] do
      result = run_suggestion_tests('sugutf', pending_words: ['permanent.Vacation'])
      failures = result[:results].reject { |r| r[:match] || r[:pending] }
      expect(failures).to be_empty, lambda {
        failures.map { |f| "#{f[:word]}: expected #{f[:expected]}, got #{f[:got]}" }.join("\n")
      }
    end

    it 'passes sug2 suggestion tests' do
      result = run_suggestion_tests('sug2')
      failures = result[:results].reject { |r| r[:match] || r[:pending] }
      expect(failures).to be_empty, lambda {
        failures.map { |f| "#{f[:word]}: expected #{f[:expected]}, got #{f[:got]}" }.join("\n")
      }
    end
  end

  # Permutations
  describe 'Permutations' do
    %w[map maputf].each do |name|
      it "passes #{name} suggestion tests" do
        result = run_suggestion_tests(name)
        failures = result[:results].reject { |r| r[:match] || r[:pending] }
        expect(failures).to be_empty, lambda {
          failures.map { |f| "#{f[:word]}: expected #{f[:expected]}, got #{f[:got]}" }.join("\n")
        }
      end
    end

    %w[rep reputf].each do |name|
      it "passes #{name} suggestion tests" do
        result = run_suggestion_tests(name)
        failures = result[:results].reject { |r| r[:match] || r[:pending] }
        expect(failures).to be_empty, lambda {
          failures.map { |f| "#{f[:word]}: expected #{f[:expected]}, got #{f[:got]}" }.join("\n")
        }
      end
    end
  end

  # Prohibit Bad Suggestions
  describe 'Prohibit Bad Suggestions' do
    it 'passes forceucase suggestion tests' do
      result = run_suggestion_tests('forceucase')
      failures = result[:results].reject { |r| r[:match] || r[:pending] }
      expect(failures).to be_empty, lambda {
        failures.map { |f| "#{f[:word]}: expected #{f[:expected]}, got #{f[:got]}" }.join("\n")
      }
    end

    it 'passes keepcase suggestion tests', pending: ['bar'] do
      result = run_suggestion_tests('keepcase', pending_words: ['bar'])
      failures = result[:results].reject { |r| r[:match] || r[:pending] }
      expect(failures).to be_empty, lambda {
        failures.map { |f| "#{f[:word]}: expected #{f[:expected]}, got #{f[:got]}" }.join("\n")
      }
    end

    it 'passes nosuggest suggestion tests' do
      result = run_suggestion_tests('nosuggest')
      failures = result[:results].reject { |r| r[:match] || r[:pending] }
      expect(failures).to be_empty, lambda {
        failures.map { |f| "#{f[:word]}: expected #{f[:expected]}, got #{f[:got]}" }.join("\n")
      }
    end

    it 'passes onlyincompound suggestion tests' do
      result = run_suggestion_tests('onlyincompound')
      failures = result[:results].reject { |r| r[:match] || r[:pending] }
      expect(failures).to be_empty, lambda {
        failures.map { |f| "#{f[:word]}: expected #{f[:expected]}, got #{f[:got]}" }.join("\n")
      }
    end

    it 'passes nosplitsugs suggestion tests' do
      result = run_suggestion_tests('nosplitsugs')
      failures = result[:results].reject { |r| r[:match] || r[:pending] }
      expect(failures).to be_empty, lambda {
        failures.map { |f| "#{f[:word]}: expected #{f[:expected]}, got #{f[:got]}" }.join("\n")
      }
    end

    %w[opentaal_forbiddenword1 opentaal_forbiddenword2].each do |name|
      it "passes #{name} suggestion tests" do
        result = run_suggestion_tests(name)
        failures = result[:results].reject { |r| r[:match] || r[:pending] }
        expect(failures).to be_empty, lambda {
          failures.map { |f| "#{f[:word]}: expected #{f[:expected]}, got #{f[:got]}" }.join("\n")
        }
      end
    end
  end

  # Phonetical Suggestions
  describe 'Phonetical Suggestions' do
    %w[ph ph2 phone].each do |name|
      it "passes #{name} suggestion tests" do
        result = run_suggestion_tests(name)
        failures = result[:results].reject { |r| r[:match] || r[:pending] }
        expect(failures).to be_empty, lambda {
          failures.map { |f| "#{f[:word]}: expected #{f[:expected]}, got #{f[:got]}" }.join("\n")
        }
      end
    end
  end

  # IO Quirks
  describe 'IO Quirks' do
    it 'passes oconv suggestion tests' do
      result = run_suggestion_tests('oconv')
      failures = result[:results].reject { |r| r[:match] || r[:pending] }
      expect(failures).to be_empty, lambda {
        failures.map { |f| "#{f[:word]}: expected #{f[:expected]}, got #{f[:got]}" }.join("\n")
      }
    end
  end

  # Edge Cases and Bugs
  describe 'Edge Cases and Bugs' do
    %w[checksharps checksharpsutf].each do |name|
      it "passes #{name} suggestion tests" do
        result = run_suggestion_tests(name)
        failures = result[:results].reject { |r| r[:match] || r[:pending] }
        expect(failures).to be_empty, lambda {
          failures.map { |f| "#{f[:word]}: expected #{f[:expected]}, got #{f[:got]}" }.join("\n")
        }
      end
    end

    it 'passes ngram_utf_fix suggestion tests' do
      result = run_suggestion_tests('ngram_utf_fix')
      failures = result[:results].reject { |r| r[:match] || r[:pending] }
      expect(failures).to be_empty, lambda {
        failures.map { |f| "#{f[:word]}: expected #{f[:expected]}, got #{f[:got]}" }.join("\n")
      }
    end

    it 'passes IJ suggestion tests' do
      result = run_suggestion_tests('IJ')
      failures = result[:results].reject { |r| r[:match] || r[:pending] }
      expect(failures).to be_empty, lambda {
        failures.map { |f| "#{f[:word]}: expected #{f[:expected]}, got #{f[:got]}" }.join("\n")
      }
    end

    # Bug report tests
    %w[1463589 1463589_utf 1695964 i35725 i54633 i58202].each do |name|
      it "passes #{name} suggestion tests" do
        result = run_suggestion_tests(name)
        failures = result[:results].reject { |r| r[:match] || r[:pending] }
        expect(failures).to be_empty, lambda {
          failures.map { |f| "#{f[:word]}: expected #{f[:expected]}, got #{f[:got]}" }.join("\n")
        }
      end
    end
  end
end
