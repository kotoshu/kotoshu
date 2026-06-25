# frozen_string_literal: true

require "json"
require "time"
require "fileutils"

module Kotoshu
  module Integrity
    # Append-only JSON audit log of every resource download.
    #
    # Each entry is one JSON object per line, written to `audit.log`
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
    class AuditLog
      # Default location for the audit log under the Kotoshu home.
      def self.default_path
        ENV.fetch("KOTOSHU_AUDIT_LOG", nil) ||
          File.join(Dir.home, ".kotoshu", "audit.log")
      end

      attr_reader :path

      def initialize(path: self.class.default_path)
        @path = path
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
        File.open(@path, "a", encoding: "UTF-8") do |f|
          f.flock(File::LOCK_EX)
          f.write("#{entry.to_json}\n")
          f.fsync
        end
        entry
      end

      # Iterate every recorded entry (parsed Hashes).
      def each
        return enum_for(:each) unless block_given?
        return unless File.exist?(@path)

        File.foreach(@path, encoding: "UTF-8") do |line|
          line = line.strip
          next if line.empty?

          yield JSON.parse(line)
        end
      end

      def entries
        each.to_a
      end

      def clear!
        FileUtils.rm_f(@path)
      end
    end
  end
end
