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
