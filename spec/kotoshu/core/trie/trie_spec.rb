# frozen_string_literal: true

require "kotoshu"
require "tempfile"

# Direct spec for the Core::Trie namespace: Node, Trie, and Builder.
#
# The trie is the foundational data structure backing IndexedDictionary
# and prefix-based suggestion strategies. None of the three files had
# a direct spec — only exercised indirectly via integration tests.
RSpec.describe Kotoshu::Core::Trie::Node do
  let(:node) { described_class.new("a") }

  describe "#initialize" do
    it "defaults the character to empty string" do
      expect(described_class.new.character).to eq("")
    end

    it "accepts an explicit character" do
      expect(described_class.new("x").character).to eq("x")
    end

    it "starts not terminal" do
      expect(node).not_to be_terminal
    end

    it "starts with an empty children hash" do
      expect(node.child_count).to eq(0)
      expect(node).not_to have_children
    end

    it "starts with a nil payload" do
      expect(node.payload).to be_nil
    end
  end

  describe "#add_child" do
    it "creates a new child node" do
      child = node.add_child("b")
      expect(child).to be_a(described_class)
      expect(child.character).to eq("b")
    end

    it "is idempotent — returns the existing child if added twice" do
      first = node.add_child("b")
      second = node.add_child("b")
      expect(second).to be(first)
    end
  end

  describe "#child / #has_child?" do
    it "returns the child node for an existing character" do
      node.add_child("b")
      expect(node.child("b")).to be_a(described_class)
    end

    it "returns nil for a missing character" do
      expect(node.child("z")).to be_nil
    end

    it "reports has_child? accurately" do
      expect(node).not_to have_child("b")
      node.add_child("b")
      expect(node).to have_child("b")
    end
  end

  describe "#mark_terminal / #terminal?" do
    it "marks the node as terminal" do
      expect { node.mark_terminal }.to change(node, :terminal?).from(false).to(true)
    end

    it "stores a payload when one is given" do
      node.mark_terminal({ score: 42 })
      expect(node.payload).to eq(score: 42)
    end

    it "overwrites a previously nil payload when no payload is given" do
      node.mark_terminal("first")
      node.mark_terminal
      expect(node.payload).to be_nil
    end
  end

  describe "#all_children / #has_children? / #child_count" do
    it "returns the children hash" do
      node.add_child("b")
      node.add_child("c")
      expect(node.all_children.keys).to contain_exactly("b", "c")
    end

    it "updates child_count as children are added" do
      expect { node.add_child("b") }.to change(node, :child_count).by(1)
      expect { node.add_child("c") }.to change(node, :child_count).by(1)
    end

    it "flips has_children? once a child exists" do
      expect(node).not_to have_children
      node.add_child("b")
      expect(node).to have_children
    end
  end

  describe "#to_s / #inspect" do
    it "includes the character and terminal flag" do
      node.add_child("b")
      expect(node.to_s).to include("Node('a'")
      expect(node.to_s).to include("terminal: false")
      expect(node.to_s).to include("children: [\"b\"]")
    end

    it "aliases inspect to to_s" do
      expect(node.inspect).to eq(node.to_s)
    end
  end
end

