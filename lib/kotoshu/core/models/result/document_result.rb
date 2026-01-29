# frozen_string_literal: true

require_relative "word_result"

module Kotoshu
  module Models
    module Result
      # Result object for checking a document or file.
      #
      # This is a value object that represents the result of checking
      # an entire document for spelling errors.
      #
      # @note This class is immutable and frozen on initialization.
      #
      # @example Creating a successful document result
      #   result = DocumentResult.new(
      #     file: "README.md",
      #     errors: [],
      #     word_count: 150
      #   )
      #   result.success?     # => true
      #   result.error_count  # => 0
      #
      # @example Creating a result with errors
      #   errors = [WordResult.incorrect("helo"), WordResult.incorrect("wrold")]
      #   result = DocumentResult.new(
      #     file: "document.txt",
      #     errors: errors,
      #     word_count: 100
      #   )
      #   result.success?     # => false
      #   result.error_count  # => 2
      class DocumentResult
        # @return [String, nil] The file path (if applicable)
        attr_reader :file

        # @return [Array<WordResult>] List of spelling errors found
        attr_reader :errors

        # @return [Integer] Total word count
        attr_reader :word_count

        # @return [Hash] Additional metadata
        attr_reader :metadata

        # Create a new DocumentResult.
        #
        # @param file [String, nil] The file path (optional)
        # @param errors [Array<WordResult>] List of errors
        # @param word_count [Integer] Total word count
        # @param metadata [Hash] Additional metadata (optional)
        def initialize(file: nil, errors: [], word_count: 0, metadata: {})
          @file = file&.dup&.freeze
          @errors = errors.dup.freeze
          @word_count = word_count
          @metadata = metadata.dup.freeze

          freeze
        end

        # Check if the document check was successful (no errors).
        #
        # @return [Boolean] True if no errors were found
        def success?
          @errors.empty?
        end

        # Check if the document check failed (has errors).
        #
        # @return [Boolean] True if errors were found
        def failed?
          !success?
        end

        # Get the number of errors found.
        #
        # @return [Integer] Error count
        def error_count
          @errors.size
        end

        # Get the number of unique errors (by word).
        #
        # @return [Integer] Unique error count
        def unique_error_count
          @errors.map(&:word).uniq.size
        end

        # Check if a specific word has an error.
        #
        # @param word [String] The word to check
        # @return [Boolean] True if the word has an error
        def has_error_for?(word)
          @errors.any? { |e| e.word == word }
        end

        # Get errors for a specific word.
        #
        # @param word [String] The word
        # @return [Array<WordResult>] Errors for the word
        def errors_for(word)
          @errors.select { |e| e.word == word }
        end

        # Iterate over errors.
        #
        # @yield [error] Each error
        # @return [Enumerator] Enumerator if no block given
        def each_error
          return enum_for(:each_error) unless block_given?
          @errors.each { |error| yield error }
        end

        # Iterate over unique error words.
        #
        # @yield [word, errors] Each unique word and its errors
        # @return [Enumerator] Enumerator if no block given
        def each_unique_error
          return enum_for(:each_unique_error) unless block_given?

          @errors.group_by(&:word).each do |word, errs|
            yield word, errs
          end
        end

        # Get the first N errors.
        #
        # @param n [Integer] Number of errors to return
        # @return [Array<WordResult>] First N errors
        def first_errors(n = 10)
          @errors.first(n)
        end

        # Get error summary as a hash.
        #
        # @return [Hash] Summary of errors
        def error_summary
          summary = Hash.new(0)
          each_error do |error|
            summary[error.word] += 1
          end
          summary
        end

        # Convert to hash.
        #
        # @return [Hash] Hash representation
        def to_h
          {
            file: @file,
            success: success?,
            word_count: @word_count,
            error_count: error_count,
            unique_error_count: unique_error_count,
            errors: @errors.map(&:to_h),
            error_summary: error_summary,
            metadata: @metadata
          }
        end

        # Convert to JSON-compatible hash.
        #
        # @return [Hash] JSON-compatible hash
        def as_json
          {
            "file" => @file,
            "success" => success?,
            "wordCount" => @word_count,
            "errorCount" => error_count,
            "uniqueErrorCount" => unique_error_count,
            "errors" => @errors.map(&:as_json),
            "errorSummary" => error_summary,
            "metadata" => @metadata
          }
        end

        # Check equality based on file and errors.
        #
        # @param other [DocumentResult] The other result
        # @return [Boolean] True if equal
        def ==(other)
          return false unless other.is_a?(DocumentResult)
          @file == other.file && @errors == other.errors
        end
        alias eql? ==

        # Hash based on file and errors.
        #
        # @return [Integer] Hash code
        def hash
          [@file, @errors].hash
        end

        # String representation.
        #
        # @return [String] String representation
        def to_s
          if success?
            if @file
              "File '#{@file}': No spelling errors found (#{@word_count} words checked)"
            else
              "No spelling errors found (#{@word_count} words checked)"
            end
          else
            prefix = @file ? "File '#{@file}':" : ""
            "#{prefix} #{error_count} spelling error(s) found " \
            "(#{unique_error_count} unique) in #{@word_count} words"
          end
        end
        alias inspect to_s

        # Create a successful document result.
        #
        # @param file [String, nil] The file path (optional)
        # @param word_count [Integer] Total word count
        # @return [DocumentResult] New result indicating success
        #
        # @example
        #   DocumentResult.success(file: "README.md", word_count: 150)
        def self.success(file: nil, word_count: 0)
          new(file: file, errors: [], word_count: word_count)
        end

        # Create a failed document result.
        #
        # @param file [String, nil] The file path (optional)
        # @param errors [Array<WordResult>] List of errors
        # @param word_count [Integer] Total word count
        # @return [DocumentResult] New result indicating failure
        #
        # @example
        #   errors = [WordResult.incorrect("helo"), WordResult.incorrect("wrold")]
        #   DocumentResult.failure(file: "doc.txt", errors: errors, word_count: 100)
        def self.failure(file: nil, errors: [], word_count: 0)
          new(file: file, errors: errors, word_count: word_count)
        end

        # Merge multiple document results.
        #
        # @param results [Array<DocumentResult>] Results to merge
        # @return [DocumentResult] Merged result
        #
        # @example Merging results from multiple files
        #   result1 = DocumentResult.new(file: "file1.txt", errors: [e1], word_count: 50)
        #   result2 = DocumentResult.new(file: "file2.txt", errors: [e2, e3], word_count: 75)
        #   DocumentResult.merge([result1, result2])
        #   # => DocumentResult with 3 errors and 125 words
        def self.merge(results)
          return new if results.empty?

          all_errors = results.flat_map(&:errors)
          total_words = results.sum(&:word_count)

          new(
            file: nil,  # Merged results don't have a single file
            errors: all_errors,
            word_count: total_words
          )
        end
      end
    end
  end
end
