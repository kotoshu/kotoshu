# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kotoshu::Components::CLEPosReader do
  # Synthetic fixture in the exact CLE delivery format (word/TAG pairs,
  # BOM, whitespace-separated). The real human-verified sample lives in
  # the licensed pk-cle-urdu checkout and is NOT copied into the gem.
  let(:doc) do
    "﻿اللہ/NNP نے/PSP پاکستان/NNP کو/PSP ہر/JJ نعمت/NN " \
      "دے/VBF دی/PU ۔/PU\n"
  end

  describe ".parse" do
    it "parses word/TAG pairs and strips the BOM" do
      pairs, unknown = described_class.parse(doc)
      expect(pairs.first).to eq(["اللہ", "NNP"])
      expect(pairs.map(&:last)).to include("PSP", "NN", "VBF", "PU")
      expect(unknown).to be_empty
    end

    it "splits on the last slash so slashes in words stay intact" do
      pairs, = described_class.parse("a/b/NN")
      expect(pairs).to eq([["a/b", "NN"]])
    end

    it "collects unknown tags in strict mode" do
      expect { described_class.parse("گھر/XYZ", strict: true) }
        .to raise_error(Kotoshu::Error, /unknown CLE tags: XYZ/)
    end

    it "answers unknown tags non-strictly" do
      pairs, unknown = described_class.parse("گھر/XYZ گھر/NN")
      expect(pairs.length).to eq(2)
      expect(unknown).to eq(%w[XYZ])
    end
  end

  describe ".parse_file" do
    it "reads a BOM'd delivery file" do
      path = File.join(Dir.mktmpdir, "press_100k_001.txt")
      File.binwrite(path, doc)
      pairs, = described_class.parse_file(path)
      expect(pairs.first).to eq(["اللہ", "NNP"])
    end
  end

  describe ".parse_dir" do
    it "maps every delivery file by path" do
      dir = Dir.mktmpdir
      File.binwrite(File.join(dir, "a.txt"), doc)
      File.binwrite(File.join(dir, "b.txt"), doc)
      out = described_class.parse_dir(dir)
      expect(out.keys.sort).to eq([File.join(dir, "a.txt"), File.join(dir, "b.txt")])
    end
  end
end
