# frozen_string_literal: true

require "kotoshu"
require "stringio"
require "tmpdir"
require "fileutils"

RSpec.describe Kotoshu::Cli::CompletionsCommand do
  let(:tmpdir) { Dir.mktmpdir("kotoshu-completions") }

  after { FileUtils.rm_rf(tmpdir) }

  def capture
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  def create_cli
    described_class.new
  end

  describe "#bash" do
    it "emits a syntactically valid bash completion script" do
      output = capture { create_cli.bash }

      expect(output).to include("# kotoshu bash completion")
      expect(output).to include("complete -F _kotoshu_completions kotoshu")
      expect(output).to include("compgen -W \"check setup status dict cache completions version fetch\"")
    end

    it "includes the language-argument branch for setup and fetch" do
      output = capture { create_cli.bash }

      expect(output).to include("setup|fetch)")
      expect(output).to include("kotoshu completions languages")
    end

    it "documents the install path" do
      output = capture { create_cli.bash }
      expect(output).to include("/etc/bash_completion.d/kotoshu")
    end
  end

  describe "#zsh" do
    it "emits a #compdef header and a _kotoshu function" do
      output = capture { create_cli.zsh }

      expect(output).to start_with("#compdef kotoshu")
      expect(output).to include("_kotoshu()")
      expect(output).to include("_kotoshu \"$@\"")
    end

    it "describes every top-level command" do
      output = capture { create_cli.zsh }

      %w[check setup status dict cache completions version fetch].each do |cmd|
        expect(output).to include("'#{cmd}:")
      end
    end

    it "shells out to kotoshu completions languages for setup/fetch" do
      output = capture { create_cli.zsh }
      expect(output).to include('"${(@f)$(kotoshu completions languages 2>/dev/null)}"')
    end
  end

  describe "#fish" do
    it "emits one complete line per top-level command" do
      output = capture { create_cli.fish }

      %w[check setup status dict cache completions version fetch].each do |cmd|
        expect(output).to include(%(-a "#{cmd}"))
      end
    end

    it "adds language completion for setup and fetch" do
      output = capture { create_cli.fish }

      expect(output).to include("__fish_seen_subcommand_from setup")
      expect(output).to include("__fish_seen_subcommand_from fetch")
    end

    it "documents the install path" do
      output = capture { create_cli.fish }
      expect(output).to include("~/.config/fish/completions/kotoshu.fish")
    end
  end

  describe "#languages" do
    it "emits supported language codes one per line" do
      output = capture { create_cli.languages }
      codes = output.split("\n")

      expect(codes).to include("en", "de", "fr", "es", "pt", "ru")
      expect(codes).to all(match(/\A[a-z]{2}(-[A-Z]{2})?\z/))
    end

    it "is non-empty" do
      output = capture { create_cli.languages }
      expect(output.split("\n").size).to be > 0
    end
  end

  describe "Kotoshu::Cli::Completions::ScriptBuilders" do
    let(:builders) { Kotoshu::Cli::Completions::ScriptBuilders }
    let(:commands) do
      [
        Kotoshu::Cli::Completions::Command.new(name: "alpha", description: "first"),
        Kotoshu::Cli::Completions::Command.new(name: "beta",  description: "second")
      ]
    end

    describe ".indent" do
      it "indents every line by the given count" do
        text = "line1\nline2\n"
        result = builders.indent(text, 4)
        expect(result).to eq("    line1\n    line2\n")
      end

      it "is a no-op at zero indent" do
        text = "line\n"
        expect(builders.indent(text, 0)).to eq(text)
      end
    end

    context "with no language-argument commands" do
      it "renders a placeholder line instead of an empty case branch" do
        bash = builders::Bash.build(commands, [])
        zsh  = builders::Zsh.build(commands, [])

        expect(bash).to include("(no language-argument commands registered)")
        expect(zsh).to include("(no language-argument commands registered)")
      end
    end

    context "with custom language-argument commands" do
      it "renders one case branch per language-argument command" do
        bash = builders::Bash.build(commands, ["alpha"])
        expect(bash).to include("alpha)")
      end
    end
  end

  describe Kotoshu::Cli::Completions::Command do
    it "is a keyword-initialised Struct with name and description" do
      cmd = described_class.new(name: "check", description: "Check spelling")
      expect(cmd.name).to eq("check")
      expect(cmd.description).to eq("Check spelling")
    end
  end

  describe "the wired CLI exposes `completions` as a subcommand" do
    it "lists `completions` in `kotoshu help`" do
      output = capture { Kotoshu::Cli::Cli.start(%w[help]) }
      expect(output).to include("completions")
    end

    it "lists bash/zsh/fish/languages under `kotoshu completions help`" do
      output = capture { Kotoshu::Cli::Cli.start(%w[completions help]) }
      %w[bash zsh fish languages].each do |sub|
        expect(output).to include(sub)
      end
    end
  end
end
