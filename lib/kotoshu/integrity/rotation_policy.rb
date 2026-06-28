# frozen_string_literal: true

module Kotoshu
  module Integrity
    # Pure value object that decides when an {AuditLog} should rotate
    # and produces the rename plan that realises the rotation.
    #
    # The policy is intentionally IO-free so it can be unit-tested in
    # isolation. {AuditLog#record} consults the policy on every write
    # and executes the returned plan via +FileUtils+.
    #
    # Rotation scheme: keep +rotations+ historical files alongside the
    # current one. On rotation:
    #
    #   1. Drop the oldest rotation slot (<path>.<rotations>).
    #   2. Shift each remaining rotation up by one suffix.
    #   3. Promote the current log to <path>.1.
    #
    # Net effect: current + N rotated files, total bounded at
    # +max_bytes * (rotations + 1)+.
    class RotationPolicy
      DEFAULT_MAX_BYTES = 10 * 1024 * 1024 # 10 MB
      DEFAULT_ROTATIONS = 5

      attr_reader :max_bytes, :rotations

      def initialize(max_bytes: DEFAULT_MAX_BYTES, rotations: DEFAULT_ROTATIONS)
        @max_bytes = max_bytes.to_i
        @rotations = rotations.to_i
        raise ArgumentError, "max_bytes must be >= 0" if @max_bytes.negative?
        raise ArgumentError, "rotations must be >= 0" if @rotations.negative?
      end

      # True when the current file size exceeds the configured ceiling.
      #
      # @param current_size [Integer] Bytes of the current log file.
      def rotate?(current_size)
        current_size > max_bytes
      end

      # Plan the file operations required to rotate +path+.
      #
      # Returns a hash with two keys:
      #
      #   +:deletes+ — Array<String> of paths to remove (+FileUtils.rm_f+).
      #   +:moves+   — Array<[String, String]> of (source, dest) pairs
      #                (+FileUtils.mv+).
      #
      # The plan is ordered so that a caller executing the deletes first
      # and then the moves in array order will not clobber any still-live
      # rotation. Sources that happen not to exist are silently skipped
      # by +FileUtils.mv+, so the plan can be applied verbatim.
      #
      # When +rotations+ is zero, the plan deletes the current path; the
      # caller's next append recreates it as an empty file (effectively a
      # truncate).
      #
      # @param path [String] The current log path (e.g. "/x/audit.log").
      def plan_for(path)
        if rotations.positive?
          {
            deletes: [rotated_path(path, rotations)],
            moves: shift_moves(path).push([path, rotated_path(path, 1)])
          }
        else
          { deletes: [path], moves: [] }
        end
      end

      private

      # Pairs that shift every existing rotation up by one suffix.
      # Ordered oldest-first so the rename chain doesn't overwrite
      # in-flight files. For +rotations = 5+ this yields:
      #
      #   [[p.4, p.5], [p.3, p.4], [p.2, p.3], [p.1, p.2]]
      def shift_moves(path)
        (rotations - 1).downto(1).map do |n|
          [rotated_path(path, n), rotated_path(path, n + 1)]
        end
      end

      def rotated_path(path, suffix)
        "#{path}.#{suffix}"
      end
    end
  end
end
