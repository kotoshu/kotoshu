# frozen_string_literal: true

require "thor"

module Kotoshu
  module Cli
    # Catalog of commands the completion scripts know about, plus pure
    # template builders that render shell-specific scripts from the
    # catalog. Kept in a single module so the data and the rendering
    # logic live next to the Thor subcommand that exposes them.
    module Completions
      # Describes a single CLI command for completion purposes.
      Command = Struct.new(:name, :description, keyword_init: true)

      # Top-level commands the bash/zsh/fish scripts will offer. Kept as
      # a static catalog — descriptions are user-facing, so they are
      # curated here rather than introspected from Thor (whose
      # `description` field is often terse).
      COMMANDS = [
        Command.new(name: "check",       description: "Check spelling in a file or stdin"),
        Command.new(name: "setup",       description: "Set up languages (download or register local files)"),
        Command.new(name: "status",      description: "Show setup, cache, and runtime status"),
        Command.new(name: "dict",        description: "Dictionary operations"),
        Command.new(name: "cache",       description: "Cache management"),
        Command.new(name: "completions", description: "Emit shell completion scripts"),
        Command.new(name: "version",     description: "Show version information"),
        Command.new(name: "fetch",       description: "Alias for `setup` (deprecated)")
      ].freeze

      # Commands whose first positional argument is a language code.
      LANGUAGE_ARGUMENT_COMMANDS = %w[setup fetch].freeze

      # Pure template builders. Each takes the catalog and renders a
      # shell-specific completion script. They have no IO dependencies
      # and are unit-tested in isolation.
      module ScriptBuilders
        module_function

        # Indent every line of +text+ by +n+ spaces. Used to align
        # interpolated blocks within their surrounding heredoc body.
        def indent(text, n)
          pad = " " * n
          text.lines.map { |line| "#{pad}#{line}" }.join
        end

        module Bash
          module_function

          def build(commands, language_argument_commands)
            word_list = commands.map(&:name).join(" ")
            lang_branch = language_branch(language_argument_commands)
            <<~BASH
              # kotoshu bash completion — install with:
              #   kotoshu completions bash > /etc/bash_completion.d/kotoshu
              # or for a single user:
              #   kotoshu completions bash > ~/.local/share/bash-completion/completions/kotoshu
              _kotoshu_completions() {
                local cur prev
                cur="${COMP_WORDS[COMP_CWORD]}"
                prev="${COMP_WORDS[COMP_CWORD-1]}"

                if [ "$COMP_CWORD" -eq 1 ]; then
                  COMPREPLY=( $(compgen -W "#{word_list}" -- "$cur") )
                  return 0
                fi

              #{ScriptBuilders.indent(lang_branch, 2)}

                return 0
              }
              complete -F _kotoshu_completions kotoshu
            BASH
          end

          def language_branch(language_argument_commands)
            return "# (no language-argument commands registered)" if language_argument_commands.empty?

            matcher = language_argument_commands.join("|")
            <<~BRANCH
              case "$prev" in
                #{matcher})
                  COMPREPLY=( $(compgen -W "$(kotoshu completions languages 2>/dev/null)" -- "$cur") )
                  return 0
                  ;;
              esac
            BRANCH
          end
          private_class_method :language_branch
        end

        module Zsh
          module_function

          def build(commands, language_argument_commands)
            describe_block = commands.map { |c| "'#{c.name}:#{escape(c.description)}'" }.join(" ")
            lang_case = language_case(language_argument_commands)
            <<~ZSH
              #compdef kotoshu
              # kotoshu zsh completion — install with:
              #   kotoshu completions zsh > "${fpath[1]}/_kotoshu"

              _kotoshu() {
                local -a commands
                commands=(
                  #{describe_block}
                )

                if (( CURRENT == 2 )); then
                  _describe 'command' commands
                  return
                fi

              #{ScriptBuilders.indent(lang_case, 2)}
              }

              _kotoshu "$@"
            ZSH
          end

          def language_case(language_argument_commands)
            return "# (no language-argument commands registered)" if language_argument_commands.empty?

            matcher = language_argument_commands.join("|")
            <<~CASE
              case "$words[2]" in
                #{matcher})
                  local -a langs
                  langs=("${(@f)$(kotoshu completions languages 2>/dev/null)}")
                  _describe 'language' langs
                  ;;
              esac
            CASE
          end
          private_class_method :language_case

          def escape(text)
            text.gsub("'", "''")
          end
          private_class_method :escape
        end

        module Fish
          module_function

          def build(commands, language_argument_commands)
            command_lines = commands.map do |c|
              "complete -c kotoshu -n \"__fish_use_subcommand\" -a \"#{c.name}\" -d \"#{escape(c.description)}\""
            end.join("\n")
            language_lines = language_argument_commands.map do |cmd|
              matcher = "__fish_seen_subcommand_from #{cmd}"
              "complete -c kotoshu -n \"#{matcher}\" -a \"(kotoshu completions languages 2>/dev/null)\""
            end.join("\n")
            <<~FISH
              # kotoshu fish completion — install with:
              #   kotoshu completions fish > ~/.config/fish/completions/kotoshu.fish
              #{command_lines}
              #{language_lines}
            FISH
          end

          def escape(text)
            text.gsub('\\', '\\\\\\\\').gsub('"', '\\"')
          end
          private_class_method :escape
        end
      end
    end

    # Thor subcommand wired as `kotoshu completions <shell>`.
    #
    # Emits shell completion scripts for bash, zsh, and fish, plus a
    # `languages` helper that prints supported language codes one per
    # line. The shell scripts shell out to `kotoshu completions
    # languages` for dynamic language completion, so newly registered
    # languages appear without regenerating the script.
    class CompletionsCommand < Thor
      desc "bash", "Emit a bash completion script for the kotoshu CLI"
      def bash
        $stdout.puts Completions::ScriptBuilders::Bash.build(
          Completions::COMMANDS, Completions::LANGUAGE_ARGUMENT_COMMANDS
        )
      end

      desc "zsh", "Emit a zsh completion script for the kotoshu CLI"
      def zsh
        $stdout.puts Completions::ScriptBuilders::Zsh.build(
          Completions::COMMANDS, Completions::LANGUAGE_ARGUMENT_COMMANDS
        )
      end

      desc "fish", "Emit a fish completion script for the kotoshu CLI"
      def fish
        $stdout.puts Completions::ScriptBuilders::Fish.build(
          Completions::COMMANDS, Completions::LANGUAGE_ARGUMENT_COMMANDS
        )
      end

      desc "languages", "Emit supported language codes, one per line"
      long_desc <<~DESC
        Prints every language code registered with
        `Kotoshu::Language::Registry`, one per line. Used by the bash,
        zsh, and fish completion scripts to populate the language list
        dynamically.
      DESC
      def languages
        Kotoshu::Language::Registry.supported_codes.each { |c| $stdout.puts c }
      end
    end
  end
end
