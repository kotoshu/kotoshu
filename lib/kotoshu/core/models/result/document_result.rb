# frozen_string_literal: true

require "lutaml/model"
require_relative "word_result"

module Kotoshu
  module Models
    module Result
      # Result object for checking a document or file.
      #
      # Serialized via lutaml-model. Holds an Array<WordResult> in +errors+.
      class DocumentResult < Lutaml::Model::Serializable
        attribute :file, :string
        attribute :word_count, :integer, default: 0
        attribute :errors, WordResult, collection: true
        attribute :metadata, :hash, default: {}

        def initialize(file: nil, errors: [], word_count: 0, metadata: {})
          super(
            file: file,
            word_count: word_count,
            errors: errors,
            metadata: metadata
          )
        end

        def success?
          errors.empty?
        end

        def failed?
          !success?
        end

        def error_count
          errors.size
        end

        def unique_error_count
          errors.map(&:word).uniq.size
        end

        def has_error_for?(word)
          errors.any? { |e| e.word == word }
        end

        def errors_for(word)
          errors.select { |e| e.word == word }
        end

        def each_error(&)
          return enum_for(:each_error) unless block_given?

          errors.each(&)
        end

        def each_unique_error(&)
          return enum_for(:each_unique_error) unless block_given?

          errors.group_by(&:word).each(&)
        end

        def first_errors(n = 10)
          errors.first(n)
        end

        def error_summary
          summary = Hash.new(0)
          each_error { |error| summary[error.word] += 1 }
          summary
        end

        def ==(other)
          return false unless other.is_a?(DocumentResult)

          file == other.file && errors == other.errors
        end
        alias eql? ==

        def hash
          [file, errors].hash
        end

        def to_s
          if success?
            if file
              "File '#{file}': No spelling errors found (#{word_count} words checked)"
            else
              "No spelling errors found (#{word_count} words checked)"
            end
          else
            prefix = file ? "File '#{file}':" : ""
            "#{prefix} #{error_count} spelling error(s) found " \
              "(#{unique_error_count} unique) in #{word_count} words"
          end
        end
        alias inspect to_s

        def self.success(file: nil, word_count: 0)
          new(file: file, errors: [], word_count: word_count)
        end

        def self.failure(file: nil, errors: [], word_count: 0)
          new(file: file, errors: errors, word_count: word_count)
        end

        def self.merge(results)
          return new if results.empty?

          new(
            file: nil,
            errors: results.flat_map(&:errors),
            word_count: results.sum(&:word_count)
          )
        end
      end
    end
  end
end
