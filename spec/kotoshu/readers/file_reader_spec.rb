# frozen_string_literal: true

require "kotoshu"
require "tmpdir"
require "fileutils"

# Direct spec for Readers::FileReader, Readers::StringReader, and
# Readers::ZipReader — the line-by-line file readers that feed
# AffReader and DicReader.
RSpec.describe Kotoshu::Readers::FileReader do
  let(:tmpdir) { Dir.mktmpdir("kotoshu-reader-spec") }
  let(:aff_path) { write_file("test.aff", "SET UTF-8\nTRY esethnto\nSFX A Y 1\nSFX A 0 ed .\n") }

  after { FileUtils.rm_rf(tmpdir) if File.exist?(tmpdir) }

  def write_file(name, content)
    path = File.join(tmpdir, name)
    File.write(path, content)
    path
  end

  describe "#initialize" do
    it "opens the file and exposes path and encoding" do
      reader = described_class.new(aff_path, "UTF-8")
      expect(reader.path).to eq(aff_path)
      expect(reader.encoding).to eq("UTF-8")
      expect(reader.line_no).to eq(0)
    ensure
      reader&.close
    end
  end

  describe "#each" do
    it "yields [line_no, line] pairs with stripped content" do
      reader = described_class.new(aff_path)
      lines = reader.to_a
      expect(lines.length).to eq(4)
      expect(lines.first).to eq([1, "SET UTF-8"])
      expect(lines.last).to eq([4, "SFX A 0 ed ."])
    ensure
      reader&.close
    end

    it "skips empty lines and increments line_no correctly" do
      path = write_file("blanks.txt", "line1\n\n\nline2\n")
      reader = described_class.new(path)
      lines = reader.to_a
      expect(lines).to eq([[1, "line1"], [4, "line2"]])
    ensure
      reader&.close
    end

    it "returns an Enumerator when no block is given" do
      reader = described_class.new(aff_path)
      expect(reader.each).to be_an(Enumerator)
    ensure
      reader&.close
    end
  end

  describe "BOM handling" do
    it "strips a UTF-8 BOM from the first line" do
      path = File.join(tmpdir, "bom.txt")
      File.binwrite(path, "\xEF\xBB\xBFhello\nworld\n")
      reader = described_class.new(path)
      lines = reader.to_a
      expect(lines.first[1]).to eq("hello")
    ensure
      reader&.close
    end
  end

  describe "#has_next? / #next / #peek" do
    it "supports iterator-style consumption" do
      reader = described_class.new(aff_path)
      expect(reader.has_next?).to be true
      first = reader.next
      expect(first).to eq([1, "SET UTF-8"])
      reader.next
      reader.next
      reader.next
      expect(reader.has_next?).to be false
    ensure
      reader&.close
    end
  end

  describe "#reset_encoding" do
    it "reopens the file with a new encoding and resets line_no" do
      reader = described_class.new(aff_path, "UTF-8")
      reader.to_a
      reader.reset_encoding("ISO-8859-1")
      expect(reader.encoding).to eq("ISO-8859-1")
      expect(reader.line_no).to eq(0)
    ensure
      reader&.close
    end
  end

  describe "#reset" do
    it "resets to the beginning" do
      reader = described_class.new(aff_path)
      reader.to_a
      reader.reset
      expect(reader.line_no).to eq(0)
      expect(reader.to_a.first).to eq([1, "SET UTF-8"])
    ensure
      reader&.close
    end
  end

  describe "encoding transcoding" do
    it "transcodes ISO-8859-1 to UTF-8" do
      path = File.join(tmpdir, "latin1.txt")
      File.binwrite(path, "caf\xE9\n") # é in Latin-1
      reader = described_class.new(path, "ISO-8859-1")
      lines = reader.to_a
      expect(lines.first[1]).to eq("café")
    ensure
      reader&.close
    end

    it "falls back to ISO-8859-1 when the declared encoding is invalid" do
      path = File.join(tmpdir, "broken.txt")
      File.binwrite(path, "caf\xE9\n")
      # Declare UTF-8 but the file is actually Latin-1.
      reader = described_class.new(path, "UTF-8")
      lines = reader.to_a
      expect(lines.first[1]).to include("caf")
    ensure
      reader&.close
    end
  end
end

RSpec.describe Kotoshu::Readers::StringReader do
  describe "#each" do
    it "yields [line_no, line] pairs from a string" do
      reader = described_class.new("SET UTF-8\nTRY abc\n\nSFX A Y 1\n")
      lines = reader.to_a
      expect(lines.length).to eq(3)
      expect(lines.first).to eq([1, "SET UTF-8"])
      expect(lines.last).to eq([4, "SFX A Y 1"])
    end

    it "skips empty lines" do
      reader = described_class.new("a\n\nb\n")
      lines = reader.to_a
      expect(lines).to eq([[1, "a"], [3, "b"]])
    end

    it "strips UTF-8 BOM from the first line" do
      reader = described_class.new("\xEF\xBB\xBFhello\nworld\n")
      lines = reader.to_a
      expect(lines.first[1]).to eq("hello")
    end

    it "returns an Enumerator when no block is given" do
      reader = described_class.new("hello\n")
      expect(reader.each).to be_an(Enumerator)
    end
  end

  describe "#reset" do
    it "resets to the beginning" do
      reader = described_class.new("a\nb\n")
      reader.to_a
      reader.reset
      expect(reader.to_a.first).to eq([1, "a"])
    end
  end
end

RSpec.describe Kotoshu::Readers::ZipReader, if: defined?(Zip) do
  let(:tmpdir) { Dir.mktmpdir("kotoshu-zip-spec") }

  after { FileUtils.rm_rf(tmpdir) if File.exist?(tmpdir) }

  it "reads lines from a zip entry" do
    zip_path = File.join(tmpdir, "test.zip")
    Zip::File.open(zip_path, Zip::File::CREATE) do |zip|
      zip.get_output_stream("data.txt") { |f| f.write("line1\nline2\n\nline3\n") }
    end

    Zip::File.open(zip_path) do |zipfile|
      reader = described_class.new(zipfile, "data.txt", "UTF-8")
      lines = reader.to_a
      expect(lines).to eq([[1, "line1"], [2, "line2"], [4, "line3"]])
    end
  end
end
