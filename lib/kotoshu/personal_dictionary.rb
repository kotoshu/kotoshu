# frozen_string_literal: true

module Kotoshu
  # Personal dictionary for user-specific words.
  #
  # Stores words in ~/.kotoshu/personal.dic in Hunspell format.
  class PersonalDictionary
    PERSONAL_DIR = File.expand_path("~/.kotoshu")
    PERSONAL_FILE = File.join(PERSONAL_DIR, "personal.dic")

    class << self
      # Add a word to personal dictionary.
      #
      # @param word [String] Word to add
      # @return [Boolean] True if added
      def add_word(word)
        return false if word.nil? || word.empty?

        ensure_directory
        words = load_words

        unless words.include?(word.downcase)
          words << word.downcase
          save_words(words)
        end

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

      # Ensure personal directory exists.
      def ensure_directory
        FileUtils.mkdir_p(PERSONAL_DIR) unless Dir.exist?(PERSONAL_DIR)
      end

      # Load words from personal dictionary file.
      #
      # @return [Array<String>] List of words
      def load_words
        return [] unless File.exist?(PERSONAL_FILE)

        File.readlines(PERSONAL_FILE, chomp: true)
            .reject { |line| line.empty? || line.start_with?("#") }
            .map(&:strip)
      end

      # Save words to personal dictionary file.
      #
      # @param words [Array<String>] Words to save
      def save_words(words)
        ensure_directory
        File.open(PERSONAL_FILE, "w") do |f|
          words.sort.uniq.each { |word| f.puts word }
        end
      end
    end
  end
end
