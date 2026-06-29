# frozen_string_literal: true

require "fileutils"

module Kotoshu
  # Personal dictionary for user-specific words.
  #
  # Stored in ~/.config/kotoshu/personal.dic (Hunspell format) under the
  # XDG config directory. Override via KOTOSHU_PERSONAL_DIC.
  #
  # The on-disk path is resolved lazily on every call so env-var
  # overrides take effect at runtime — handy for tests and for users
  # who set KOTOSHU_PERSONAL_DIC after the gem loads.
  class PersonalDictionary
    class << self
      # Resolve the personal-dictionary file path from Paths (which
      # honors KOTOSHU_PERSONAL_DIC). Read fresh each call so an
      # env override applied after gem load still takes effect.
      #
      # @return [String]
      def file_path
        Kotoshu::Paths.personal_dictionary_path
      end

      # Add a word to personal dictionary.
      #
      # @param word [String] Word to add
      # @return [Boolean] True if the word was newly added (i.e. it
      #   wasn't already in the dictionary); false otherwise.
      def add_word(word)
        return false if word.nil? || word.empty?

        ensure_directory
        words = load_words

        return false if words.include?(word.downcase)

        words << word.downcase
        save_words(words)
        true
      end

      # Get all personal words.
      #
      # @return [Array<String>] All personal words
      def words
        load_words
      end

      # Remove a word from personal dictionary.
      #
      # @param word [String] Word to remove
      # @return [Boolean] True if removed
      def remove_word(word)
        return false if word.nil? || word.empty?

        words = load_words
        if words.delete(word.downcase)
          save_words(words)
          true
        else
          false
        end
      end

      # Check if word is in personal dictionary.
      #
      # @param word [String] Word to check
      # @return [Boolean] True if present
      def include?(word)
        return false if word.nil? || word.empty?

        load_words.include?(word.downcase)
      end

      private

      # Ensure personal dictionary's parent directory exists.
      def ensure_directory
        FileUtils.mkdir_p(File.dirname(file_path))
      end

      # Load words from personal dictionary file.
      #
      # @return [Array<String>] List of words
      def load_words
        return [] unless File.exist?(file_path)

        File.readlines(file_path, chomp: true)
          .reject { |line| line.empty? || line.start_with?("#") }
          .map(&:strip)
      end

      # Save words to personal dictionary file.
      #
      # @param words [Array<String>] Words to save
      def save_words(words)
        ensure_directory
        File.open(file_path, "w") do |f|
          words.sort.uniq.each { |word| f.puts word }
        end
      end
    end
  end
end
