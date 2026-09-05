# frozen_string_literal: true

module Kotoshu
  module Cli
    # Runs the check pipeline over a set of files and directories
    # (plan 88): the CLI file mode, one target at a time, sharing one
    # language resolution, baseline, and per-file output.
    #
    # Directories are expanded by DirectoryWalker; explicit file
    # targets are checked as given. A baseline (when provided) is
    # applied per file, exactly as single-file check does.
    class DirectoryCheck
      # Outcome of checking one file: the checked path, the check
      # result, and the baseline application (nil without a
      # baseline).
      FileOutcome = Struct.new(:path, :result, :application, keyword_init: true)

      attr_reader :outcomes

      # @param roots [Array<String>] files and directories to check
      # @param check [#call] callable taking the file text and
      #   returning a Models::Result::DocumentResult (the CLI
      #   file-mode pipeline, including inline suppressions)
      # @param baseline_path [String, nil] --baseline file
      # @param include_globs [Array<String>] --include globs
      # @param exclude_globs [Array<String>] --exclude globs
      def initialize(roots, check:, baseline_path: nil, include_globs: [], exclude_globs: [])
        @roots = Array(roots)
        @check = check
        @baseline_path = baseline_path
        @walker = DirectoryWalker.new(include_globs: include_globs, exclude_globs: exclude_globs)
        @outcomes = []
      end

      # Check every selected file.
      #
      # @return [Array<FileOutcome>] one outcome per checked file, in
      #   walk order
      def run
        @outcomes = target_files.map { |path| check_file(path) }
        @outcomes
      end

      # The number of files checked.
      #
      # @return [Integer]
      def file_count
        @outcomes.size
      end

      # Total errors across all files, after baseline application.
      #
      # @return [Integer]
      def error_count
        @outcomes.sum { |outcome| outcome.result.error_count }
      end

      # Total words across all files.
      #
      # @return [Integer]
      def word_count
        @outcomes.sum { |outcome| outcome.result.word_count }
      end

      # Whether any file failed.
      #
      # @return [Boolean]
      def failed?
        @outcomes.any? { |outcome| outcome.result.failed? }
      end

      # Baseline-suppressed error count across all files.
      #
      # @return [Integer]
      def suppressed_count
        applications.sum(&:suppressed_count)
      end

      # Stale baseline entry count across all files.
      #
      # @return [Integer]
      def stale_count
        applications.sum(&:stale_count)
      end

      private

      # The applications of the baseline across outcomes.
      #
      # @return [Array[Baseline::Store::Application>]
      def applications
        @outcomes.filter_map(&:application)
      end

      # Expand roots into a deduplicated file list: explicit files
      # first (in argument order), then walked directory files.
      #
      # @return [Array<String>] file paths
      def target_files
        files = @roots.select { |root| File.file?(root) }
        @roots.select { |root| File.directory?(root) }.each do |dir|
          files.concat(@walker.files(dir))
        end
        files.each_with_object([]) do |path, unique|
          unique << path unless unique.include?(path)
        end
      end

      # Check one file and apply the baseline to its result.
      #
      # @param path [String] file path
      # @return [FileOutcome]
      def check_file(path)
        text = File.read(path, encoding: Kotoshu.configuration.encoding)
        result = @check.call(text)
        application = apply_baseline(result, path)
        result = application.result if application
        FileOutcome.new(path: path, result: result, application: application)
      end

      # Apply the baseline to one file result, mirroring the CLI
      # file-mode semantics.
      #
      # @param result [Models::Result::DocumentResult] check result
      # @param path [String] file path
      # @return [Baseline::Store::Application, nil]
      def apply_baseline(result, path)
        return nil unless @baseline_path

        baseline_store.apply(result, file: path)
      end

      # Load the baseline store once.
      #
      # @return [Baseline::Store]
      def baseline_store
        @baseline_store ||= Baseline::Store.load(@baseline_path)
      end
    end
  end
end
