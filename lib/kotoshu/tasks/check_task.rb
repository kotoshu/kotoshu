# frozen_string_literal: true

module Kotoshu
  module Tasks
    # Rake task checking a repository text files with the plan-88
    # file selection (plan 89, item 3).
    #
    # @example Default task via require
    #   # Rakefile
    #   require "kotoshu/tasks"
    #   # provides rake kotoshu:check over the repo text files
    #
    # @example Configured
    #   Kotoshu::Tasks::CheckTask.new do |t|
    #     t.files = FileList["_posts/**/*.md"]
    #     t.language = "en"
    #     t.fail_on_error = true
    #   end
    class CheckTask
      include Rake::DSL

      # @param name [Symbol] task name under the kotoshu namespace
      # @yieldparam task [CheckTask] self for configuration
      def initialize(name = :check, &block)
        @name = name
        @files = nil
        @root = Dir.pwd
        @language = nil
        @fail_on_error = true
        @baseline_path = nil
        yield self if block

        define
      end

      attr_accessor :name, :files, :root, :language, :fail_on_error, :baseline_path

      # The files the task will check: the configured list, or the
      # plan-88 selection over the root.
      #
      # @return [Array<String>]
      def target_files
        return Array(files) if files

        Cli::DirectoryWalker.new.files(root)
      end

      private

      # Register the kotoshu:<name> task.
      def define
        desc "Check spelling in the repository text files"
        namespace :kotoshu do
          task(name) { run }
        end
      end

      # Run the check and abort on errors when fail_on_error.
      def run
        runner = Cli::DirectoryCheck.new(
          target_files,
          check: ->(text) { check_text(text) },
          baseline_path: baseline_path
        )
        runner.run
        report(runner)
        if fail_on_error && runner.failed?
          abort("kotoshu: #{runner.error_count} spelling error(s) in " \
                "#{runner.file_count} file(s)")
        end
      end

      # Check one text through the configured language.
      #
      # @param text [String] file contents
      # @return [Models::Result::DocumentResult]
      def check_text(text)
        language ? Kotoshu.spellchecker_for(language).check(text) : Kotoshu.check(text)
      end

      # Print one line per file with errors plus a summary.
      def report(runner)
        runner.outcomes.each do |outcome|
          next if outcome.result.success?

          outcome.result.each_error do |error|
            suggestions = error.has_suggestions? ? " -> #{error.top_suggestions(3).join(', ')}" : ""
            puts "#{outcome.path}: #{error.word}#{suggestions}"
          end
        end
        puts "#{runner.file_count} file(s) checked, #{runner.error_count} error(s)"
      end
    end
  end
end
