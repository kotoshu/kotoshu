# frozen_string_literal: true

module Kotoshu
  # Framework integrations for validation layers (plan 89).
  #
  # Soft dependency: ActiveModel is NOT in kotoshu.gemspec. The
  # validator file soft-requires it exactly like Models::OnnxModel
  # soft-requires onnxruntime (see CLAUDE.md); when it is absent the
  # class still loads but raises a caller-friendly error on use.
  module Validators
    # True when ActiveModel was requireable at load time.
    ACTIVE_MODEL_LOADED = begin
      require "active_model"
      true
    rescue LoadError
      false
    end

    # Raised when the validator is used without ActiveModel.
    class ActiveModelUnavailable < Kotoshu::Error
      def initialize
        super("Kotoshu spelling validation needs ActiveModel. " \
              "Add gem 'activemodel' (or the full Rails stack) to your Gemfile.")
      end
    end

    if ACTIVE_MODEL_LOADED
      # ActiveModel EachValidator that fails validation on
      # misspelled content.
      #
      # One error is added per misspelling, with the top suggestion
      # in the message.
      #
      # @example Wired for the validates short syntax
      #   # Rails initializer or the model file:
      #   SpellingValidator = Kotoshu::Validators::SpellingValidator
      #
      #   class Post < ApplicationRecord
      #     validates :body, spelling: true
      #     validates :summary, spelling: { language: :en,
      #                                     personal_words: %w[kotoshu] }
      #   end
      #
      # @example Without the short syntax
      #   validates_with Kotoshu::Validators::SpellingValidator,
      #                  attributes: [:body]
      #
      # Options:
      # - language: language code; defaults to auto-detection.
      # - personal_words: array of words accepted in addition to the
      #   dictionary.
      class SpellingValidator < ActiveModel::EachValidator
        def validate_each(record, attribute, value)
          return if value.nil? || value.empty?

          result = Kotoshu.check(value, language: language)
          errors = result.errors.reject { |error| personal_words.include?(error.word.downcase) }
          errors.each do |error|
            record.errors.add(attribute, :spelling, **error_attributes(error))
          end
        end

        private

        # The language to check with: the option value, or
        # auto-detection when unset.
        #
        # @return [String, Symbol, nil]
        def language
          options[:language]
        end

        # Words accepted on top of the dictionary, downcased.
        #
        # @return [Array<String>]
        def personal_words
          @personal_words ||= Array(options[:personal_words]).map(&:downcase)
        end

        # Build the error details for one misspelling.
        #
        # @param error [Models::Result::WordResult] the misspelling
        # @return [Hash] message and metadata
        def error_attributes(error)
          suggestion = error.top_suggestions(1).first
          message = "'#{error.word}' is misspelled"
          message += " - did you mean '#{suggestion}'?" if suggestion
          { message: message, word: error.word, suggestions: error.top_suggestions(3) }
        end
      end
    else
      # Placeholder raising a friendly error when ActiveModel is
      # missing; keeps the constant resolvable for tooling.
      class SpellingValidator
        def initialize(*)
          raise ActiveModelUnavailable
        end
      end
    end
  end
end
