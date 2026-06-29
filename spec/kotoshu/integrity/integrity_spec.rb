# frozen_string_literal: true

require "kotoshu"
require "tmpdir"
require "fileutils"
require "json"

# Trigger autoload of the integrity namespace.
Kotoshu::Integrity::AuditLog

# Direct spec for the integrity/ namespace: RotationPolicy, Manifest, AuditLog.
#
# These had no direct spec — only exercised indirectly via cache specs that
# hit the live network. This file pins each class's public contract with
# pure-Ruby fixtures (in-memory JSON for Manifest, tmpdir for AuditLog).
RSpec.describe Kotoshu::Integrity do
  # ---- RotationPolicy ----------------------------------------------------

  describe Kotoshu::Integrity::RotationPolicy do
    describe "#initialize" do
      it "defaults max_bytes to 10 MB and rotations to 5" do
        p = described_class.new
        expect(p.max_bytes).to eq(10 * 1024 * 1024)
        expect(p.rotations).to eq(5)
      end

      it "accepts custom max_bytes and rotations" do
        p = described_class.new(max_bytes: 1000, rotations: 3)
        expect(p.max_bytes).to eq(1000)
        expect(p.rotations).to eq(3)
      end

      it "coerces string inputs to integers" do
        p = described_class.new(max_bytes: "1000", rotations: "2")
        expect(p.max_bytes).to eq(1000)
        expect(p.rotations).to eq(2)
      end

      it "raises ArgumentError for negative max_bytes" do
        expect { described_class.new(max_bytes: -1) }
          .to raise_error(ArgumentError, /max_bytes must be >= 0/)
      end

      it "raises ArgumentError for negative rotations" do
        expect { described_class.new(rotations: -1) }
          .to raise_error(ArgumentError, /rotations must be >= 0/)
      end

      it "accepts zero for both (effectively truncate-on-rotate / never-rotate)" do
        p = described_class.new(max_bytes: 0, rotations: 0)
        expect(p.max_bytes).to eq(0)
        expect(p.rotations).to eq(0)
      end
    end

    describe "#rotate?" do
      it "is false when current_size <= max_bytes" do
        p = described_class.new(max_bytes: 1000)
        expect(p.rotate?(0)).to be false
        expect(p.rotate?(999)).to be false
        expect(p.rotate?(1000)).to be false
      end

      it "is true when current_size > max_bytes" do
        p = described_class.new(max_bytes: 1000)
        expect(p.rotate?(1001)).to be true
      end
    end

    describe "#plan_for" do
      let(:policy) { described_class.new(max_bytes: 1000, rotations: 3) }
      let(:path) { "/var/log/audit.log" }

      it "deletes the oldest rotation slot" do
        plan = policy.plan_for(path)
        expect(plan[:deletes]).to eq(["/var/log/audit.log.3"])
      end

      it "shifts each existing rotation up by one suffix, oldest-first" do
        plan = policy.plan_for(path)
        expect(plan[:moves]).to eq([
                                     ["/var/log/audit.log.2", "/var/log/audit.log.3"],
                                     ["/var/log/audit.log.1", "/var/log/audit.log.2"],
                                     ["/var/log/audit.log",   "/var/log/audit.log.1"]
                                   ])
      end

      it "deletes the current path (truncate) when rotations is zero" do
        p = described_class.new(max_bytes: 1000, rotations: 0)
        plan = p.plan_for(path)
        expect(plan[:deletes]).to eq([path])
        expect(plan[:moves]).to eq([])
      end

      it "with rotations=1 deletes .1 and moves current to .1" do
        p = described_class.new(max_bytes: 1000, rotations: 1)
        plan = p.plan_for(path)
        expect(plan[:deletes]).to eq(["/var/log/audit.log.1"])
        expect(plan[:moves]).to eq([
                                     ["/var/log/audit.log", "/var/log/audit.log.1"]
                                   ])
      end

      it "is purely functional — does not touch the filesystem" do
        # plan_for doesn't perform IO; safe to call against non-existent paths.
        expect { policy.plan_for("/nonexistent/path/file.log") }.not_to raise_error
      end

      it "preserves move ordering so a verbatim executor never clobbers a live file" do
        # The plan executes deletes first, then moves in array order. With
        # rotations=N, by the time (log, log.1) executes, log.N has been
        # deleted and log.(N-1) has been moved to log.N — so no overwrite.
        2.upto(5) do |n|
          plan = described_class.new(rotations: n).plan_for(path)
          # After each move, the destination must not be a source for any
          # later move (else the chain would clobber). Check that each
          # destination is unique within the moves array.
          destinations = plan[:moves].map(&:last)
          expect(destinations).to eq(destinations.uniq),
                                  "destinations not unique for rotations=#{n}: #{destinations}"
        end
      end
    end
  end

  # ---- Manifest ----------------------------------------------------------

  describe Kotoshu::Integrity::Manifest do
    let(:sample_json) do
      <<~JSON
        {
          "version": 1,
          "generated_at": "2026-06-25T10:00:00Z",
          "resources": {
            "en/spelling/index.dic": {
              "size": 49568,
              "sha256": "#{Digest::SHA256.hexdigest("hello")}",
              "language": "en",
              "type": "spelling",
              "license": "LGPL/MPL/GPL",
              "source": "SCROLL"
            },
            "en/spelling/index.aff": {
              "size": 1024,
              "sha256": "#{Digest::SHA256.hexdigest("world")}",
              "language": "en",
              "type": "spelling",
              "license": "LGPL/MPL/GPL",
              "source": "SCROLL"
            }
          }
        }
      JSON
    end

    describe ".parse" do
      it "builds a Manifest from a JSON string" do
        m = described_class.parse(sample_json)
        expect(m).to be_a(described_class)
        expect(m.version).to eq(1)
        expect(m.generated_at).to eq("2026-06-25T10:00:00Z")
      end

      it "parses each resource into an Entry" do
        m = described_class.parse(sample_json)
        entry = m.fetch("en/spelling/index.dic")
        expect(entry).to be_a(Kotoshu::Integrity::Manifest::Entry)
        expect(entry.path).to eq("en/spelling/index.dic")
        expect(entry.size).to eq(49568)
        expect(entry.sha256).to eq(Digest::SHA256.hexdigest("hello"))
        expect(entry.language).to eq("en")
        expect(entry.type).to eq("spelling")
        expect(entry.license).to eq("LGPL/MPL/GPL")
        expect(entry.source).to eq("SCROLL")
      end

      it "parses manifests with no resources section as empty" do
        m = described_class.parse('{"version": 1}')
        expect(m).to be_empty
      end

      it "raises IntegrityError on malformed JSON" do
        expect { described_class.parse("not json {") }
          .to raise_error(Kotoshu::IntegrityError, /manifest/)
      end
    end

    describe "#fetch" do
      it "returns the Entry for a known path" do
        m = described_class.parse(sample_json)
        expect(m.fetch("en/spelling/index.dic").size).to eq(49568)
      end

      it "returns nil for an unknown path" do
        m = described_class.parse(sample_json)
        expect(m.fetch("en/unknown.txt")).to be_nil
      end
    end

    describe "#empty?" do
      it "is true when no resources were parsed" do
        expect(described_class.parse('{"resources": {}}')).to be_empty
      end

      it "is false when resources are present" do
        expect(described_class.parse(sample_json)).not_to be_empty
      end
    end

    describe "#verify_content!" do
      let(:manifest) { described_class.parse(sample_json) }

      it "returns true when the SHA-256 matches" do
        expect(manifest.verify_content!("en/spelling/index.dic", "hello")).to be true
      end

      it "raises IntegrityError when the SHA-256 mismatches" do
        expect { manifest.verify_content!("en/spelling/index.dic", "wrong") }
          .to raise_error(Kotoshu::IntegrityError, /Integrity verification failed/)
      end

      it "includes the URL in the error when provided" do
        expect do
          manifest.verify_content!("en/spelling/index.dic", "wrong",
                                   url: "https://example.com/x")
        end.to raise_error(Kotoshu::IntegrityError, /url: https:\/\/example\.com\/x/)
      end

      it "returns nil (no-op) when the manifest has no entry for the path" do
        expect(manifest.verify_content!("en/unknown.txt", "anything")).to be_nil
      end
    end

    describe "Entry#verify?" do
      let(:entry) { described_class.parse(sample_json).fetch("en/spelling/index.dic") }

      it "is true when the content hashes to the recorded sha256" do
        expect(entry.verify?("hello")).to be true
      end

      it "is false otherwise" do
        expect(entry.verify?("wrong")).to be false
      end
    end

    describe ".load" do
      it "delegates to the http layer and parses the body" do
        # Use a real http stub object — no `double` per project rules.
        http_stub = Class.new do
          def initialize(body)
            @body = body
          end

          def get(_url)
            @body
          end
        end.new(sample_json)

        manifest = described_class.load("https://example.com/manifest.json",
                                        http: http_stub)
        expect(manifest.fetch("en/spelling/index.dic").size).to eq(49568)
      end

      it "returns nil when the http layer returns nil (404 / 410)" do
        http_stub = Class.new do
          def get(_url)
            nil
          end
        end.new

        expect(described_class.load("https://example.com/manifest.json",
                                    http: http_stub)).to be_nil
      end

      it "propagates JSON parse errors" do
        http_stub = Class.new do
          def get(_url)
            "not json"
          end
        end.new

        expect do
          described_class.load("https://example.com/manifest.json", http: http_stub)
        end.to raise_error(Kotoshu::IntegrityError)
      end
    end
  end

  # ---- AuditLog ----------------------------------------------------------

  describe Kotoshu::Integrity::AuditLog do
    let(:tmpdir) { Dir.mktmpdir("kotoshu-audit-spec") }
    let(:log_path) { File.join(tmpdir, "audit.log") }

    after do
      FileUtils.rm_rf(tmpdir) if File.exist?(tmpdir)
    end

    describe ".default_path" do
      it "returns the Paths.audit_log_path" do
        expect(described_class.default_path).to eq(Kotoshu::Paths.audit_log_path)
      end
    end

    describe "#record" do
      it "writes one JSON object per line" do
        log = described_class.new(path: log_path)
        log.record(url: "https://example.com/x", status: "verified",
                   size: 10, sha256: "abc", manifest_sha256: "abc",
                   resource_id: "en:spelling")
        lines = File.readlines(log_path)
        expect(lines.length).to eq(1)
        parsed = JSON.parse(lines.first)
        expect(parsed["url"]).to eq("https://example.com/x")
        expect(parsed["status"]).to eq("verified")
        expect(parsed["size"]).to eq(10)
        expect(parsed["sha256"]).to eq("abc")
        expect(parsed["manifest_sha256"]).to eq("abc")
        expect(parsed["resource_id"]).to eq("en:spelling")
        expect(parsed["timestamp"]).to match(/\A\d{4}-\d{2}-\d{2}T/)
      end

      it "returns the written entry hash" do
        log = described_class.new(path: log_path)
        entry = log.record(url: "https://x", status: "unverified")
        expect(entry).to be_a(Hash)
        expect(entry[:url]).to eq("https://x")
        expect(entry[:status]).to eq("unverified")
      end

      it "creates the parent directory when missing" do
        nested = File.join(tmpdir, "nested/deep/audit.log")
        log = described_class.new(path: nested)
        log.record(url: "https://x", status: "verified")
        expect(File.exist?(nested)).to be true
      end

      it "appends multiple entries" do
        log = described_class.new(path: log_path)
        log.record(url: "https://x/1", status: "verified")
        log.record(url: "https://x/2", status: "unverified")
        log.record(url: "https://x/3", status: "missing")
        lines = File.readlines(log_path)
        expect(lines.length).to eq(3)
        expect(lines.map { |l| JSON.parse(l)["status"] }).to eq(
          %w[verified unverified missing]
        )
      end
    end

    describe "#each" do
      it "iterates entries newest-first across current + rotations" do
        # Bounded rotation: 200 bytes per file, 2 rotations => 3 live files.
        # Each entry is ~80 bytes, so each file holds ~2-3 entries before
        # rotating. Writing 20 entries therefore drops the oldest ~14; the
        # remaining ~6 should still be observable, newest-first.
        policy = Kotoshu::Integrity::RotationPolicy.new(max_bytes: 200, rotations: 2)
        log = described_class.new(path: log_path, rotation_policy: policy)
        20.times { |i| log.record(url: "https://x/#{i}", status: "verified") }

        urls = log.each.map { |e| e["url"] }

        # Surviving entries (latest 6 of the 20) ordered newest-first.
        expect(urls.first).to eq("https://x/19")
        expect(urls.last).to eq("https://x/14")
        expect(urls).to eq(urls.sort.reverse) # monotonic descending
        # Rotation bound: not all 20 survive.
        expect(urls.length).to be < 20
      end

      it "preserves every entry when capacity exceeds the total payload" do
        # Big enough that no rotation ever triggers.
        policy = Kotoshu::Integrity::RotationPolicy.new(max_bytes: 100_000, rotations: 5)
        log = described_class.new(path: log_path, rotation_policy: policy)
        20.times { |i| log.record(url: "https://x/#{i}", status: "verified") }

        urls = log.each.map { |e| e["url"] }
        expect(urls.length).to eq(20)
        expect(urls.first).to eq("https://x/19")
        expect(urls.last).to eq("https://x/0")
      end

      it "returns an Enumerator when no block is given" do
        log = described_class.new(path: log_path)
        log.record(url: "https://x", status: "verified")
        expect(log.each).to be_an(Enumerator)
        expect(log.each.to_a.length).to eq(1)
      end
    end

    describe "#entries" do
      it "returns the array form of #each" do
        log = described_class.new(path: log_path)
        log.record(url: "https://x", status: "verified")
        entries = log.entries
        expect(entries).to be_an(Array)
        expect(entries.length).to eq(1)
      end

      it "is empty when no entries have been recorded" do
        log = described_class.new(path: log_path)
        expect(log.entries).to eq([])
      end
    end

    describe "#clear!" do
      it "removes the current log and all rotations" do
        policy = Kotoshu::Integrity::RotationPolicy.new(max_bytes: 100, rotations: 3)
        log = described_class.new(path: log_path, rotation_policy: policy)
        20.times { |i| log.record(url: "https://x/#{i}", status: "verified") }

        log.clear!

        expect(File.exist?(log_path)).to be false
        1.upto(3) { |n| expect(File.exist?("#{log_path}.#{n}")).to be false }
        expect(log.entries).to eq([])
      end

      it "is safe to call on an empty log" do
        log = described_class.new(path: log_path)
        expect { log.clear! }.not_to raise_error
      end
    end

    describe "rotation integration" do
      it "renames the current file to .1 when the policy says rotate" do
        policy = Kotoshu::Integrity::RotationPolicy.new(max_bytes: 100, rotations: 2)
        log = described_class.new(path: log_path, rotation_policy: policy)

        # First entry: tiny, no rotation.
        log.record(url: "u1", status: "verified")
        expect(File.exist?("#{log_path}.1")).to be false

        # Write enough to exceed 100 bytes; rotation triggers before next write.
        15.times { |i| log.record(url: "u-#{i}-padding-the-log", status: "verified") }

        # After rotation: current + .1 both exist (.2 may or may not yet).
        expect(File.exist?(log_path)).to be true
        expect(File.exist?("#{log_path}.1")).to be true
      end

      it "never grows beyond the configured bound across many writes" do
        # max_bytes=100, rotations=2 → upper bound ≈ 100 * 3 = 300 bytes.
        policy = Kotoshu::Integrity::RotationPolicy.new(max_bytes: 100, rotations: 2)
        log = described_class.new(path: log_path, rotation_policy: policy)

        200.times { |i| log.record(url: "u-#{i}", status: "verified") }

        sizes = [log_path, "#{log_path}.1", "#{log_path}.2"]
          .select { |p| File.exist?(p) }
          .map { |p| File.size(p) }
        total = sizes.sum
        # Each rotation cap is at most ~max_bytes (slightly over due to the
        # entry that triggered rotation). Bound on total ≈ 3 * (100 + slack).
        expect(total).to be < 600
      end
    end
  end
end
