# frozen_string_literal: true

require "kotoshu"

RSpec.describe Kotoshu::Checks do
  # A real spellchecker over a real dictionary fixture: the checks
  # compose real instances, never doubles. ("rice" is deliberately
  # absent from the fixture so a misspelling is reachable.)
  let(:dictionary) do
    dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")
    dict.add_word("rice")
    dict
  end
  let(:context) do
    { language: "en", spellchecker: Kotoshu::Spellchecker.new(dictionary: dictionary) }
  end
  let(:registry) { Kotoshu::Checks::Registry.new(context: context) }

  describe Kotoshu::Checks::Base do
    it "requires subclasses to declare a check kind" do
      expect { Class.new(described_class).check_kind }
        .to raise_error(NotImplementedError, /must declare check_kind/)
    end

    it "requires subclasses to implement run" do
      check = Class.new(described_class).new
      expect { check.run("text") }.to raise_error(NotImplementedError, /must implement run/)
    end

    it "applies to every language by default" do
      expect(Class.new(described_class).applies_to?("zh-Hans-CN")).to be true
    end
  end

  describe Kotoshu::Checks::SpellingCheck do
    it "is the only default-on check" do
      expect(described_class.default_on?).to be true
      expect(Kotoshu::Checks::GrammarCheck.default_on?).to be false
    end

    it "finds misspelled words as typed findings" do
      findings = described_class.new(context).run("hello wrold")
      expect(findings.map(&:check_kind).uniq).to eq [:spelling]
      expect(findings.map(&:word)).to eq ["wrold"]
      expect(findings.first.payload).to be_a(Kotoshu::Models::Result::WordResult)
    end

    it "returns no findings for correct text" do
      expect(described_class.new(context).run("hello world")).to eq []
    end
  end

  describe Kotoshu::Checks::GrammarCheck do
    it "applies to english and degrades to absent elsewhere" do
      expect(described_class.available?("en")).to be true
      expect(described_class.available?("zh-Hans-CN")).to be false
    end

    it "tokenizes with offsets" do
      check = described_class.new(context)
      tokens = check.send(:tokenize, "hello  world")
      expect(tokens).to eq [
        { token: "hello", pos_tag: nil, position: 0 },
        { token: "world", pos_tag: nil, position: 7 }
      ]
    end

    it "runs without crashing and returns typed findings" do
      findings = described_class.new(context).run("hello world")
      expect(findings).to all(have_attributes(check_kind: :grammar))
    end
  end

  describe Kotoshu::Checks::Registry do
    it "enables exactly spelling by default" do
      expect(registry.enabled).to eq [Kotoshu::Checks::SpellingCheck]
    end

    it "lists grammar as opt-in" do
      expect(registry.opt_in).to eq [Kotoshu::Checks::GrammarCheck]
    end

    it "degrades to check-absent for languages without grammar rules" do
      zh_registry = described_class.new(
        checks: Kotoshu::Checks::Registry::DEFAULT_CHECKS,
        context: { language: "zh-Hans-CN", spellchecker: context[:spellchecker] }
      )
      expect(zh_registry.available).to eq [Kotoshu::Checks::SpellingCheck]
    end

    it "runs all available checks on demand" do
      results = registry.run_all("hello world")
      expect(results.keys).to contain_exactly(:spelling, :grammar)
      expect(results[:spelling]).to eq []
    end

    it "keys findings by check kind" do
      results = registry.run_all("hello wrold")
      expect(results[:spelling].map(&:word)).to eq ["wrold"]
    end

    it "is data driven: a custom check list composes without code changes" do
      custom = Class.new(Kotoshu::Checks::Base) do
        def self.check_kind = :custom

        def run(_text)
          [Kotoshu::Checks::Finding.new(:custom, { word: "x", position: 0 })]
        end
      end
      custom_registry = described_class.new(checks: [custom], context: context)
      findings = custom_registry.run("anything", checks: [custom])
      expect(findings[:custom].map(&:check_kind)).to eq [:custom]
    end
  end
end
