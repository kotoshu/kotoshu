# frozen_string_literal: true

require "kotoshu"
require "tmpdir"
require "fileutils"
require "stringio"

# Direct spec for the personal-dictionary CLI subcommand.
#
# The command is a thin Thor wrapper over Kotoshu::PersonalDictionary.
# These specs exercise the wiring by calling the public Thor methods
# directly (rather than going through Thor.start, which intercepts
# Thor::Error before it can propagate). A real tmpdir-backed
# personal.dic file is used — no doubles.
RSpec.describe Kotoshu::Cli::PersonalCommand do
  let(:tmpdir) { Dir.mktmpdir("kotoshu-personal-cli-spec") }
  let(:personal_dic) { File.join(tmpdir, "personal.dic") }

  around do |example|
    original = ENV.fetch("KOTOSHU_PERSONAL_DIC", nil)
    ENV["KOTOSHU_PERSONAL_DIC"] = personal_dic
    begin
      example.run
    ensure
      ENV["KOTOSHU_PERSONAL_DIC"] = original
    end
  end

  after { FileUtils.rm_rf(tmpdir) if File.exist?(tmpdir) }

  def cli(options = {})
    described_class.new([], options)
  end

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  describe "#add" do
    it "adds words and reports the count" do
      out = capture_stdout { cli.add("foo", "bar") }
      expect(out).to match(/Added 2 words/)
      expect(Kotoshu::PersonalDictionary.words).to contain_exactly("foo", "bar")
    end

    it "ignores duplicates" do
      cli.add("foo")
      out = capture_stdout { cli.add("foo", "bar") }
      expect(out).to match(/Added 1 word/)
    end

    it "raises UsageError when called with no words" do
      expect { cli.add }.to raise_error(Kotoshu::Cli::Errors::UsageError, /No words given/)
    end
  end

  describe "#remove" do
    before { cli.add("foo", "bar", "baz") }

    it "removes words and reports the count" do
      out = capture_stdout { cli.remove("foo", "bar") }
      expect(out).to match(/Removed 2 words/)
      expect(Kotoshu::PersonalDictionary.words).to eq(["baz"])
    end

    it "ignores words not in the dictionary" do
      out = capture_stdout { cli.remove("missing") }
      expect(out).to match(/Removed 0 words/)
    end
  end

  describe "#list" do
    it "prints every word one per line" do
      cli.add("alpha", "beta")
      out = capture_stdout { cli.list }
      expect(out.split("\n")).to contain_exactly("alpha", "beta")
    end

    it "prints (empty) when nothing is added" do
      out = capture_stdout { cli.list }
      expect(out).to match(/empty/)
    end
  end

  describe "#import" do
    let(:source_file) { File.join(tmpdir, "terms.txt") }

    before do
      File.write(source_file, "alpha\nbeta\n# comment\n\ngamma\n")
    end

    it "adds non-comment, non-blank lines" do
      out = capture_stdout { cli.import(source_file) }
      expect(out).to match(/Imported 3 words/)
      expect(Kotoshu::PersonalDictionary.words).to contain_exactly("alpha", "beta", "gamma")
    end

    it "dry_run mode lists what would be added without writing" do
      out = capture_stdout { cli(dry_run: true).import(source_file) }
      expect(out).to match(/Would import 3 words/)
      expect(Kotoshu::PersonalDictionary.words).to eq([])
    end

    it "raises UsageError when a file does not exist" do
      expect { cli.import("/nonexistent/terms.txt") }
        .to raise_error(Kotoshu::Cli::Errors::UsageError, /File not found/)
    end
  end

  describe "#path" do
    it "prints the on-disk location of the personal dictionary" do
      out = capture_stdout { cli.path }
      expect(out.chomp).to eq(personal_dic)
    end
  end

  describe "#clear" do
    before { cli.add("foo", "bar") }

    it "wipes the file when --yes is passed" do
      out = capture_stdout { cli(yes: true).clear }
      expect(out).to match(/Cleared/)
      expect(Kotoshu::PersonalDictionary.words).to eq([])
    end

    it "is a no-op when stdin returns 'n'" do
      allow($stdin).to receive(:gets).and_return("n\n")
      out = capture_stdout { cli.clear }
      expect(out).to match(/Clear the entire personal dictionary/) # prompt only
      expect(Kotoshu::PersonalDictionary.words).to contain_exactly("foo", "bar")
    end
  end

  describe "wiring into kotoshu CLI" do
    it "is registered as a subcommand on Kotoshu::Cli::Cli" do
      expect(Kotoshu::Cli::Cli.subcommands).to include("personal")
    end
  end
end
