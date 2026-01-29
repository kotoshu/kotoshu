# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kotoshu::Dictionary::Repository, "# Walking Skeleton - Dictionary Repository" do
  describe "creation" do
    it "creates empty repository" do
      repo = Kotoshu::Dictionary::Repository.new

      expect(repo.empty?).to be true
      expect(repo.size).to eq(0)
    end

    it "creates repository with initial dictionaries" do
      dict1 = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")
      dict2 = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "es")

      repo = Kotoshu::Dictionary::Repository.new(en_US: dict1, es: dict2)

      expect(repo.size).to eq(2)
      expect(repo[:en_US]).to eq(dict1)
      expect(repo[:es]).to eq(dict2)
    end
  end

  describe "#register" do
    it "registers dictionary under key" do
      repo = Kotoshu::Dictionary::Repository.new
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")

      result = repo.register(:en_US, dict)

      expect(result).to eq(repo)
      expect(repo.registered?(:en_US)).to be true
      expect(repo[:en_US]).to eq(dict)
    end

    it "converts string keys to symbols" do
      repo = Kotoshu::Dictionary::Repository.new
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")

      repo.register("en_US", dict)

      expect(repo.registered?(:en_US)).to be true
      expect(repo["en_US"]).to eq(dict)
    end

    it "replaces existing dictionary" do
      repo = Kotoshu::Dictionary::Repository.new
      dict1 = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")
      dict2 = Kotoshu::Dictionary::PlainText.new("spec/fixtures/empty.txt", language_code: "en-US")

      repo.register(:en_US, dict1)
      repo.register(:en_US, dict2)

      expect(repo[:en_US]).to eq(dict2)
      expect(repo.size).to eq(1)
    end

    it "has alias add" do
      repo = Kotoshu::Dictionary::Repository.new
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")

      repo.add(:en_US, dict)

      expect(repo.registered?(:en_US)).to be true
    end

    it "has alias []=" do
      repo = Kotoshu::Dictionary::Repository.new
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")

      repo[:en_US] = dict

      expect(repo.registered?(:en_US)).to be true
    end
  end

  describe "#get" do
    it "returns dictionary for existing key" do
      repo = Kotoshu::Dictionary::Repository.new
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")

      repo.register(:en_US, dict)

      expect(repo.get(:en_US)).to eq(dict)
    end

    it "returns nil for non-existing key" do
      repo = Kotoshu::Dictionary::Repository.new

      expect(repo.get(:en_US)).to be_nil
    end

    it "has alias []" do
      repo = Kotoshu::Dictionary::Repository.new
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")

      repo.register(:en_US, dict)

      expect(repo[:en_US]).to eq(dict)
    end

    it "converts string keys to symbols" do
      repo = Kotoshu::Dictionary::Repository.new
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")

      repo.register(:en_US, dict)

      expect(repo.get("en_US")).to eq(dict)
    end
  end

  describe "#registered?" do
    it "returns true for registered key" do
      repo = Kotoshu::Dictionary::Repository.new
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")

      repo.register(:en_US, dict)

      expect(repo.registered?(:en_US)).to be true
    end

    it "returns false for unregistered key" do
      repo = Kotoshu::Dictionary::Repository.new

      expect(repo.registered?(:en_US)).to be false
    end

    it "has alias has_key?" do
      repo = Kotoshu::Dictionary::Repository.new
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")

      repo.register(:en_US, dict)

      expect(repo.has_key?(:en_US)).to be true
    end

    it "has alias key?" do
      repo = Kotoshu::Dictionary::Repository.new
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")

      repo.register(:en_US, dict)

      expect(repo.key?(:en_US)).to be true
    end
  end

  describe "#unregister" do
    it "removes dictionary" do
      repo = Kotoshu::Dictionary::Repository.new
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")

      repo.register(:en_US, dict)
      result = repo.unregister(:en_US)

      expect(result).to eq(dict)
      expect(repo.registered?(:en_US)).to be false
      expect(repo.size).to eq(0)
    end

    it "returns nil for non-existing key" do
      repo = Kotoshu::Dictionary::Repository.new

      expect(repo.unregister(:en_US)).to be_nil
    end

    it "has alias remove" do
      repo = Kotoshu::Dictionary::Repository.new
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")

      repo.register(:en_US, dict)
      repo.remove(:en_US)

      expect(repo.registered?(:en_US)).to be false
    end
  end

  describe "#clear" do
    it "removes all dictionaries" do
      repo = Kotoshu::Dictionary::Repository.new
      dict1 = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")
      dict2 = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "es")

      repo.register(:en_US, dict1)
      repo.register(:es, dict2)
      result = repo.clear

      expect(result).to eq(repo)
      expect(repo.empty?).to be true
    end
  end

  describe "#keys" do
    it "returns all registered keys" do
      repo = Kotoshu::Dictionary::Repository.new
      dict1 = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")
      dict2 = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "es")

      repo.register(:en_US, dict1)
      repo.register(:es, dict2)

      expect(repo.keys).to contain_exactly(:en_US, :es)
    end
  end

  describe "#values" do
    it "returns all dictionaries" do
      repo = Kotoshu::Dictionary::Repository.new
      dict1 = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")
      dict2 = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "es")

      repo.register(:en_US, dict1)
      repo.register(:es, dict2)

      expect(repo.values).to contain_exactly(dict1, dict2)
    end
  end

  describe "#size" do
    it "returns number of dictionaries" do
      repo = Kotoshu::Dictionary::Repository.new
      dict1 = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")
      dict2 = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "es")

      repo.register(:en_US, dict1)
      expect(repo.size).to eq(1)

      repo.register(:es, dict2)
      expect(repo.size).to eq(2)
    end

    it "has alias count" do
      repo = Kotoshu::Dictionary::Repository.new
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")

      repo.register(:en_US, dict)

      expect(repo.count).to eq(1)
    end

    it "has alias length" do
      repo = Kotoshu::Dictionary::Repository.new
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")

      repo.register(:en_US, dict)

      expect(repo.length).to eq(1)
    end
  end

  describe "#empty?" do
    it "returns true for empty repository" do
      repo = Kotoshu::Dictionary::Repository.new

      expect(repo.empty?).to be true
    end

    it "returns false for non-empty repository" do
      repo = Kotoshu::Dictionary::Repository.new
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")

      repo.register(:en_US, dict)

      expect(repo.empty?).to be false
    end
  end

  describe "#each" do
    it "iterates over key-dictionary pairs" do
      repo = Kotoshu::Dictionary::Repository.new
      dict1 = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")
      dict2 = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "es")

      repo.register(:en_US, dict1)
      repo.register(:es, dict2)

      pairs = []
      repo.each { |key, dict| pairs << [key, dict] }

      expect(pairs).to contain_exactly([:en_US, dict1], [:es, dict2])
    end

    it "returns enumerator when no block given" do
      repo = Kotoshu::Dictionary::Repository.new

      expect(repo.each).to be_a(Enumerator)
    end
  end

  describe "#merge" do
    it "merges another repository" do
      repo1 = Kotoshu::Dictionary::Repository.new
      repo2 = Kotoshu::Dictionary::Repository.new
      dict1 = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")
      dict2 = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "es")

      repo1.register(:en_US, dict1)
      repo2.register(:es, dict2)

      result = repo1.merge(repo2)

      expect(result).to eq(repo1)
      expect(repo1.size).to eq(2)
      expect(repo1[:en_US]).to eq(dict1)
      expect(repo1[:es]).to eq(dict2)
    end

    it "merges a hash" do
      repo = Kotoshu::Dictionary::Repository.new
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")

      result = repo.merge(es: dict)

      expect(result).to eq(repo)
      expect(repo.size).to eq(1)
      expect(repo[:es]).to eq(dict)
    end

    it "overwrites existing keys" do
      repo = Kotoshu::Dictionary::Repository.new
      dict1 = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")
      dict2 = Kotoshu::Dictionary::PlainText.new("spec/fixtures/empty.txt", language_code: "en-US")

      repo.register(:en_US, dict1)
      repo.merge(en_US: dict2)

      expect(repo[:en_US]).to eq(dict2)
      expect(repo.size).to eq(1)
    end
  end

  describe "#find_by_language" do
    it "returns dictionaries matching language code" do
      repo = Kotoshu::Dictionary::Repository.new
      dict1 = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")
      dict2 = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-GB")
      dict3 = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "es")

      repo.register(:en_us, dict1)
      repo.register(:en_gb, dict2)
      repo.register(:es, dict3)

      results = repo.find_by_language("en-US")

      expect(results).to contain_exactly(dict1)
    end

    it "is case-insensitive" do
      repo = Kotoshu::Dictionary::Repository.new
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")

      repo.register(:en_US, dict)

      expect(repo.find_by_language("en-us")).to contain_exactly(dict)
      expect(repo.find_by_language("EN-US")).to contain_exactly(dict)
    end

    it "returns empty array when no matches" do
      repo = Kotoshu::Dictionary::Repository.new
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "es")

      repo.register(:es, dict)

      expect(repo.find_by_language("en-US")).to eq([])
    end
  end

  describe "#to_h" do
    it "returns hash representation" do
      repo = Kotoshu::Dictionary::Repository.new
      dict1 = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")
      dict2 = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "es")

      repo.register(:en_US, dict1)
      repo.register(:es, dict2)

      hash = repo.to_h

      expect(hash).to eq({ en_US: dict1, es: dict2 })
      expect(hash).not_to be(repo.dictionaries)
    end
  end

  describe "#to_s" do
    it "returns string representation" do
      repo = Kotoshu::Dictionary::Repository.new
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")

      repo.register(:en_US, dict)

      expect(repo.to_s).to eq("Repository(size: 1)")
    end

    it "has alias inspect" do
      repo = Kotoshu::Dictionary::Repository.new

      expect(repo.inspect).to eq(repo.to_s)
    end
  end

  describe ".instance" do
    it "returns singleton instance" do
      instance1 = Kotoshu::Dictionary::Repository.instance
      instance2 = Kotoshu::Dictionary::Repository.instance

      expect(instance1).to be(instance2)
    end

    it "returns same instance across calls" do
      Kotoshu::Dictionary::Repository.clear

      instance = Kotoshu::Dictionary::Repository.instance
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")
      instance.register(:en_US, dict)

      expect(Kotoshu::Dictionary::Repository.instance[:en_US]).to eq(dict)

      Kotoshu::Dictionary::Repository.clear
    end
  end

  describe ".register" do
    it "registers dictionary in global repository" do
      Kotoshu::Dictionary::Repository.clear
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")

      result = Kotoshu::Dictionary::Repository.register(:en_US, dict)

      expect(result).to eq(Kotoshu::Dictionary::Repository.instance)
      expect(Kotoshu::Dictionary::Repository.registered?(:en_US)).to be true

      Kotoshu::Dictionary::Repository.clear
    end
  end

  describe ".get" do
    it "gets dictionary from global repository" do
      Kotoshu::Dictionary::Repository.clear
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")

      Kotoshu::Dictionary::Repository.register(:en_US, dict)

      expect(Kotoshu::Dictionary::Repository.get(:en_US)).to eq(dict)

      Kotoshu::Dictionary::Repository.clear
    end
  end

  describe ".unregister" do
    it "unregisters dictionary from global repository" do
      Kotoshu::Dictionary::Repository.clear
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")

      Kotoshu::Dictionary::Repository.register(:en_US, dict)
      result = Kotoshu::Dictionary::Repository.unregister(:en_US)

      expect(result).to eq(dict)
      expect(Kotoshu::Dictionary::Repository.registered?(:en_US)).to be false

      Kotoshu::Dictionary::Repository.clear
    end
  end

  describe ".clear" do
    it "clears global repository" do
      Kotoshu::Dictionary::Repository.clear
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")

      Kotoshu::Dictionary::Repository.register(:en_US, dict)
      result = Kotoshu::Dictionary::Repository.clear

      expect(result).to eq(Kotoshu::Dictionary::Repository.instance)
      expect(Kotoshu::Dictionary::Repository.instance.empty?).to be true
    end
  end

  describe ".keys" do
    it "returns all keys from global repository" do
      Kotoshu::Dictionary::Repository.clear
      dict1 = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")
      dict2 = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "es")

      Kotoshu::Dictionary::Repository.register(:en_US, dict1)
      Kotoshu::Dictionary::Repository.register(:es, dict2)

      expect(Kotoshu::Dictionary::Repository.keys).to contain_exactly(:en_US, :es)

      Kotoshu::Dictionary::Repository.clear
    end
  end
end
