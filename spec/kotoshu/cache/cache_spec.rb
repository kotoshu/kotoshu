# frozen_string_literal: true

require "kotoshu"
require "tmpdir"
require "fileutils"
require "json"

# Trigger autoload of the cache constants exercised below.
Kotoshu::Cache::Cache
Kotoshu::Cache::BaseCache
Kotoshu::Cache::FrequencyCache

# Direct spec for the un-specced files in lib/kotoshu/cache/:
#   cache.rb            — abstract Cache interface (module)
#   base_cache.rb       — shared download/metadata/eviction base class
#   frequency_cache.rb  — Kelly frequency-list backend
#
# language_cache.rb, model_cache.rb, lookup_cache.rb, suggestion_cache.rb,
# and eviction_policy.rb already have dedicated specs.
RSpec.describe Kotoshu::Cache do
  # ---- Cache (abstract module) -----------------------------------------

  describe Kotoshu::Cache::Cache do
    # Build a fresh anonymous include of the module so the abstract
    # methods are exercised without picking up any concrete subclass
    # behavior.
    let(:instance) do
      klass = Class.new do
        include Kotoshu::Cache::Cache
      end
      klass.new
    end

    %i[fetch write read delete clear key? size stats reset_stats].each do |method|
      it "##{method} raises NotImplementedError (abstract contract)" do
        # fetch and write take blocks/args differently — supply enough
        # to satisfy arity without asserting on the call shape.
        args = []
        args << :key if %i[fetch write read delete key?].include?(method)
        args << :value if method == :write
        block = method == :fetch ? -> { :computed } : nil

        expect { instance.public_send(method, *args, &block) }
          .to raise_error(NotImplementedError)
      end
    end
  end

  # ---- BaseCache -------------------------------------------------------

  describe Kotoshu::Cache::BaseCache do
    # Bare subclass — inherits the abstract methods so they raise
    # NotImplementedError. (BaseCache itself is abstract.)
    let(:bare_subclass) do
      Class.new(described_class) do
        def default_cache_path
          @tmp_path
        end
      end
    end

    let(:tmpdir) { Dir.mktmpdir("kotoshu-basecache-spec") }

    after { FileUtils.rm_rf(tmpdir) if File.exist?(tmpdir) }

    describe "#initialize" do
      it "exposes cache_path, cache_ttl, max_cache_size, source_registry as readers" do
        c = described_class.new(cache_path: tmpdir, cache_ttl: 60, max_cache_size: 1024)
        expect(c.cache_path).to eq(tmpdir)
        expect(c.cache_ttl).to eq(60)
        expect(c.max_cache_size).to eq(1024)
        expect(c.source_registry).to be_a(Kotoshu::SourceRegistry)
      end

      it "creates the cache directory and a tmp/ subdirectory on construction" do
        described_class.new(cache_path: tmpdir)
        expect(File.directory?(tmpdir)).to be true
        expect(File.directory?(File.join(tmpdir, "tmp"))).to be true
      end

      it "defaults cache_ttl to 7 days (604_800 seconds)" do
        c = described_class.new(cache_path: tmpdir)
        expect(c.cache_ttl).to eq(604_800)
      end

      it "pulls max_cache_size from Configuration by default" do
        c = described_class.new(cache_path: tmpdir)
        expect(c.max_cache_size).to eq(Kotoshu::Configuration.instance.max_cache_size)
      end

      it "pulls source_registry from Configuration by default" do
        c = described_class.new(cache_path: tmpdir)
        # SourceRegistry doesn't define ==, so compare the underlying state.
        expect(c.source_registry).to be_a(Kotoshu::SourceRegistry)
        expect(c.source_registry.base_url).to eq(Kotoshu::Configuration.instance.source_registry.base_url)
      end
    end

    describe "abstract template methods" do
      let(:bare_instance) { bare_subclass.new(cache_path: tmpdir) }

      # Map each abstract method to its required argument count.
      {
        cached_resources: 0,
        supports_resource?: 1,
        download_resource: 2,
        load_cached: 1,
        metadata_path_for: 1,
        resource_dir_for: 1,
        resource_files_exist?: 1
      }.each do |method, arity|
        it "##{method} raises NotImplementedError" do
          args = ["en"].take(arity) + (arity == 2 ? ["dest"] : [])
          expect { bare_instance.public_send(method, *args) }
            .to raise_error(NotImplementedError, /Subclass must implement/)
        end
      end
    end

    describe "#stats / #reset_stats" do
      # Use a concrete subclass so the abstract cached_resources is
      # filled in — stats calls it.
      let(:cache) do
        klass = Class.new(described_class) do
          def cached_resources
            Dir.children(cache_path).reject { |p| p.start_with?(".") || p == "tmp" }
          end
        end
        klass.new(cache_path: tmpdir)
      end

      it "stats returns the documented shape with zero counters by default" do
        s = cache.stats
        expect(s).to include(hits: 0, misses: 0, total: 0, hit_rate: 0.0)
        expect(s).to include(:cached_resources, :size_bytes, :oldest_entry)
      end

      it "reset_stats returns self for chaining" do
        expect(cache.reset_stats).to be(cache)
      end
    end

    describe "#available? / #get / #clear / #clear_all" do
      # Concrete subclass with an in-memory resource map.
      let(:concrete_subclass) do
        Class.new(described_class) do
          def initialize(cache_path:, supported:)
            super(cache_path: cache_path)
            @supported = supported
          end

          def supports_resource?(id)
            @supported.include?(id)
          end

          def cached_resources
            Dir.children(@cache_path).reject { |p| p.start_with?(".") }
          end

          def metadata_path_for(id)
            File.join(@cache_path, id, "metadata.json")
          end

          def resource_dir_for(id)
            File.join(@cache_path, id)
          end

          def resource_files_exist?(id)
            File.exist?(File.join(@cache_path, id, "data.txt"))
          end

          def download_resource(id, dest)
            FileUtils.mkdir_p(dest)
            File.write(File.join(dest, "data.txt"), "data for #{id}")
            File.write(File.join(dest, "metadata.json"),
                       JSON.pretty_generate("cached_at" => Time.now.utc.iso8601))
            { id: id }
          end

          def load_cached(id)
            { id: id, path: File.join(@cache_path, id, "data.txt") }
          end
        end
      end

      let(:cache) { concrete_subclass.new(cache_path: tmpdir, supported: %w[en de]) }

      it "available? is false when the resource is not supported" do
        expect(cache.available?("xx")).to be false
      end

      it "available? is false when supported but no metadata is on disk" do
        expect(cache.available?("en")).to be false
      end

      it "clear returns false for an unsupported resource" do
        expect(cache.clear("xx")).to be false
      end

      it "clear returns false when the resource dir does not exist" do
        expect(cache.clear("en")).to be false
      end

      it "clear_all wipes the cache directory and rebuilds tmp/" do
        FileUtils.mkdir_p(File.join(tmpdir, "en"))
        File.write(File.join(tmpdir, "en", "data.txt"), "x")
        cache.clear_all
        expect(File.exist?(File.join(tmpdir, "en"))).to be false
        expect(File.directory?(File.join(tmpdir, "tmp"))).to be true
      end
    end

    describe "#evict" do
      let(:cache) { described_class.new(cache_path: tmpdir, max_cache_size: 1_000) }

      it "returns a plan with :evict / :keep / :bytes_reclaimed keys" do
        plan = cache.evict(dry_run: true)
        expect(plan).to include(:evict, :keep, :bytes_reclaimed)
        expect(plan[:evict]).to be_an(Array)
        expect(plan[:keep]).to be_an(Array)
      end

      it "dry_run: true does not modify the disk" do
        FileUtils.mkdir_p(File.join(tmpdir, "lang1"))
        File.write(File.join(tmpdir, "lang1", "data"), "x" * 500)
        cache.evict(dry_run: true)
        expect(File.exist?(File.join(tmpdir, "lang1", "data"))).to be true
      end

      it "without dry_run removes the evicted entries" do
        # Seed two metadata.json-bearing entries that together exceed
        # the 1_000 byte cap. (collect_eviction_entries walks for
        # metadata.json files — that's how evict decides what's live.)
        dir_a = File.join(tmpdir, "lang_a")
        dir_b = File.join(tmpdir, "lang_b")
        FileUtils.mkdir_p([dir_a, dir_b])
        File.write(File.join(dir_a, "data"), "a" * 800)
        File.write(File.join(dir_a, "metadata.json"), JSON.pretty_generate("cached_at" => Time.now.utc.iso8601))
        File.write(File.join(dir_b, "data"), "b" * 800)
        File.write(File.join(dir_b, "metadata.json"), JSON.pretty_generate("cached_at" => Time.now.utc.iso8601))

        cache.evict
        remaining = Dir.children(tmpdir).reject { |p| p.start_with?(".") || p == "tmp" }
        expect(remaining.length).to be < 2
      end
    end
  end

  # ---- FrequencyCache --------------------------------------------------

  describe Kotoshu::Cache::FrequencyCache do
    let(:tmpdir) { Dir.mktmpdir("kotoshu-freqcache-spec") }
    let(:cache) { described_class.new(cache_path: tmpdir) }

    after { FileUtils.rm_rf(tmpdir) if File.exist?(tmpdir) }

    describe "constants" do
      it "KELLY_LANGUAGES lists the 8 supported languages" do
        expect(described_class.const_get(:KELLY_LANGUAGES))
          .to contain_exactly("ar", "zh", "en", "el", "it", "no", "ru", "sv")
      end

      it "GITHUB_REPO points at the kotoshu/frequency-list-kelly repo" do
        expect(described_class.const_get(:GITHUB_REPO)).to eq("kotoshu/frequency-list-kelly")
      end

      it "GITHUB_BRANCH is 'main'" do
        expect(described_class.const_get(:GITHUB_BRANCH)).to eq("main")
      end
    end

    describe "#available_languages" do
      it "returns the Kelly languages as a fresh Array (not the frozen constant)" do
        langs = cache.available_languages
        expect(langs).to eq(described_class.const_get(:KELLY_LANGUAGES))
        expect(langs).not_to be(described_class.const_get(:KELLY_LANGUAGES))
      end
    end

    describe "#supports_resource?" do
      it "is true for every Kelly language" do
        %w[ar zh en el it no ru sv].each do |code|
          expect(cache.supports_resource?(code)).to be(true), "expected #{code} supported"
        end
      end

      it "is false for unsupported codes" do
        expect(cache.supports_resource?("de")).to be false
        expect(cache.supports_resource?("fr")).to be false
      end
    end

    describe "#cached_resources" do
      it "lists directories under cache_path (ignoring dotfiles and tmp/)" do
        FileUtils.mkdir_p(File.join(tmpdir, "en"))
        FileUtils.mkdir_p(File.join(tmpdir, "ru"))
        FileUtils.mkdir_p(File.join(tmpdir, ".hidden"))
        File.write(File.join(tmpdir, "scratch.txt"), "x")

        expect(cache.cached_resources.sort).to eq(%w[en ru])
      end

      it "is empty when nothing has been cached (tmp/ exists but is not a language)" do
        expect(cache.cached_resources).to eq([])
      end
    end

    describe "#get_frequency" do
      it "returns nil for unsupported languages without making a network call" do
        # 'de' is not in KELLY_LANGUAGES, so supports_resource? returns
        # false and get short-circuits before download. Supported
        # languages require a real download (see :network integration
        # specs).
        expect(cache.get_frequency("de")).to be_nil
      end
    end
  end
end
