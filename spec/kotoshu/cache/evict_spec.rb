# frozen_string_literal: true

require "kotoshu"
require "fileutils"
require "tmpdir"
require "json"
require "time"

RSpec.describe Kotoshu::Cache::BaseCache, "#evict" do
  let(:tmpdir) { Dir.mktmpdir("kotoshu-evict") }
  # Build a LanguageCache pointed at tmpdir, then drop fake resource
  # directories into it with metadata.json + payload files. LanguageCache
  # is the concrete subclass of BaseCache we ship — using it here
  # exercises the inherited #evict without standing up a new fixture
  # subclass.
  let(:cache) do
    Kotoshu::Cache::LanguageCache.new(
      cache_path: tmpdir,
      cache_ttl: 604_800,
      max_cache_size: 1_000
    )
  end

  after { FileUtils.rm_rf(tmpdir) }

  def write_resource(lang, type, bytes:, cached_at:)
    dir = File.join(tmpdir, "languages", lang, type)
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "index.dic"), "x" * bytes)
    File.write(
      File.join(dir, "metadata.json"),
      JSON.generate(
        version: cached_at,
        url: "https://example.test",
        language: lang,
        type: type,
        checksum: "deadbeef",
        cached_at: cached_at
      )
    )
    dir
  end

  it "returns a no-op plan when nothing exceeds the cap (dry_run)" do
    write_resource("en", "spelling", bytes: 400, cached_at: "2026-03-01T00:00:00Z")

    plan = cache.evict(dry_run: true)

    expect(plan[:evict]).to eq([])
    expect(plan[:bytes_reclaimed]).to eq(0)
    expect(plan[:keep].size).to eq(1)
  end

  it "plans to evict the oldest entry when the cap is exceeded (dry_run)" do
    old_dir = write_resource("en", "spelling", bytes: 400, cached_at: "2026-01-01T00:00:00Z")
    new_dir = write_resource("de", "spelling", bytes: 400, cached_at: "2026-03-01T00:00:00Z")

    plan = cache.evict(dry_run: true)

    expect(plan[:evict].map { |e| e[:path] }).to eq([old_dir])
    expect(plan[:keep].map { |e| e[:path] }).to eq([new_dir])
    # bytes_reclaimed is the on-disk size of the evicted resource
    # directory — payload (.dic) plus metadata.json.
    expect(plan[:bytes_reclaimed]).to be > 400
    expect(plan[:bytes_reclaimed]).to be < 1_000
    # dry run does not touch the disk
    expect(File.exist?(old_dir)).to be(true)
  end

  it "removes the evicted directories when not a dry run" do
    old_dir = write_resource("en", "spelling", bytes: 600, cached_at: "2026-01-01T00:00:00Z")
    new_dir = write_resource("de", "spelling", bytes: 600, cached_at: "2026-03-01T00:00:00Z")

    plan = cache.evict(dry_run: false)

    expect(plan[:evict].map { |e| e[:path] }).to eq([old_dir])
    expect(File.exist?(old_dir)).to be(false)
    expect(File.exist?(new_dir)).to be(true)
  end

  it "skips directories that have no metadata.json" do
    # Real resource with metadata.
    keep_dir = write_resource("fr", "spelling", bytes: 200, cached_at: "2026-01-01T00:00:00Z")
    # Stray directory with payload but no metadata — should be invisible
    # to the policy (we only know what to evict from metadata.json).
    stray = File.join(tmpdir, "languages", "xx", "spelling")
    FileUtils.mkdir_p(stray)
    File.write(File.join(stray, "index.dic"), "y" * 5_000)

    plan = cache.evict(dry_run: false)

    expect(plan[:evict]).to eq([])
    expect(File.exist?(keep_dir)).to be(true)
    # We never touch the stray directory; clean_expired / purge handle it.
    expect(File.exist?(stray)).to be(true)
  end

  it "treats a corrupt metadata.json as oldest (sorted first for eviction)" do
    corrupt_dir = File.join(tmpdir, "languages", "cs", "spelling")
    FileUtils.mkdir_p(corrupt_dir)
    File.write(File.join(corrupt_dir, "index.dic"), "x" * 600)
    File.write(File.join(corrupt_dir, "metadata.json"), "{not valid json")
    fresh_dir = write_resource("sk", "spelling", bytes: 600, cached_at: "2026-03-01T00:00:00Z")

    plan = cache.evict(dry_run: false)

    expect(plan[:evict].first[:path]).to eq(corrupt_dir)
    expect(File.exist?(corrupt_dir)).to be(false)
    expect(File.exist?(fresh_dir)).to be(true)
  end

  it "respects the configured max_cache_size on the instance" do
    small_cap_cache = Kotoshu::Cache::LanguageCache.new(
      cache_path: tmpdir,
      cache_ttl: 604_800,
      max_cache_size: 10_000
    )
    write_resource("en", "spelling", bytes: 600, cached_at: "2026-01-01T00:00:00Z")

    plan = small_cap_cache.evict(dry_run: true)

    expect(plan[:evict]).to eq([])
  end
end

RSpec.describe "Configuration wiring for max_cache_size", "#evict" do
  it "the SCHEMA entry exists with the env var and Integer type" do
    schema = Kotoshu::Configuration::SCHEMA[:max_cache_size]
    expect(schema[:env]).to eq("KOTOSHU_MAX_CACHE_SIZE")
    expect(schema[:type]).to eq(Integer)
    expect(schema[:default]).to eq(1_073_741_824)
  end

  it "the Configuration instance exposes max_cache_size as a public reader" do
    expect(Kotoshu::Configuration.instance).to respond_to(:max_cache_size)
    expect(Kotoshu::Configuration.instance.max_cache_size).to be_an(Integer)
  end
end
