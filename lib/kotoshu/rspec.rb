# frozen_string_literal: true

require "rspec/matchers"

module Kotoshu
  # RSpec integration (plan 89): word and document matchers with
  # real failure messages.
  #
  # RSpec is a soft dependency of the gem itself; this file requires
  # rspec/matchers (present in any suite that would use it).
  #
  # @example Wiring
  #   # spec_helper.rb
  #   require "kotoshu/rspec"
  #   RSpec.configure do |config|
  #     config.include Kotoshu::Rspec::Matchers
  #   end
  #
  # @example Word matcher
  #   expect_words("helo", "world").to all_be_spelled_correctly
  #   expect("helo").not_to be_spelled_correctly
  #
  # @example Document matcher
  #   expect_document("README.adoc").to be_spelled_correctly
  #   expect("helo wrold").not_to be_spelled_correctly(in: "en")
  module Rspec
    # Matchers exposed to specs via config.include.
    module Matchers
      # Expectation target over discrete words: returns the real
      # RSpec target so `.to all_be_spelled_correctly` works. Requires
      # RSpec::Matchers to be in scope (it is, in any suite including
      # this module).
      #
      # @param words [Array<String>] words to check
      # @return [RSpec::Expectations::ExpectationTarget]
      def expect_words(*words)
        expect(words.flatten)
      end

      # Expectation target over a documents contents.
      #
      # @param path [String] document path
      # @return [RSpec::Expectations::ExpectationTarget]
      def expect_document(path)
        expect(File.read(path))
      end

      # Matcher: every item of the target is a correctly spelled
      # word. Pairs with expect_words.
      def all_be_spelled_correctly
        AllWordsSpelledCorrectlyMatcher.new
      end

      # Matcher: a single word is correct, or a whole text is free of
      # misspellings (any whitespace makes it a document).
      def be_spelled_correctly(in: nil)
        SpelledCorrectlyMatcher.new(language: binding.local_variable_get(:in))
      end

      # Checks each word of an enumerable.
      class AllWordsSpelledCorrectlyMatcher
        def matches?(words)
          @words = Array(words)
          @misspelled = @words.reject { |word| Kotoshu.correct?(word) }
          @misspelled.empty?
        end

        def failure_message
          "expected all words to be spelled correctly, but found " \
          "#{formatted_misspellings}"
        end

        def failure_message_when_negated
          "expected some words to be misspelled, but all were correct"
        end

        def description
          "all be spelled correctly"
        end

        private

        # One "word -> suggestion" pair per misspelling.
        #
        # @return [String]
        def formatted_misspellings
          @misspelled.map do |word|
            suggestions = Kotoshu.suggest(word).top(3).map(&:word)
            detail = suggestions.empty? ? "no suggestions" : suggestions.join(", ")
            "#{word.inspect} (#{detail})"
          end.join(", ")
        end
      end

      # Checks one word, or a whole document when the string contains
      # whitespace.
      class SpelledCorrectlyMatcher
        def initialize(language: nil)
          @language = language
        end

        def matches?(target)
          @target = target.to_s
          @errors = document? ? document_errors : word_errors
          @errors.empty?
        end

        def failure_message
          if document?
            "expected the document to be spelled correctly, but found " \
            "#{formatted_errors}"
          else
            "expected #{@target.inspect} to be spelled correctly"
          end
        end

        def failure_message_when_negated
          if document?
            "expected the document to have misspellings, but it is clean"
          else
            "expected #{@target.inspect} to be misspelled"
          end
        end

        def description
          "be spelled correctly"
        end

        private

        # Whether the target is a document rather than one word.
        def document?
          @target.match?(/\s/)
        end

        # Document misspellings via the check pipeline.
        def document_errors
          Kotoshu.check(@target, language: @language).errors
        end

        # Single-word misspelling via correct?.
        def word_errors
          Kotoshu.correct?(@target, language: @language) ? [] : [@target]
        end

        # One "word -> suggestions" pair per misspelling.
        #
        # @return [String]
        def formatted_errors
          @errors.map do |error|
            if error.is_a?(String)
              "#{error.inspect} (no suggestions)"
            else
              suggestions = error.top_suggestions(3)
              detail = suggestions.empty? ? "no suggestions" : suggestions.join(", ")
              "#{error.word.inspect} (#{detail})"
            end
          end.join(", ")
        end
      end
    end
  end
end
