# frozen_string_literal: true

module Kotoshu
  class Spellchecker
    # Parallel file checker for concurrent spellchecking.
    #
    # Uses a thread pool to check multiple files simultaneously,
    # providing significant speedup on multi-core systems.
    #
    # @example Check files in parallel
    #   checker = ParallelChecker.new(spellchecker: spellchecker, worker_count: 4)
    #   results = checker.check_files_parallel(["file1.txt", "file2.txt"])
    class ParallelChecker
      # Default number of worker threads
      DEFAULT_WORKER_COUNT = 4

      # @return [Spellchecker] The underlying spellchecker
      attr_reader :spellchecker

      # @return [Integer] Number of worker threads
      attr_reader :worker_count

      # Create a new parallel checker.
      #
      # @param spellchecker [Spellchecker] The spellchecker to use
      # @param worker_count [Integer] Number of worker threads (default: 4)
      def initialize(spellchecker:, worker_count: DEFAULT_WORKER_COUNT)
        @spellchecker = spellchecker
        @worker_count = worker_count
        @queue = Queue.new
        @results = []
        @mutex = Mutex.new
      end

      # Check multiple files in parallel.
      #
      # @param file_paths [Array<String>] Paths to files to check
      # @return [Array<Core::Models::Result::DocumentResult>] Results for each file
      def check_files_parallel(file_paths)
        return [] if file_paths.empty?

        # Add all files to the queue
        file_paths.each { |path| @queue << path }

        # Add poison pills to signal workers to stop
        @worker_count.times { @queue << :done }

        # Create and start workers
        workers = @worker_count.times.map { create_worker }

        # Wait for all workers to complete
        workers.each(&:join)

        # Clear queue for reuse
        @queue.clear while @queue.empty? == false

        @results
      end

      # Check a single file (convenience method).
      #
      # @param file_path [String] Path to file
      # @return [Core::Models::Result::DocumentResult] Check result
      def check_file(file_path)
        @spellchecker.check_file(file_path)
      end

      private

      # Create a worker thread.
      #
      # @return [Thread] Worker thread
      def create_worker
        Thread.new do
          while (path = @queue.pop) != :done
            begin
              result = @spellchecker.check_file(path)
              @mutex.synchronize do
                @results << result
              end
            rescue StandardError => e
              # Log error but continue processing other files
              warn "Error checking file #{path}: #{e.message}"
            end
          end
        end
      end
    end
  end
end
