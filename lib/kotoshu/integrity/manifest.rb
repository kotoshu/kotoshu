# frozen_string_literal: true

require "json"
require "digest"
require_relative "../core/exceptions"

module Kotoshu
  module Integrity
    # Parsed view of a content repo's `manifest.json`.
    #
    # Format (per TODO.impl/09-integrity-security.md task 1):
    #
    #   {
    #     "version": 1,
    #     "generated_at": "2026-06-25T10:00:00Z",
    #     "resources": {
    #       "en/spelling/index.dic": {
    #         "size": 49568,
    #         "sha256": "ab12...",
    #         "language": "en",
    #         "type": "spelling",
    #         "license": "LGPL/MPL/GPL",
    #         "source": "SCROLL"
    #       }
    #     }
    #   }
    #
    # Construction:
    #
    #   manifest = Manifest.parse(json_string)
    #   manifest.fetch("en/spelling/index.dic")  # => Entry or nil
    #   manifest.verify_content!("en/spelling/index.dic", bytes) # raises on mismatch
    #
    # `Manifest.load(url, http:)`, returns nil when the manifest 404s (graceful
    # degradation — see module docs).
    class Manifest
      Entry = Struct.new(:path, :sha256, :size, :language, :type, :license, :source,
                         keyword_init: true) do
        def verify?(content)
          Digest::SHA256.hexdigest(content) == sha256
        end
      end

      # Parse a manifest JSON string. Returns an empty Manifest if the JSON
      # is parseable but has no resources (caller treats as "no constraints").
      def self.parse(json)
        data = JSON.parse(json)
        entries = {}
        (data["resources"] || {}).each do |path, fields|
          entries[path] = Entry.new(
            path: path,
            sha256: fields["sha256"],
            size: fields["size"],
            language: fields["language"],
            type: fields["type"],
            license: fields["license"],
            source: fields["source"]
          )
        end
        new(entries, version: data["version"], generated_at: data["generated_at"])
      rescue JSON::ParserError => e
        raise Kotoshu::IntegrityError.new(
          "manifest",
          expected: "<valid JSON>",
          actual: "<parse error: #{e.message}>"
        )
      end

      # Fetch and parse a manifest from a URL. Returns nil when the
      # manifest is absent (HTTP 404/410) so callers can fall back to
      # unverified downloads — see module docs. Any other failure
      # (5xx, network error, parse error) raises.
      def self.load(url, http: Kotoshu::Integrity::NetHTTP)
        body = http.get(url)
        return nil if body.nil?

        parse(body)
      end

      attr_reader :entries, :version, :generated_at

      def initialize(entries, version: nil, generated_at: nil)
        @entries = entries
        @version = version
        @generated_at = generated_at
      end

      def fetch(path)
        @entries[path]
      end

      def empty?
        @entries.empty?
      end

      # Verify that content for `path` matches the manifest entry.
      # Raises {Kotoshu::IntegrityError} on mismatch. No-op when the
      # manifest has no entry for `path` (returns nil — caller decides
      # whether to treat absence as failure in strict mode).
      def verify_content!(path, content, url: nil)
        entry = @entries[path]
        return nil unless entry

        actual = Digest::SHA256.hexdigest(content)
        unless actual == entry.sha256
          raise Kotoshu::IntegrityError.new(
            path,
            expected: entry.sha256,
            actual: actual,
            url: url
          )
        end
        true
      end
    end
  end
end