RSpec.describe Kotoshu::Core::Trie::Trie do
  let(:trie) { described_class.new }

  describe "#initialize" do
    it "starts empty" do
      expect(described_class.new).to be_empty
      expect(described_class.new.size).to eq(0)
    end

    it "exposes a root Node" do
      expect(described_class.new.root).to be_a(Kotoshu::Core::Trie::Node)
    end
  end

  describe "#insert / #lookup" do
    it "inserts a word and confirms it via lookup" do
      trie.insert("hello")
      expect(trie.lookup("hello")).to be true
    end

    it "returns false for a word that was never inserted" do
      trie.insert("hello")
      expect(trie.lookup("world")).to be false
    end

    it "returns false for a prefix that is not itself a word" do
      trie.insert("hello")
      expect(trie.lookup("hel")).to be false
    end

    it "increments size only for new words" do
      expect { trie.insert("cat") }.to change(trie, :size).by(1)
      expect { trie.insert("cat") }.not_to change(trie, :size)
    end

    it "aliases has_word? and contains? to lookup" do
      trie.insert("cat")
      expect(trie.has_word?("cat")).to be true
      expect(trie.contains?("cat")).to be true
    end

    it "returns self for chaining" do
      expect(trie.insert("cat")).to be(trie)
    end
  end

  describe "#has_prefix?" do
    it "returns true when any word starts with the prefix" do
      trie.insert("hello")
      expect(trie.has_prefix?("hel")).to be true
      expect(trie.has_prefix?("hello")).to be true
    end

    it "returns false when no word has the prefix" do
      trie.insert("hello")
      expect(trie.has_prefix?("world")).to be false
    end
  end

  describe "#find_node" do
    it "returns the terminal node for an inserted word" do
      trie.insert("cat")
      node = trie.find_node("cat")
      expect(node).to be_terminal
    end

    it "returns an interior node for a prefix" do
      trie.insert("cat")
      node = trie.find_node("ca")
      expect(node).not_to be_nil
      expect(node).not_to be_terminal
    end

    it "returns nil when the prefix is absent" do
      expect(trie.find_node("zzz")).to be_nil
    end
  end

  describe "#words_with_prefix" do
    before do
      %w[cat car card care carpet dog].each { |w| trie.insert(w) }
    end

    it "returns all words starting with the prefix" do
      expect(trie.words_with_prefix("ca").sort).to eq(%w[car card care carpet cat])
    end

    it "returns the single word when the prefix is a full word" do
      expect(trie.words_with_prefix("cat")).to eq(["cat"])
    end

    it "returns an empty array when no words match" do
      expect(trie.words_with_prefix("zzz")).to eq([])
    end
  end

  describe "#all_words" do
    it "returns every word in insertion traversal order" do
      %w[cat dog bird].each { |w| trie.insert(w) }
      expect(trie.all_words.sort).to eq(%w[bird cat dog])
    end

    it "returns an empty array for an empty trie" do
      expect(trie.all_words).to eq([])
    end
  end

  describe "#count_prefix" do
    it "counts words with the given prefix" do
      %w[cat car card].each { |w| trie.insert(w) }
      expect(trie.count_prefix("ca")).to eq(3)
      expect(trie.count_prefix("car")).to eq(2)
      expect(trie.count_prefix("zzz")).to eq(0)
    end
  end

  describe "#suggestions" do
    before do
      %w[cat car card carpet cabin].each { |w| trie.insert(w) }
    end

    it "returns completions sharing the longest matching prefix" do
      suggestions = trie.suggestions("ca")
      expect(suggestions).to include("cat", "car", "card", "carpet", "cabin")
    end

    it "honours the max_results cap" do
      suggestions = trie.suggestions("ca", max_results: 2)
      expect(suggestions.size).to be <= 2
    end
  end

  describe "#each_word" do
    it "yields word and payload for terminal nodes" do
      trie.insert("cat", "meow")
      trie.insert("dog", "bark")
      pairs = []
      trie.each_word { |w, p| pairs << [w, p] }
      expect(pairs.sort).to eq([["cat", "meow"], ["dog", "bark"]])
    end

    it "returns an Enumerator when no block is given" do
      trie.insert("cat")
      expect(trie.each_word).to be_an(Enumerator)
    end
  end

  describe "#traverse" do
    it "visits every node with its accumulated prefix" do
      trie.insert("ab")
      visited = []
      trie.traverse { |prefix, _node| visited << prefix }
      expect(visited).to include("", "a", "ab")
    end

    it "returns an Enumerator when no block is given" do
      expect(trie.traverse).to be_an(Enumerator)
    end
  end

  describe "#clear" do
    it "empties the trie" do
      trie.insert("cat")
      expect { trie.clear }.to change(trie, :size).to(0)
      expect(trie.lookup("cat")).to be false
    end

    it "returns self for chaining" do
      expect(trie.clear).to be(trie)
    end
  end

  describe "#merge!" do
    it "absorbs words from the other trie" do
      other = described_class.new
      other.insert("dog")
      trie.insert("cat")
      trie.merge!(other)
      expect(trie.lookup("cat")).to be true
      expect(trie.lookup("dog")).to be true
    end

    it "returns self" do
      other = described_class.new
      expect(trie.merge!(other)).to be(trie)
    end
  end

  describe "#& (intersection)" do
    it "produces a new trie with words in both" do
      trie.insert("cat")
      trie.insert("dog")
      other = described_class.new
      other.insert("dog")
      other.insert("bird")

      intersection = trie & other
      expect(intersection.lookup("dog")).to be true
      expect(intersection.lookup("cat")).to be false
      expect(intersection.lookup("bird")).to be false
    end
  end

  describe "#| (union)" do
    it "produces a new trie with words from both" do
      trie.insert("cat")
      other = described_class.new
      other.insert("dog")

      union = trie | other
      expect(union.lookup("cat")).to be true
      expect(union.lookup("dog")).to be true
    end
  end

  describe "#to_s / #inspect" do
    it "includes the size" do
      trie.insert("cat")
      expect(trie.to_s).to eq("Trie(size: 1)")
    end

    it "aliases inspect to to_s" do
      expect(trie.inspect).to eq(trie.to_s)
    end
  end
