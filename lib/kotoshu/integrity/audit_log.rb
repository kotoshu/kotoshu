# frozen_string_literal: true

require "json"
require "time"
require "fileutils"

module Kotoshu
  module Integrity
    # Append-only JSON audit log of every resource download.
    #
    # Each entry is one JSON object per line, written to +audit.log+
    # under the configured Kotoshu home directory. The log is consulted
    # by users when investigating "what did Kotoshu fetch?" and by CI
    # for reproducibility audits.
    #
    # Statuses:
    #   "verified"    — content matched manifest entry's SHA-256
    #   "unverified"  — no manifest entry available; bytes trusted as-is
    #   "mismatch"    — SHA-256 mismatch (also raises IntegrityError)
    #   "missing"     — attempted download failed (network, 404, etc.)
    #
    # The log is opened, appended, and closed per entry — no long-lived
    # file handle. Writes are line-buffered and fsync'd so the record
    # survives a crash mid-batch.
    #
    # == Rotation
    #
    # When the current file exceeds +rotation_policy.max_bytes+, the
    # policy produces a rename plan (see {RotationPolicy#plan_for}) and
    # the log shifts the existing rotations up by one slot before
    # writing the new entry to a fresh current file. The total on-disk
    # footprint is bounded at +max_bytes * (rotations + 1)+.
    #
    # Rotation happens under an exclusive flock on a sibling lockfile
    # (+audit.log.lock+) — not on the log itself — because the log path
    # moves during rotation and the lock would otherwise travel with it.
    class AuditLog
      # Default location: $XDG_DATA_HOME/kotoshu/audit.log
      # (~/.local/share/kotoshu/audit.log), or $KOTOSHU_AUDIT_LOG.
      def self.default_path
        Kotoshu::Paths.audit_log_path
      end

      attr_reader :path, :rotation_policy

      # @param path [String] Override the log file location.
      # @param rotation_policy [RotationPolicy, nil] When nil, no
      #   rotation is performed (the log grows unbounded). Pass a
      #   +RotationPolicy+ instance to enable bounded rotation.
      def initialize(path: self.class.default_path, rotation_policy: nil)
        @path = path
        @rotation_policy = rotation_policy
      end

      # Record one download attempt. Returns the written entry hash.
      #
      # @param url [String] Source URL
      # @param size [Integer, nil] Bytes downloaded (nil on missing)
      # @param sha256 [String, nil] Computed SHA-256 of bytes (nil on missing)
      # @param manifest_sha256 [String, nil] Expected SHA-256 from manifest
      # @param status [String] One of: verified, unverified, mismatch, missing
      # @param resource_id [String, nil] Caller-supplied resource identifier
      def record(url:, status:, size: nil, sha256: nil,
                 manifest_sha256: nil, resource_id: nil)
        entry = {
          timestamp: Time.now.utc.iso8601,
          url: url,
          resource_id: resource_id,
          size: size,
          sha256: sha256,
          manifest_sha256: manifest_sha256,
          status: status
        }
        FileUtils.mkdir_p(File.dirname(@path))
        with_exclusive_lock do
          rotate_if_needed!
          File.open(@path, "a", encoding: "UTF-8") do |f|
            f.write("#{entry.to_json}\n")
            f.fsync
          end
        end
        entry
      end

      # Iterate every recorded entry (parsed Hashes) across the current
      # log and all rotations, newest-first.
      #
      # Newest-first means: within each file, lines are yielded in reverse
      # write order (the last appended entry first); files are visited in
      # order current, .1, .2, ... (newest file first). This guarantees a
      # strictly decreasing write-time ordering across the whole log,
      # which is what an auditor scanning "what did kotoshu fetch most
      # recently?" expects.
      def each(&block)
        return enum_for(:each) unless block

        each_file_reversed(@path, &block)
        return unless rotation_policy&.rotations&.positive?

        1.upto(rotation_policy.rotations) do |n|
          each_file_reversed("#{@path}.#{n}", &block)
        end
      end

      def entries
        each.to_a
      end

      def clear!
        with_exclusive_lock do
          FileUtils.rm_f(@path)
          clear_rotations
        end
      end

      private

      # Yield parsed entries from +path+ newest-first (reverse line order).
      # No-op when the file doesn't exist. Each individual rotation file is
      # bounded by +RotationPolicy.max_bytes+, so loading one file's lines
      # into memory before reversing is acceptable.
      def each_file_reversed(path)
        return unless File.exist?(path)

        File.readlines(path, encoding: "UTF-8")
          .map(&:strip)
          .reject(&:empty?)
          .reverse_each { |line| yield JSON.parse(line) }
      end

      def clear_rotations
        return unless rotation_policy&.rotations&.positive?

        1.upto(rotation_policy.rotations) do |n|
          FileUtils.rm_f("#{@path}.#{n}")
        end
      end

      def rotate_if_needed!
        return unless rotation_policy
        return unless File.exist?(@path)
        return unless rotation_policy.rotate?(File.size(@path))

        plan = rotation_policy.plan_for(@path)
        plan[:deletes].each { |p| FileUtils.rm_f(p) }
        plan[:moves].each do |src, dst|
          FileUtils.mv(src, dst) if File.exist?(src)
        end
      end

      # Exclusive flock on a stable sibling lockfile. The log itself is
      # a poor lock target because rotation renames it out from under
      # any writer mid-flight.
      def with_exclusive_lock
        FileUtils.mkdir_p(File.dirname(@path))
        File.open(lockfile_path, File::RDWR | File::CREAT, 0o644) do |lock|
          lock.flock(File::LOCK_EX)
          yield
        end
      end

      def lockfile_path
        "#{@path}.lock"
      end
    end
  end
end
