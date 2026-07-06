# frozen_string_literal: true

require "kotoshu"
require "tmpdir"
require "fileutils"

# Trigger autoload of every dictionary constant exercised below.
Kotoshu::Dictionary::Base
Kotoshu::Dictionary::CSpell
Kotoshu::Dictionary::Custom
Kotoshu::Dictionary::Hunspell
Kotoshu::Dictionary::UnixWords

# Direct spec for the un-specced dictionary backends:
#   base.rb, cspell.rb, custom.rb, hunspell.rb, unix_words.rb
#
# plain_text.rb and repository.rb already have dedicated specs.
#
# unified.rb is intentionally not specced: it declares
# `class Kotoshu::Dictionary` while lib/kotoshu/dictionary.rb already
# declares `module Kotoshu::Dictionary`. Ruby treats these as
# conflicting declarations, so loading the file raises
# `TypeError: Dictionary is not a class`. Nothing in lib/, spec/, or
# exe/ actually references Kotoshu::Dictionary::Unified (the autoload
# entry exists but is never triggered). This is dead code and a real
# bug — flagged for the user to delete or rename (e.g., move the class
# under Kotoshu::Dictionary::Unified).
RSpec.describe Kotoshu::Dictionary do
  # ---- Base (abstract) -------------------------------------------------

  describe Kotoshu::Dictionary::Base do
    # Bare subclass — inherits the abstract template methods so they
    # raise NotImplementedError as documented.
    let(:bare_subclass) do
      Class.new(described_class) do
        def initialize(language_code, locale: nil, metadata: {})
          super
        end
      end
    end

    # Stubbed subclass — provides a small in-memory word list so the
    # concrete (non-abstract) instance methods can be exercised.
    let(:stubbed_subclass) do
      Class.new(described_class) do
        def initialize(language_code, words:, locale: nil, metadata: {})
          super(language_code, locale: locale, metadata: metadata)
          @words = words
        end

        def lookup(word)
          @words.include?(word)
        end

        def suggest(word, max_suggestions: 10)
          @words.first(max_suggestions).grep(/#{word[0..2]}/)
        end

        def add_word(word, flags: [])
          return false if @words.include?(word)

          @words << word
          true
        end

        def remove_word(word)
          @words.delete(word)
        end

        def words
          @words.dup
        end
      end
    end

    describe "#initialize" do
      it "freezes language_code, locale, and metadata" do
        d = stubbed_subclass.new("en-US", words: %w[foo])
        expect(d.language_code).to eq("en-US")
        expect(d.language_code).to be_frozen
        expect(d.locale).to be_nil
        expect(d.metadata).to be_frozen
      end

      it "raises ArgumentError for a nil language_code" do
        expect { described_class.new(nil) }.to raise_error(ArgumentError, /cannot be empty/)
      end

      it "raises ArgumentError for an empty language_code" do
        expect { described_class.new("") }.to raise_error(ArgumentError, /cannot be empty/)
      end

      it "preserves but freezes a passed-in locale" do
        d = stubbed_subclass.new("en-US", words: [], locale: "en_US")
        expect(d.locale).to eq("en_US")
        expect(d.locale).to be_frozen
      end
    end

    describe "abstract template methods" do
      it "lookup raises NotImplementedError" do
        expect { bare_subclass.new("en").lookup("foo") }
          .to raise_error(NotImplementedError, /must implement #lookup/)
      end

      it "suggest raises NotImplementedError" do
        expect { bare_subclass.new("en").suggest("foo") }
          .to raise_error(NotImplementedError, /must implement #suggest/)
      end

      it "add_word raises NotImplementedError" do
        expect { bare_subclass.new("en").add_word("foo") }
          .to raise_error(NotImplementedError, /must implement #add_word/)
      end

      it "remove_word raises NotImplementedError" do
        expect { bare_subclass.new("en").remove_word("foo") }
          .to raise_error(NotImplementedError, /must implement #remove_word/)
      end

      it "words raises NotImplementedError" do
        expect { bare_subclass.new("en").words }
          .to raise_error(NotImplementedError, /must implement #words/)
      end
    end

    describe "aliases" do
      let(:dict) { stubbed_subclass.new("en", words: %w[apple pear]) }

      it "has_word? is an alias for lookup" do
        expect(dict.has_word?("apple")).to be true
        expect(dict.has_word?("missing")).to be false
      end

      it "include? is an alias for lookup" do
        expect(dict.include?("apple")).to be true
      end

      it "contains? is an alias for lookup" do
        expect(dict.contains?("apple")).to be true
      end

      it "lookup? is an alias for lookup" do
        expect(dict.lookup?("apple")).to be true
      end

      it "<< is an alias for add_word" do
        dict << "banana"
        expect(dict.lookup("banana")).to be true
      end

      it "all_words is an alias for words" do
        expect(dict.all_words).to eq(%w[apple pear])
      end

      it "count and length are aliases for size" do
        expect(dict.count).to eq(2)
        expect(dict.length).to eq(2)
      end
    end

    describe "#size / #empty?" do
      it "size returns the number of words" do
        expect(stubbed_subclass.new("en", words: %w[a b c]).size).to eq(3)
      end

      it "empty? is true when there are no words" do
        expect(stubbed_subclass.new("en", words: []).empty?).to be true
        expect(stubbed_subclass.new("en", words: %w[a]).empty?).to be false
      end
    end

    describe "#each_word" do
      it "iterates words when a block is given" do
        d = stubbed_subclass.new("en", words: %w[a b c])
        collected = []
        d.each_word { |w| collected << w }
        expect(collected).to eq(%w[a b c])
      end

      it "returns an Enumerator when no block is given" do
        d = stubbed_subclass.new("en", words: %w[a b])
        expect(d.each_word).to be_an(Enumerator)
        expect(d.each_word.to_a).to eq(%w[a b])
      end
    end

    describe "#words_with_prefix / #words_matching" do
      let(:dict) { stubbed_subclass.new("en", words: %w[apple apply banana application]) }

      it "returns words starting with the prefix" do
        expect(dict.words_with_prefix("appl").sort).to eq(%w[apple application apply])
      end

      it "returns words matching a Regexp" do
        expect(dict.words_matching(/^app/).sort).to eq(%w[apple application apply])
      end
    end

    describe "#to_s / #inspect" do
      it "includes the class name, language code, and size" do
        d = stubbed_subclass.new("en-US", words: %w[a b])
        s = d.to_s
        # Anonymous classes show as Class:0x..., so just check the
        # language and size portions.
        expect(s).to match(/language: en-US/)
        expect(s).to match(/size: 2/)
        expect(d.inspect).to eq(d.to_s)
      end
    end

    describe "#type" do
      it "derives a snake_case symbol from the class name" do
        # Use a named class so the symbol derivation is deterministic.
        klass = Class.new(described_class) do
          def self.name; "Kotoshu::Dictionary::MyTestDict"; end
        end
        expect(klass.new("en").type).to eq(:my_test_dict)
      end
    end

    describe "module-level registry" do
      after { Kotoshu::Dictionary.reset_registry! }

      it "Kotoshu::Dictionary.register_type adds a class under a symbol" do
        klass = Class.new(described_class)
        Kotoshu::Dictionary.register_type(:test_register, klass)
        expect(Kotoshu::Dictionary.registry[:test_register]).to eq(klass)
      end

      it "Kotoshu::Dictionary.load dispatches to the registered class constructor" do
        klass = Class.new(described_class)
        Kotoshu::Dictionary.register_type(:test_load, klass)
        instance = Kotoshu::Dictionary.load(:test_load, "en")
        expect(instance).to be_a(klass)
        expect(instance.language_code).to eq("en")
      end

      it "Kotoshu::Dictionary.load raises ConfigurationError for an unknown type" do
        expect { Kotoshu::Dictionary.load(:nonexistent_thing, "en") }
          .to raise_error(Kotoshu::ConfigurationError, /Unknown dictionary type/)
      end
    end

    describe "class-level registry" do
      after do
        registry = described_class.registry
        registry.delete(:test_class_register)
        registry.delete(:test_class_load)
      end

      it "Base.register_type(type_key) registers self into the module-level registry" do
        klass = Class.new(described_class)
        klass.register_type(:test_class_register)
        expect(Kotoshu::Dictionary.registry[:test_class_register]).to eq(klass)
      end

      it "Base.load(type, *args) dispatches to the registered class constructor" do
        klass = Class.new(described_class)
        described_class.registry[:test_class_load] = klass
        instance = described_class.load(:test_class_load, "en")
        expect(instance).to be_a(klass)
      end
    end
  end

  # ---- UnixWords -------------------------------------------------------

  describe Kotoshu::Dictionary::UnixWords do
    let(:tmpdir) { Dir.mktmpdir("kotoshu-unix-spec") }
    let(:words_path) { File.join(tmpdir, "words.txt") }
    let!(:dict) do
      File.write(words_path, "hello\nworld\nruby\n# comment\n\nhelp\n")
      described_class.new(words_path, language_code: "en-US")
    end

    after { FileUtils.rm_rf(tmpdir) if File.exist?(tmpdir) }

    describe "#initialize" do
      it "raises DictionaryNotFoundError when the file does not exist" do
        expect { described_class.new(File.join(tmpdir, "nope"), language_code: "en") }
          .to raise_error(Kotoshu::DictionaryNotFoundError)
      end

      it "skips blank lines and # comments" do
        expect(dict.words).to contain_exactly("hello", "world", "ruby", "help")
      end

      it "registers itself in the Dictionary registry as :unix_words" do
        expect(Kotoshu::Dictionary.registry[:unix_words]).to eq(described_class)
      end
    end

    describe "#lookup" do
      it "is true for words in the file (case-insensitive by default)" do
        expect(dict.lookup("HELLO")).to be true
        expect(dict.lookup("ruby")).to be true
      end

      it "is false for missing words" do
        expect(dict.lookup("missing")).to be false
      end

      it "is false for nil and empty input" do
        expect(dict.lookup(nil)).to be false
        expect(dict.lookup("")).to be false
      end
    end

    describe "#suggest" do
      it "returns close edit-distance matches" do
        suggestions = dict.suggest("helo")
        expect(suggestions).to include("hello", "help")
      end

      it "returns [] for nil and empty input" do
        expect(dict.suggest(nil)).to eq([])
        expect(dict.suggest("")).to eq([])
      end

      it "respects the max_suggestions limit" do
        suggestions = dict.suggest("helo", max_suggestions: 1)
        expect(suggestions.length).to be <= 1
      end
    end

    describe "#add_word / #remove_word" do
      it "add_word adds and returns true" do
        expect(dict.add_word("newword")).to be true
        expect(dict.lookup("newword")).to be true
      end

      it "add_word returns false for an existing word" do
        expect(dict.add_word("hello")).to be false
      end

      it "add_word returns false for nil/empty" do
        expect(dict.add_word(nil)).to be false
        expect(dict.add_word("")).to be false
      end

      it "remove_word removes and returns true" do
        expect(dict.remove_word("hello")).to be true
        expect(dict.lookup("hello")).to be false
      end

      it "remove_word returns false for a missing word" do
        expect(dict.remove_word("absent")).to be false
      end
    end

    describe "case sensitivity" do
      it "treats input case-insensitively when case_sensitive is false (default)" do
        expect(dict.lookup("HELLO")).to be true
      end

      it "treats input case-sensitively when case_sensitive is true" do
        File.write(words_path, "Hello\nWorld\n")
        cs_dict = described_class.new(words_path, language_code: "en", case_sensitive: true)
        expect(cs_dict.lookup("Hello")).to be true
        expect(cs_dict.lookup("hello")).to be false
      end
    end

    describe ".detect_system_dictionary / .detect" do
      it "returns the first path in SYSTEM_PATHS that exists, or nil" do
        result = described_class.detect_system_dictionary
        expect(result).to be_nil | be_a(String)
      end

      it "detect returns nil when no system dictionary is found" do
        # Stub out SYSTEM_PATHS to a guaranteed-empty list.
        stub_const("#{described_class}::SYSTEM_PATHS", ["/nonexistent/words"])
        expect(described_class.detect(language_code: "en")).to be_nil
      end
    end
  end

  # ---- Custom ----------------------------------------------------------

  describe Kotoshu::Dictionary::Custom do
    describe "#initialize" do
      it "starts empty by default" do
        d = described_class.new(language_code: "en")
        expect(d.empty?).to be true
      end

      it "accepts an initial word list (case-insensitive)" do
        d = described_class.new(words: %w[Hello World], language_code: "en")
        expect(d.lookup("hello")).to be true
        expect(d.lookup("WORLD")).to be true
      end

      it "preserves case when case_sensitive is true" do
        d = described_class.new(words: %w[Hello], language_code: "en", case_sensitive: true)
        expect(d.lookup("Hello")).to be true
        expect(d.lookup("hello")).to be false
      end

      it "registers itself in the Dictionary registry as :custom" do
        described_class.new(language_code: "en")
        expect(Kotoshu::Dictionary.registry[:custom]).to eq(described_class)
      end
    end

    describe "#lookup / #suggest" do
      let(:dict) { described_class.new(words: %w[hello help held heap world], language_code: "en") }

      it "lookup is false for nil/empty" do
        expect(dict.lookup(nil)).to be false
        expect(dict.lookup("")).to be false
      end

      it "suggest returns close matches and respects max_suggestions" do
        results = dict.suggest("helo")
        expect(results).to include("hello", "help")
        expect(dict.suggest("helo", max_suggestions: 1).length).to be <= 1
      end

      it "suggest returns [] for nil/empty" do
        expect(dict.suggest(nil)).to eq([])
        expect(dict.suggest("")).to eq([])
      end
    end

    describe "#add_word / #remove_word" do
      let(:dict) { described_class.new(words: %w[foo], language_code: "en") }

      it "add_word adds new words and rejects duplicates" do
        expect(dict.add_word("bar")).to be true
        expect(dict.add_word("bar")).to be false
      end

      it "add_word strips whitespace before storing" do
        expect(dict.add_word("  padded  ")).to be true
        expect(dict.lookup("padded")).to be true
      end

      it "remove_word removes words" do
        dict.add_word("bar")
        expect(dict.remove_word("bar")).to be true
        expect(dict.lookup("bar")).to be false
      end

      it "remove_word returns false for missing words" do
        expect(dict.remove_word("absent")).to be false
      end
    end

    describe "#clear / #readonly?" do
      it "clear empties the dictionary and returns self" do
        d = described_class.new(words: %w[a b c], language_code: "en")
        expect(d.clear).to be(d)
        expect(d.empty?).to be true
      end

      it "readonly? is always false" do
        expect(described_class.new(language_code: "en").readonly?).to be false
      end
    end

    describe "#merge" do
      let(:dict) { described_class.new(words: %w[apple], language_code: "en") }

      it "merges words from another Dictionary::Base" do
        other = described_class.new(words: %w[banana cherry], language_code: "en")
        dict.merge(other)
        expect(dict.lookup("banana")).to be true
        expect(dict.lookup("cherry")).to be true
      end

      it "merges words from a plain Array" do
        dict.merge(%w[mango])
        expect(dict.lookup("mango")).to be true
      end

      it "is a no-op for other input types" do
        dict.merge("string is not valid")
        expect(dict.size).to eq(1)
      end

      it "returns self" do
        expect(dict.merge(%w[x])).to be(dict)
      end
    end
  end

  # ---- CSpell ----------------------------------------------------------

  describe Kotoshu::Dictionary::CSpell do
    let(:words_txt) { "spec/fixtures/dictionaries/cspell/words.txt" }

    let(:dict) { described_class.new(words_txt, language_code: "en-US") }

    describe "#initialize" do
      it "loads a .txt fixture into the trie" do
        d = described_class.new(words_txt, language_code: "en-US")
        expect(d.words).to include("hello", "world", "help")
      end

      it "raises DictionaryNotFoundError for a missing file" do
        expect { described_class.new("/nonexistent", language_code: "en") }
          .to raise_error(Kotoshu::DictionaryNotFoundError)
      end

      it "registers itself as :cspell in the Dictionary registry" do
        described_class.new(words_txt, language_code: "en")
        expect(Kotoshu::Dictionary.registry[:cspell]).to eq(described_class)
      end
    end

    describe "#lookup / #has_prefix?" do
      it "lookup is true for words in the file" do
        expect(dict.lookup("hello")).to be true
        expect(dict.lookup("world")).to be true
      end

      it "lookup is false for missing words" do
        expect(dict.lookup("nonexistent")).to be false
      end

      it "lookup is false for nil/empty" do
        expect(dict.lookup(nil)).to be false
        expect(dict.lookup("")).to be false
      end

      it "has_prefix? is true when at least one word starts with the prefix" do
        expect(dict.has_prefix?("hel")).to be true
        expect(dict.has_prefix?("zzz")).to be false
      end
    end

    describe "#add_word / #remove_word" do
      it "add_word always returns false (trie is frozen post-load)" do
        expect(dict.add_word("newword")).to be false
        expect(dict.add_word("hello")).to be false
      end

      it "remove_word always returns false (trie is immutable after load)" do
        expect(dict.remove_word("hello")).to be false
      end
    end

    describe "#words" do
      it "returns every word stored in the trie" do
        all = dict.words
        expect(all).to include("hello", "world", "help", "held", "heap", "test", "example")
      end
    end
  end

  # ---- Hunspell --------------------------------------------------------

  describe Kotoshu::Dictionary::Hunspell do
    let(:aff_path) { "spec/fixtures/dictionaries/hunspell/test.aff" }
    let(:dic_path) { "spec/fixtures/dictionaries/hunspell/test.dic" }

    describe "#initialize" do
      it "raises DictionaryNotFoundError when the .aff file is missing" do
        expect do
          described_class.new(aff_path: "/nope.aff", dic_path: dic_path, language_code: "en")
        end.to raise_error(Kotoshu::DictionaryNotFoundError)
      end

      it "raises DictionaryNotFoundError when the .dic file is missing" do
        expect do
          described_class.new(aff_path: aff_path, dic_path: "/nope.dic", language_code: "en")
        end.to raise_error(Kotoshu::DictionaryNotFoundError)
      end

      it "loads aff and dic data" do
        d = described_class.new(aff_path: aff_path, dic_path: dic_path, language_code: "en-US")
        expect(d.aff_data).to be_a(Hash)
        expect(d.aff_data).to include("SET")
        expect(d.dic_words).to be_an(Array)
        expect(d.dic_words.length).to be > 0
      end

      it "parses affix rules into prefix/suffix buckets" do
        d = described_class.new(aff_path: aff_path, dic_path: dic_path, language_code: "en-US")
        expect(d.affix_rules).to include(:prefix, :suffix)
        expect(d.affix_rules[:prefix]).to be_a(Hash)
        expect(d.affix_rules[:suffix]).to be_a(Hash)
      end

      it "registers itself as :hunspell in the Dictionary registry" do
        described_class.new(aff_path: aff_path, dic_path: dic_path, language_code: "en-US")
        expect(Kotoshu::Dictionary.registry[:hunspell]).to eq(described_class)
      end
    end

    describe "instance facade" do
      let(:dict) { described_class.new(aff_path: aff_path, dic_path: dic_path, language_code: "en-US") }

      it "exposes a memoized Lookuper" do
        expect(dict.lookuper).to eq(dict.lookuper)
      end

      it "exposes a memoized Suggester" do
        expect(dict.suggester).to eq(dict.suggester)
      end
    end
  end
end
