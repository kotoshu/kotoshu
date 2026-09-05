# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"
require "kotoshu/cli/ignore_matcher"

# Behavior specs for the .gitignore/.ignore glob subset (plan 88).
# Real ignore files written to real tmpdirs; no doubles.
RSpec.describe Kotoshu::Cli::IgnoreMatcher do
  def matcher_for(*lines)
    described_class.new(lines)
  end

  describe "plain name patterns" do
    it "matches the basename at any depth" do
      matcher = matcher_for("todo.txt")
      expect(matcher.ignored?("todo.txt")).to be true
      expect(matcher.ignored?("docs/todo.txt")).to be true
      expect(matcher.ignored?("deep/nested/dir/todo.txt")).to be true
    end

    it "does not match different names or substrings" do
      matcher = matcher_for("todo.txt")
      expect(matcher.ignored?("todo.md")).to be false
      expect(matcher.ignored?("my-todo.txt")).to be false
      expect(matcher.ignored?("todo.txt.bak")).to be false
    end
  end

  describe "* and ? globs" do
    it "matches any characters except the path separator" do
      matcher = matcher_for("*.log")
      expect(matcher.ignored?("debug.log")).to be true
      expect(matcher.ignored?("build/debug.log")).to be true
      expect(matcher.ignored?("nested/debug.log")).to be true
      expect(matcher.ignored?("debug.log2")).to be false
    end

    it "does not let a lone star cross directories" do
      matcher = matcher_for("docs/*.md")
      expect(matcher.ignored?("docs/readme.md")).to be true
      expect(matcher.ignored?("docs/guides/readme.md")).to be false
      expect(matcher.ignored?("other/readme.md")).to be false
    end

    it "matches exactly one character with ?" do
      matcher = matcher_for("file?.txt")
      expect(matcher.ignored?("file1.txt")).to be true
      expect(matcher.ignored?("file12.txt")).to be false
    end
  end

  describe "** globstar" do
    it "matches a name at any depth with **/name" do
      matcher = matcher_for("**/tmp")
      expect(matcher.ignored?("tmp")).to be true
      expect(matcher.ignored?("a/tmp")).to be true
      expect(matcher.ignored?("a/b/c/tmp")).to be true
    end

    it "matches everything below a directory with dir/**" do
      matcher = matcher_for("build/**")
      expect(matcher.ignored?("build/x.log")).to be true
      expect(matcher.ignored?("build/nested/y.log")).to be true
      expect(matcher.ignored?("build")).to be false
      expect(matcher.ignored?("buildx/y.log")).to be false
    end

    it "matches any depth between two anchors with a/**/b" do
      matcher = matcher_for("a/**/b")
      expect(matcher.ignored?("a/b")).to be true
      expect(matcher.ignored?("a/x/b")).to be true
      expect(matcher.ignored?("a/x/y/b")).to be true
      expect(matcher.ignored?("x/a/b")).to be false
    end

    it "matches everything with a lone **" do
      matcher = matcher_for("**")
      expect(matcher.ignored?("anything/at/all.txt")).to be true
    end
  end

  describe "anchoring" do
    it "anchors patterns containing a slash to the ignore directory" do
      matcher = matcher_for("docs/generated")
      expect(matcher.ignored?("docs/generated")).to be true
      expect(matcher.ignored?("docs/generated/deep.md")).to be true
      expect(matcher.ignored?("site/docs/generated")).to be false
    end

    it "anchors patterns with a leading slash only at the top" do
      matcher = matcher_for("/root-only.txt")
      expect(matcher.ignored?("root-only.txt")).to be true
      expect(matcher.ignored?("sub/root-only.txt")).to be false
    end
  end

  describe "directory-only patterns" do
    it "matches directories, not files, with a trailing slash" do
      matcher = matcher_for("dist/")
      expect(matcher.ignored?("dist", directory: true)).to be true
      expect(matcher.ignored?("a/dist", directory: true)).to be true
      expect(matcher.ignored?("dist")).to be false
    end
  end

  describe "negation" do
    it "re-includes a file negated after a matching pattern" do
      matcher = matcher_for("*.log", "!keep.log")
      expect(matcher.ignored?("debug.log")).to be true
      expect(matcher.ignored?("keep.log")).to be false
    end

    it "lets the last matching pattern win" do
      matcher = matcher_for("!keep.log", "*.log")
      expect(matcher.ignored?("keep.log")).to be true
    end

    it "negates directory patterns too" do
      matcher = matcher_for("docs/", "!docs/README.md")
      expect(matcher.ignored?("docs", directory: true)).to be true
      expect(matcher.ignored?("docs/README.md")).to be false
    end
  end

  describe "comments, blanks and escapes" do
    it "skips blank lines and comments" do
      matcher = matcher_for("", "   ", "# a comment", "*.log")
      expect(matcher.patterns.size).to eq(1)
      expect(matcher.ignored?("x.log")).to be true
    end

    it "treats escaped ! and # as literals" do
      matcher = matcher_for("\\!important.log", "\\#hash.log")
      expect(matcher.ignored?("!important.log")).to be true
      expect(matcher.ignored?("#hash.log")).to be true
    end
  end

  describe ".load_directory" do
    around do |example|
      Dir.mktmpdir do |dir|
        @dir = dir
        example.run
      end
    end

    it "loads .gitignore and .ignore together, .ignore last" do
      File.write(File.join(@dir, ".gitignore"), "*.log\n")
      File.write(File.join(@dir, ".ignore"), "!keep.log\n")

      matcher = described_class.load_directory(@dir)
      expect(matcher.patterns.size).to eq(2)
      expect(matcher.ignored?("debug.log")).to be true
      expect(matcher.ignored?("keep.log")).to be false
    end

    it "returns an empty matcher when neither file exists" do
      matcher = described_class.load_directory(@dir)
      expect(matcher.patterns).to be_empty
      expect(matcher.ignored?("anything")).to be false
    end

    it "detects presence without loading" do
      expect(described_class.present_in?(@dir)).to be false
      File.write(File.join(@dir, ".ignore"), "x\n")
      expect(described_class.present_in?(@dir)).to be true
    end
  end
end
