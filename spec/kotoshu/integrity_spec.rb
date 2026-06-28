# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "json"

# Real-instance specs for the Integrity module. No mocks — manifest
# verification is tested against real SHA-256 computation. The NetHTTP
# shim is exercised via a stub callable that responds to `get(url)`,
# which is permitted (it's a seam, not a double of a real class).
RSpec.describe Kotoshu::Integrity do
  describe Kotoshu::Integrity::Manifest do
    let(:sha256_en_aff) { Digest::SHA256.hexdigest("AFF CONTENT EN") }
    let(:sha256_en_dic) { Digest::SHA256.hexdigest("DIC CONTENT EN") }

    let(:manifest_json) do
      {
        "version" => 1,
        "generated_at" => "2026-06-25T10:00:00Z",
        "resources" => {
          "en/spelling/index.aff" => {
            "size" => 15, "sha256" => sha256_en_aff,
            "language" => "en", "type" => "spelling"
          },
          "en/spelling/index.dic" => {
            "size" => 15, "sha256" => sha256_en_dic,
            "language" => "en", "type" => "spelling"
          }
        }
      }.to_json
    end

    describe ".parse" do
      it "returns a Manifest with entries keyed by relative path" do
        manifest = described_class.parse(manifest_json)

        expect(manifest).to be_a(described_class)
        expect(manifest.version).to eq(1)
        expect(manifest.generated_at).to eq("2026-06-25T10:00:00Z")
        expect(manifest.fetch("en/spelling/index.aff").sha256).to eq(sha256_en_aff)
      end

      it "returns an empty manifest when the resources section is absent" do
        manifest = described_class.parse('{"version":1}')
        expect(manifest.empty?).to eq(true)
      end

      it "raises IntegrityError on malformed JSON" do
        expect { described_class.parse("{not json") }.to raise_error(Kotoshu::IntegrityError)
      end
    end

    describe "#verify_content!" do
      let(:manifest) { described_class.parse(manifest_json) }

      it "returns true when content matches the manifest entry" do
        expect(manifest.verify_content!("en/spelling/index.aff", "AFF CONTENT EN")).to eq(true)
      end

      it "raises IntegrityError with expected and actual hashes on mismatch" do
        bad = "TAMPERED CONTENT"
        actual_hash = Digest::SHA256.hexdigest(bad)

        expect do
          manifest.verify_content!("en/spelling/index.aff", bad, url: "https://x/y.aff")
        end.to raise_error(Kotoshu::IntegrityError) do |err|
          expect(err.expected).to eq(sha256_en_aff)
          expect(err.actual).to eq(actual_hash)
          expect(err.url).to eq("https://x/y.aff")
          expect(err.resource_id).to eq("en/spelling/index.aff")
        end
      end

      it "returns nil (no-op) when the path is not in the manifest" do
        result = manifest.verify_content!("unknown/path.txt", "anything")
        expect(result).to be_nil
      end
    end

    describe ".load" do
      let(:stub_http) do
        Module.new do
          @responses = {}
          def self.set(url, body)
            @responses ||= {}
            @responses[url] = body
          end

          def self.clear
            @responses&.clear
          end

          def self.get(url, **)
            @responses ||= {}
            @responses.fetch(url) { raise Kotoshu::Integrity::NetHTTP::HttpError, "not stubbed" }
          end
        end
      end

      before do
        stub_http.clear
        stub_http.set("https://example.test/manifest.json", manifest_json)
      end

      it "fetches and parses the manifest from a URL" do
        manifest = described_class.load("https://example.test/manifest.json", http: stub_http)
        expect(manifest.fetch("en/spelling/index.aff").sha256).to eq(sha256_en_aff)
      end

      it "returns nil when manifest is absent (HTTP 404)" do
        # Simulate 404 by returning nil from the http shim
        four_oh_four = Module.new do
          def self.get(_url, **)
            nil
          end
        end

        result = described_class.load("https://example.test/manifest.json", http: four_oh_four)
        expect(result).to be_nil
      end
    end
  end

  describe Kotoshu::Integrity::RotationPolicy do
    it "uses the documented defaults" do
      policy = described_class.new
      expect(policy.max_bytes).to eq(described_class::DEFAULT_MAX_BYTES)
      expect(policy.rotations).to eq(described_class::DEFAULT_ROTATIONS)
    end

    it "rejects negative max_bytes" do
      expect { described_class.new(max_bytes: -1) }.to raise_error(ArgumentError)
    end

    it "rejects negative rotations" do
      expect { described_class.new(rotations: -1) }.to raise_error(ArgumentError)
    end

    it "is wired to Configuration via the audit_max_bytes / audit_rotations accessors" do
      schema = Kotoshu::Configuration::SCHEMA
      expect(schema).to have_key(:audit_max_bytes)
      expect(schema).to have_key(:audit_rotations)
      expect(schema[:audit_max_bytes][:env]).to eq("KOTOSHU_AUDIT_MAX_BYTES")
      expect(schema[:audit_rotations][:env]).to eq("KOTOSHU_AUDIT_ROTATIONS")

      config = Kotoshu::Configuration.instance
      expect(config).to respond_to(:audit_max_bytes)
      expect(config).to respond_to(:audit_rotations=)
      expect(config.audit_max_bytes).to eq(schema[:audit_max_bytes][:default])
      expect(config.audit_rotations).to eq(schema[:audit_rotations][:default])
    end

    describe "#rotate?" do
      it "is false at and below the threshold" do
        policy = described_class.new(max_bytes: 100, rotations: 3)
        expect(policy.rotate?(0)).to eq(false)
        expect(policy.rotate?(100)).to eq(false)
      end

      it "is true above the threshold" do
        policy = described_class.new(max_bytes: 100, rotations: 3)
        expect(policy.rotate?(101)).to eq(true)
      end
    end

    describe "#plan_for" do
      it "produces a drop + shift + promote plan when rotations > 0" do
        policy = described_class.new(max_bytes: 100, rotations: 3)
        plan = policy.plan_for("/tmp/audit.log")

        # Oldest rotation slot is dropped.
        expect(plan[:deletes]).to eq(["/tmp/audit.log.3"])

        # Existing rotations shift up by one (oldest-first to avoid clobber).
        expect(plan[:moves]).to eq([
                                     ["/tmp/audit.log.2", "/tmp/audit.log.3"],
                                     ["/tmp/audit.log.1", "/tmp/audit.log.2"],
                                     ["/tmp/audit.log", "/tmp/audit.log.1"]
                                   ])
      end

      it "truncates the current log when rotations == 0" do
        policy = described_class.new(max_bytes: 100, rotations: 0)
        plan = policy.plan_for("/tmp/audit.log")

        expect(plan[:deletes]).to eq(["/tmp/audit.log"])
        expect(plan[:moves]).to eq([])
      end

      it "preserves plan shape at rotations == 1 (current → .1 only)" do
        policy = described_class.new(max_bytes: 100, rotations: 1)
        plan = policy.plan_for("/tmp/audit.log")

        expect(plan[:deletes]).to eq(["/tmp/audit.log.1"])
        expect(plan[:moves]).to eq([
                                     ["/tmp/audit.log", "/tmp/audit.log.1"]
                                   ])
      end
    end
  end

  describe Kotoshu::Integrity::AuditLog do
    let(:tmpdir) { Dir.mktmpdir("kotoshu-audit") }
    let(:log_path) { File.join(tmpdir, "audit.log") }
    let(:log) { described_class.new(path: log_path) }

    after { FileUtils.rm_rf(tmpdir) }

    it "appends one JSON object per line per record" do
      log.record(url: "https://x/a", status: "verified", size: 10,
                 sha256: "abc", manifest_sha256: "abc", resource_id: "en:spelling")
      log.record(url: "https://x/b", status: "unverified", size: 5,
                 sha256: "def", resource_id: "de:spelling")

      lines = File.readlines(log_path).map { |l| JSON.parse(l.strip) }
      expect(lines.length).to eq(2)
      expect(lines[0]["status"]).to eq("verified")
      expect(lines[0]["manifest_sha256"]).to eq("abc")
      expect(lines[1]["status"]).to eq("unverified")
    end

    it "exposes entries via #each and #entries" do
      log.record(url: "https://x", status: "missing", resource_id: "ru:spelling")

      entries = log.entries
      expect(entries.length).to eq(1)
      expect(entries[0]["status"]).to eq("missing")
      expect(entries[0]["resource_id"]).to eq("ru:spelling")
      expect(entries[0]["timestamp"]).to match(/\A\d{4}-\d{2}-\d{2}T/)
    end

    it "creates the parent directory if it does not exist" do
      nested = File.join(tmpdir, "deeply", "nested", "audit.log")
      described_class.new(path: nested).record(url: "https://x", status: "verified")
      expect(File.exist?(nested)).to eq(true)
    end

    it "can be cleared" do
      log.record(url: "https://x", status: "verified")
      expect(File.exist?(log_path)).to eq(true)
      log.clear!
      expect(File.exist?(log_path)).to eq(false)
    end

    it "returns the written entry from #record" do
      entry = log.record(url: "https://x", status: "verified", size: 7, sha256: "deadbeef")
      expect(entry).to be_a(Hash)
      expect(entry[:url]).to eq("https://x")
      expect(entry[:size]).to eq(7)
      expect(entry[:status]).to eq("verified")
    end

    context "with a rotation policy" do
      let(:policy) do
        Kotoshu::Integrity::RotationPolicy.new(max_bytes: 1024, rotations: 3)
      end
      let(:log) { described_class.new(path: log_path, rotation_policy: policy) }

      it "does not rotate while under the threshold" do
        log.record(url: "https://x", status: "verified")
        log.record(url: "https://x", status: "verified")

        expect(File.exist?("#{log_path}.1")).to eq(false)
      end

      it "promotes the current log to .1 once over the threshold" do
        # First write fills the file past the threshold.
        big = "x" * 1200
        log.record(url: "https://x/#{big}", status: "verified")
        expect(File.size(log_path)).to be > 1024

        # Second write triggers rotation: current → .1, then new entry written.
        log.record(url: "https://x/fresh", status: "verified")

        expect(File.exist?("#{log_path}.1")).to eq(true)
        expect(File.exist?("#{log_path}.2")).to eq(false)

        # The rotated file contains the entry from before the rotation.
        rotated_lines = File.readlines("#{log_path}.1")
        expect(rotated_lines.length).to eq(1)
        expect(JSON.parse(rotated_lines.first.strip)["url"]).to include(big)

        # The current file contains only the entry written after rotation.
        current_lines = File.readlines(log_path)
        expect(current_lines.length).to eq(1)
        expect(JSON.parse(current_lines.first.strip)["url"]).to eq("https://x/fresh")
      end

      it "shifts existing rotations up before promoting current" do
        # Seed .1 with content so we can observe the shift.
        File.write("#{log_path}.1", "old-rotation-1\n")

        # Push current past the threshold and write again.
        big = "x" * 1200
        log.record(url: "https://x/#{big}", status: "verified")
        log.record(url: "https://x/again", status: "verified")

        # Original .1 is now .2.
        expect(File.exist?("#{log_path}.2")).to eq(true)
        expect(File.read("#{log_path}.2")).to eq("old-rotation-1\n")
        # New .1 is the freshly-rotated current.
        expect(File.exist?("#{log_path}.1")).to eq(true)
      end

      it "caps total rotations at the configured count" do
        # Fill and rotate enough times to overflow.
        10.times do |i|
          big = "x" * 1200
          log.record(url: "https://x/#{i}/#{big}", status: "verified")
        end

        (1..3).each { |n| expect(File.exist?("#{log_path}.#{n}")).to eq(true) }
        expect(File.exist?("#{log_path}.4")).to eq(false)
      end

      it "exposes rotated entries via #entries (newest-first)" do
        # Force one rotation by writing a big entry then a small one.
        big = "x" * 1200
        log.record(url: "https://x/#{big}", status: "verified")
        log.record(url: "https://x/fresh", status: "verified")

        urls = log.entries.map { |e| e["url"] }
        # Newest (current) comes first, followed by the rotated entry.
        expect(urls.first).to eq("https://x/fresh")
        expect(urls.any? { |u| u.include?(big) }).to eq(true)
      end

      it "clears the current log and all rotations on clear!" do
        big = "x" * 1200
        log.record(url: "https://x/#{big}", status: "verified")
        log.record(url: "https://x/fresh", status: "verified")
        expect(File.exist?("#{log_path}.1")).to eq(true)

        log.clear!

        expect(File.exist?(log_path)).to eq(false)
        expect(File.exist?("#{log_path}.1")).to eq(false)
      end
    end
  end

  describe Kotoshu::IntegrityError do
    it "carries resource_id, expected, actual, url" do
      err = described_class.new("en/spelling/index.aff",
                                expected: "aaaa",
                                actual: "bbbb",
                                url: "https://x/y")
      expect(err.resource_id).to eq("en/spelling/index.aff")
      expect(err.expected).to eq("aaaa")
      expect(err.actual).to eq("bbbb")
      expect(err.url).to eq("https://x/y")
    end

    it "is a Kotoshu::Error" do
      expect(described_class.new("x", expected: "a", actual: "b")).to be_a(Kotoshu::Error)
    end
  end
end
