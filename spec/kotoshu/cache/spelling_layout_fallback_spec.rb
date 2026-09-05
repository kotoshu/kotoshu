# frozen_string_literal: true

require_relative "../../../lib/kotoshu/cache/language_cache"
require_relative "../../support/local_http_server"
require "fileutils"
require "tmpdir"

# The dictionaries repo ships only `en` under the {lang}/spelling/
# sublayout; the staged languages sit flat at {lang}/index.*. Downloads
# must try the sublayout first and fall back to the flat layout.
RSpec.describe "spelling layout fallback" do
  let(:temp_dir) { Dir.mktmpdir }

  after do
    FileUtils.rm_rf(temp_dir) if File.exist?(temp_dir)
  end

  def cache_for(server)
    Kotoshu::Cache::LanguageCache.new(
      cache_path: temp_dir,
      cache_ttl: 3600,
      source_registry: Kotoshu::SourceRegistry.new(
        base_url: server.base_url,
        pins: { "dictionaries" => "main" }
      )
    )
  end

  def server_with(layout)
    base = Dir.mktmpdir
    target = File.join(base, "dictionaries", "main", "it")
    target = File.join(target, "spelling") unless layout == :flat
    FileUtils.mkdir_p(target)
    File.binwrite(File.join(target, "index.aff"), "SET UTF-8\nTRY esianrtolcdugmphbyfvkwz\n")
    File.binwrite(File.join(target, "index.dic"), "2\nciao\nprova\n")
    LocalHttpServer.new(root: base)
  end

  it "downloads from the spelling sublayout when present" do
    server = server_with(:sublayout)
    begin
      result = cache_for(server).get_spelling("it")
      expect(File).to exist(result[:aff_path])
    ensure
      server.stop
    end
  end

  it "falls back to the flat layout when the sublayout 404s" do
    server = server_with(:flat)
    begin
      result = cache_for(server).get_spelling("it")
      expect(File).to exist(result[:aff_path])
      expect(File).to exist(result[:dic_path])
      expect(File.read(File.join(temp_dir, "languages", "it", "spelling", "index.dic")))
        .to include("prova")
    ensure
      server.stop
    end
  end

  it "raises naming the flat URL when both layouts are missing" do
    base = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(base, "dictionaries", "main", "it"))
    server = LocalHttpServer.new(root: base)
    begin
      expect { cache_for(server).get_spelling("it") }
        .to raise_error(Kotoshu::DictionaryNotFoundError, %r{/it/index\.aff})
    ensure
      server.stop
    end
  end
end

# Baseline paths compare canonically: a baseline recorded as
# `docs/a.md` matches a check run over `./docs/a.md` (directory
# walking prefixes `./`), and recorded entries are stored canonical.
RSpec.describe Kotoshu::Baseline::Store do
  describe ".canonical_path" do
    it "strips a leading ./ and collapses duplicate separators" do
      expect(described_class.canonical_path("./docs/a.md")).to eq("docs/a.md")
      expect(described_class.canonical_path("docs//a.md")).to eq("docs/a.md")
      expect(described_class.canonical_path("/abs/a.md")).to eq("/abs/a.md")
    end
  end

  describe "#entries_for" do
    it "matches ./-prefixed checks against plain-path entries" do
      store = described_class.new(
        entries: [
          Kotoshu::Baseline::Entry.new(file: "docs/a.md", line: 1, word: "helo", count: 1)
        ]
      )

      expect(store.entries_for("./docs/a.md")).to eq(store.entries)
      expect(store.entries_for("docs/a.md")).to eq(store.entries)
      expect(store.entries_for("docs/b.md")).to be_empty
    end
  end
end
