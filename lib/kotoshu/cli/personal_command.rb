# frozen_string_literal: true

require "thor"

module Kotoshu
  module Cli
    # Thor subcommand for managing the user's personal dictionary.
    #
    # The personal dictionary is a Hunspell-style .dic file at
    # +~/.config/kotoshu/personal.dic+ (override via KOTOSHU_PERSONAL_DIC).
    # Words added here are treated as correct during spell-checking.
    #
    # @example Add a word
    #   kotoshu personal add Kotoshu
    #
    # @example List personal words
    #   kotoshu personal list
    #
    # @example Remove a word
    #   kotoshu personal remove Kotoshu
    #
    # @example Import words from a file (one word per line)
    #   kotoshu personal import project-terms.txt
    #
    # @example Show the on-disk location
    #   kotoshu personal path
    class PersonalCommand < Thor
      desc "add WORD [WORD ...]", "Add one or more words to the personal dictionary"
      def add(*words)
        raise Kotoshu::Cli::Errors::UsageError, "No words given" if words.empty?

        added = words.count { |word| Kotoshu::PersonalDictionary.add_word(word) }
        puts "Added #{added} #{plural(added, 'word')} to #{Kotoshu::PersonalDictionary.file_path}"
      end

      desc "remove WORD [WORD ...]", "Remove one or more words from the personal dictionary"
      def remove(*words)
        raise Kotoshu::Cli::Errors::UsageError, "No words given" if words.empty?

        removed = words.count { |word| Kotoshu::PersonalDictionary.remove_word(word) }
        puts "Removed #{removed} #{plural(removed, 'word')}"
      end

      desc "list", "List every word in the personal dictionary"
      def list
        words = Kotoshu::PersonalDictionary.words
        if words.empty?
          puts "(empty)"
          return
        end

        words.each { |word| puts word }
      end

      desc "import FILE [FILE ...]", "Import words from one or more text files (one word per line)"
      method_option :dry_run, type: :boolean, default: false,
                              desc: "Print what would be added without writing"
      def import(*files)
        raise Kotoshu::Cli::Errors::UsageError, "No files given" if files.empty?

        candidates = []
        files.each do |path|
          raise Kotoshu::Cli::Errors::UsageError, "File not found: #{path}" unless File.exist?(path)

          File.foreach(path, chomp: true) do |line|
            word = line.strip
            next if word.empty? || word.start_with?("#")

            candidates << word
          end
        end

        if options[:dry_run]
          puts "Would import #{candidates.length} #{plural(candidates.length, 'word')}:"
          candidates.each { |w| puts "  #{w}" }
          return
        end

        added = candidates.count { |word| Kotoshu::PersonalDictionary.add_word(word) }
        puts "Imported #{added} #{plural(added, 'word')} from #{files.length} #{plural(files.length, 'file')}"
      end

      desc "path", "Print the on-disk location of the personal dictionary"
      def path
        puts Kotoshu::PersonalDictionary.file_path
      end

      desc "clear", "Remove every word from the personal dictionary"
      method_option :yes, type: :boolean, default: false,
                          desc: "Skip the confirmation prompt"
      def clear
        unless options[:yes]
          print "Clear the entire personal dictionary? [y/N] "
          answer = $stdin.gets&.chomp&.downcase
          return unless ["y", "yes"].include?(answer)
        end

        file = Kotoshu::PersonalDictionary.file_path
        return unless File.exist?(file)

        File.write(file, "")
        puts "Cleared #{file}"
      end

      private

      # English plural helper: "1 word", "2 words".
      def plural(count, singular)
        count == 1 ? singular : "#{singular}s"
      end
    end
  end
end
