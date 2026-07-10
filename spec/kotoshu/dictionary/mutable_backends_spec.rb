# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe "mutable dictionary backends" do
  describe Kotoshu::Dictionary::PlainText do
    def build_dictionary(words)
      Kotoshu::Dictionary::PlainText.from_words(words, language_code: "en")
    end

    it_behaves_like "a mutable dictionary backend"

    describe "suggestion generation after mutation" do
      def suggestions_for(dict, word)
        generator = Kotoshu::Suggestions::Generator.new(
          dict, algorithms: [Kotoshu::Suggestions::Strategies::EditDistanceStrategy]
        )
        generator.generate(word).suggestions.map(&:word)
      end

      it "suggests words added after construction (Configuration custom_words path)" do
        dict = build_dictionary(%w[cat dog bird])
        dict.add_word("hello")

        expect(suggestions_for(dict, "helo")).to include("hello")
      end

      it "never suggests removed words" do
        dict = build_dictionary(%w[cat dog bird])
        dict.remove_word("bird")

        expect(suggestions_for(dict, "brid")).not_to include("bird")
      end
    end
  end

  describe Kotoshu::Dictionary::Custom do
    def build_dictionary(words)
      Kotoshu::Dictionary::Custom.new(words: words, language_code: "en")
    end

    it_behaves_like "a mutable dictionary backend"

    it "rejects whitespace-only words instead of storing nil" do
      dict = build_dictionary(%w[apple])

      expect(dict.add_word("   ")).to be false
      expect(dict.words).to contain_exactly("apple")
    end
  end

  describe Kotoshu::Dictionary::UnixWords do
    around do |example|
      Dir.mktmpdir("kotoshu-mutable-spec") do |dir|
        @tmpdir = dir
        example.run
      end
    end

    def build_dictionary(words)
      path = File.join(@tmpdir, "words.txt")
      File.write(path, words.join("\n"))
      Kotoshu::Dictionary::UnixWords.new(path, language_code: "en")
    end

    it_behaves_like "a mutable dictionary backend"
  end
end
