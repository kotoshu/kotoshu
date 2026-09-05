# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"
require "kotoshu/jekyll"

# Jekyll generator specs (plan 89, item 4): the real Jekyll, a real
# site with posts and drafts, the real engine. Skips when jekyll is
# not installed.
RSpec.describe Kotoshu::Jekyll::Generator do
  unless Kotoshu::Jekyll::JEKYLL_LOADED
    skip "jekyll not installed"
  end

  EN_AFF = File.expand_path("../integrational/fixtures/en_US.aff", __dir__)
  EN_DIC = File.expand_path("../integrational/fixtures/en_US.dic", __dir__)

  before(:all) do
    skip "en_US fixtures missing" unless File.exist?(EN_AFF) && File.exist?(EN_DIC)
    @dir = Dir.mktmpdir
    @cache = File.join(@dir, "cache")
    cache_dir = File.join(@cache, "languages", "en", "spelling")
    FileUtils.mkdir_p(cache_dir)
    FileUtils.cp(EN_AFF, File.join(cache_dir, "index.aff"))
    FileUtils.cp(EN_DIC, File.join(cache_dir, "index.dic"))
    File.write(File.join(cache_dir, "metadata.json"), {
      "language" => "en",
      "type" => "spelling",
      "version" => "2026-01-01T00:00:00Z",
      "cached_at" => Time.now.utc.iso8601,
      "source" => "fixture"
    }.to_json)
    @old_env = %w[KOTOSHU_CACHE_PATH XDG_CONFIG_HOME XDG_DATA_HOME].to_h { |k| [k, ENV.fetch(k, nil)] }
    ENV["KOTOSHU_CACHE_PATH"] = @cache
    ENV["XDG_CONFIG_HOME"] = File.join(@dir, "config")
    ENV["XDG_DATA_HOME"] = File.join(@dir, "local")
    Kotoshu::Configuration.reset
    Kotoshu.reset_spellchecker
  end

  after(:all) do
    Kotoshu::Configuration.reset
    Kotoshu.reset_spellchecker
    @old_env&.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    FileUtils.remove_entry(@dir) if @dir
  end

  around do |example|
    Dir.mktmpdir do |site_dir|
      @site_dir = site_dir
      example.run
    end
  end

  def write_post(name, content)
    path = File.join(@site_dir, "_posts", name)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "---\nlayout: post\ntitle: Test\n---\n#{content}\n")
    path
  end

  def build_site(show_drafts: false)
    config = Jekyll.configuration(
      "source" => @site_dir,
      "destination" => File.join(@site_dir, "_site"),
      "show_drafts" => show_drafts,
      "disable_disk_cache" => true,
      "quiet" => true,
      "url" => "https://example.com"
    )
    site = Jekyll::Site.new(config)
    site.read
    site
  end

  it "is a registered-safe Jekyll generator" do
    expect(described_class.superclass).to eq(Jekyll::Generator)
    expect(described_class.safe).to be(true)
  end

  it "passes a clean site" do
    write_post("2026-01-01-clean.md", "hello world")

    expect { described_class.new.generate(build_site) }.not_to raise_error
  end

  it "fails the build naming the post and word" do
    write_post("2026-01-01-dirty.md", "hello wrold")

    expect { described_class.new.generate(build_site) }.to raise_error(RuntimeError) do |error|
      expect(error.message).to include("wrold")
      expect(error.message).to include("2026-01-01-dirty.md")
    end
  end

  it "checks drafts when the site builds with drafts" do
    FileUtils.mkdir_p(File.join(@site_dir, "_drafts"))
    File.write(File.join(@site_dir, "_drafts", "wip.md"),
               "---\nlayout: post\ntitle: WIP\n---\nwrold again\n")

    expect { described_class.new.generate(build_site(show_drafts: true)) }
      .to raise_error(RuntimeError, /wrold/)
  end

  it "respects a baseline in the site source" do
    write_post("2026-01-01-dirty.md", "hello wrold")
    site = build_site
    document = site.posts.docs.first
    checks = { document.relative_path.to_s => [Kotoshu.check(document.content), document.content] }
    Kotoshu::Baseline::Store.from_checks(checks)
      .save(File.join(@site_dir, ".kotoshu-baseline.json"))

    expect { described_class.new.generate(build_site) }.not_to raise_error

    write_post("2026-01-02-new.md", "xyzzy here\n")
    expect { described_class.new.generate(build_site) }
      .to raise_error(RuntimeError, /xyzzy/)
  end

  it "is quiet for a site without posts" do
    expect { described_class.new.generate(build_site) }.not_to raise_error
  end
end
