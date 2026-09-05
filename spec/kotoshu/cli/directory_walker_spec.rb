# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"
require "kotoshu/cli/directory_walker"

# Behavior specs for the directory walker (plan 88): real tmpdir
# trees, real .gitignore/.ignore files, no doubles.
RSpec.describe Kotoshu::Cli::DirectoryWalker do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = dir
      example.run
    end
  end

  def write(relative, content = "hello world\n")
    path = File.join(@root, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
    path
  end

  def relatives(paths)
    paths.map { |path| path.delete_prefix("#{@root}/") }
  end

  def walk(**options)
    relatives(described_class.new(**options).files(@root))
  end

  describe "extension selection" do
    it "selects the known text extensions" do
      %w[a.md b.markdown c.asciidoc d.adoc e.txt f.rst g.mdx].each { |name| write(name) }

      expect(walk).to eq(%w[a.md b.markdown c.asciidoc d.adoc e.txt f.rst g.mdx])
    end

    it "skips unknown extensions" do
      write("doc.md")
      write("photo.png")
      write("app.rb")
      write("data.json")

      expect(walk).to eq(["doc.md"])
    end

    it "finds files at any depth, deterministically sorted" do
      write("zebra.md")
      write("docs/alpha.md")
      write("docs/nested/beta.md")
      write("docs/nested/deep/gamma.md")

      expect(walk).to eq(["docs/alpha.md", "docs/nested/beta.md", "docs/nested/deep/gamma.md", "zebra.md"])
    end
  end

  describe "default skips" do
    it "skips the default directories" do
      %w[.git node_modules vendor target].each do |dir|
        write("#{dir}/notes.md")
      end
      write("keep.md")

      expect(walk).to eq(["keep.md"])
    end

    it "skips hidden files and directories" do
      write(".hidden.md")
      write(".config/settings.md")
      write("visible.md")

      expect(walk).to eq(["visible.md"])
    end
  end

  describe "--include and --exclude" do
    before do
      write("docs/readme.md")
      write("docs/guide.adoc")
      write("notes.txt")
      write("photo.png")
    end

    it "replaces the extension default with include globs" do
      expect(walk(include_globs: ["*.adoc"])).to eq(["docs/guide.adoc"])
    end

    it "matches slashless globs against the basename at any depth" do
      expect(walk(include_globs: ["*.md"])).to eq(["docs/readme.md"])
    end

    it "matches slashed globs against the path from the root" do
      expect(walk(include_globs: ["docs/*.md"])).to eq(["docs/readme.md"])
      expect(walk(include_globs: ["*.md", "*.txt"])).to include("docs/readme.md", "notes.txt")
    end

    it "checks non-text files when included explicitly" do
      expect(walk(include_globs: ["*.png"])).to eq(["photo.png"])
    end

    it "excludes always win over the extension default" do
      expect(walk(exclude_globs: ["*.md"])).to eq(["docs/guide.adoc", "notes.txt"])
    end

    it "excludes win over includes" do
      expect(walk(include_globs: %w[*.md *.adoc], exclude_globs: ["*.adoc"])).to eq(["docs/readme.md"])
    end
  end

  describe ".gitignore and .ignore support" do
    it "ignores matched files" do
      write("keep.md")
      write("draft.md")
      File.write(File.join(@root, ".gitignore"), "draft.md\n")

      expect(walk).to eq(["keep.md"])
    end

    it "honors negation with the last pattern winning" do
      write("gen/a.md")
      write("gen/keep.md")
      File.write(File.join(@root, ".gitignore"), "gen/*.md\n!gen/keep.md\n")

      expect(walk).to eq(["gen/keep.md"])
    end

    it "never descends into ignored directories" do
      write("build/a.md")
      write("build/nested/b.md")
      write("keep.md")
      File.write(File.join(@root, ".gitignore"), "build/\n")

      expect(walk).to eq(["keep.md"])
    end

    it "cannot re-include a file inside an ignored directory" do
      write("build/keep.md")
      File.write(File.join(@root, ".gitignore"), "build/\n!build/keep.md\n")

      expect(walk).to be_empty
    end

    it "supports globstar" do
      write("a/generated/x.md")
      write("b/generated/y.md")
      write("keep.md")
      File.write(File.join(@root, ".gitignore"), "**/generated/\n")

      expect(walk).to eq(["keep.md"])
    end

    it "scopes nested ignore files to their subtree" do
      write("docs/alpha.md")
      write("docs/draft.md")
      write("draft.md")
      File.write(File.join(@root, "docs", ".gitignore"), "draft.md\n")

      expect(walk).to eq(["docs/alpha.md", "draft.md"])
    end

    it "reads .ignore with the same semantics" do
      write("keep.md")
      write("local-only.md")
      File.write(File.join(@root, ".ignore"), "local-only.md\n")

      expect(walk).to eq(["keep.md"])
    end

    it "applies the root ignore to nested paths" do
      write("docs/generated/notes.md")
      write("docs/keep.md")
      File.write(File.join(@root, ".gitignore"), "generated/\n")

      expect(walk).to eq(["docs/keep.md"])
    end
  end
end