end

RSpec.describe Kotoshu::Core::Trie::Builder do
  describe "#add_word" do
    it "inserts the word into the underlying trie" do
      builder = described_class.new
      builder.add_word("hello")
      trie = builder.build
      expect(trie.lookup("hello")).to be true
    end

    it "returns self for chaining" do
      builder = described_class.new
      expect(builder.add_word("hello")).to be(builder)
    end

    it "aliases << to add_word" do
      builder = described_class.new
      builder << "hello"
      expect(builder.build.lookup("hello")).to be true
    end
  end

  describe "#add_words" do
    it "inserts every word" do
      trie = described_class.new.add_words(%w[cat dog bird]).build
      expect(trie.all_words.sort).to eq(%w[bird cat dog])
    end

    it "returns self for chaining" do
      builder = described_class.new
      expect(builder.add_words(%w[cat])).to be(builder)
    end
  end

  describe "#from_hash" do
    it "inserts words with payloads" do
      builder = described_class.new
      builder.from_hash({ "cat" => "meow", "dog" => "bark" })
      trie = builder.build
      pairs = trie.each_word.to_a.sort
      expect(pairs).to eq([["cat", "meow"], ["dog", "bark"]])
    end
  end

  describe "#from_array" do
    it "inserts every word from the array" do
      trie = described_class.new.from_array(%w[cat dog]).build
      expect(trie.all_words.sort).to eq(%w[cat dog])
    end
  end

  describe "#from_string" do
    it "inserts words from a newline-separated string" do
      trie = described_class.new.from_string("cat\ndog\n\n# comment\n").build
      expect(trie.all_words.sort).to eq(%w[cat dog])
    end
  end

  describe "#from_file" do
    it "inserts words from a file, ignoring blanks and comments" do
      Tempfile.create(["words", ".txt"]) do |f|
        f.puts "cat"
        f.puts ""
        f.puts "# comment"
        f.puts "dog"
        f.close
        trie = described_class.new.from_file(f.path).build
        expect(trie.all_words.sort).to eq(%w[cat dog])
      end
    end
  end

  describe "#build" do
    it "returns a frozen Trie" do
      trie = described_class.new.add_word("cat").build
      expect(trie).to be_frozen
    end
  end

  describe "class methods" do
    it ".from_array builds a trie directly" do
      trie = described_class.from_array(%w[cat dog])
      expect(trie.lookup("cat")).to be true
      expect(trie.lookup("dog")).to be true
    end

    it ".from_hash builds a trie with payloads" do
      trie = described_class.from_hash({ "cat" => "meow" })
      expect(trie.each_word.to_a).to include(["cat", "meow"])
    end

    it ".from_string builds a trie from text" do
      trie = described_class.from_string("cat\ndog\n")
      expect(trie.all_words.sort).to eq(%w[cat dog])
    end

    it ".from_file builds a trie from a file" do
      Tempfile.create(["words", ".txt"]) do |f|
        f.puts "cat"
        f.puts "dog"
        f.close
        trie = described_class.from_file(f.path)
        expect(trie.all_words.sort).to eq(%w[cat dog])
      end
    end
  end
end
