# frozen_string_literal: true

require "kotoshu"
require "tmpdir"
require "fileutils"

# Trigger autoload of every embeddings constant we exercise below.
Kotoshu::Embeddings::Protocol
Kotoshu::Embeddings::EmbeddingModelProtocol
Kotoshu::Embeddings::SimilarityEngineProtocol
Kotoshu::Embeddings::VocabularyProtocol
Kotoshu::Embeddings::Registry
Kotoshu::Embeddings::Search
Kotoshu::Embeddings::EmbeddingPipeline
Kotoshu::Embeddings::OnnxRuntimeModel

# Direct spec for the un-specced files in lib/kotoshu/embeddings/:
#   protocol.rb, registry.rb, search.rb, embedding_pipeline.rb,
#   onnx_runtime_model.rb
#
# vocabulary.rb, similarity_engine.rb, similarity_search.rb and
# lru_cache.rb already have dedicated specs and are not duplicated here.
#
# lib/kotoshu/embeddings/protocols.rb (plural) is intentionally not
# specced: it is a broken orphan — it `require_relative`s three
# nonexistent files under `protocols/` and re-binds top-level constants
# (EmbeddingModel, SimilarityEngine, Vocabulary) that do not exist.
# Nothing in lib/, spec/, or exe/ loads it; the autoload table in
# lib/kotoshu/embeddings.rb does not reference it. Flagged for the user
# to delete or rewrite in a follow-up.
RSpec.describe Kotoshu::Embeddings do
  # ---- Protocol --------------------------------------------------------

  describe Kotoshu::Embeddings::Protocol do
    # Build a fresh anonymous protocol per test so registrations don't
    # leak across examples (the built-in EmbeddingModelProtocol /
    # SimilarityEngineProtocol / VocabularyProtocol ship with their own
    # required method sets).
    let(:protocol_module) do
      m = Module.new
      m.singleton_class.include described_class
      m
    end

    it "exposes required_methods as a Set (empty by default)" do
      expect(protocol_module.required_methods).to be_a(Set)
      expect(protocol_module.required_methods).to be_empty
    end

    it "exposes optional_methods as a Set (empty by default)" do
      expect(protocol_module.optional_methods).to be_a(Set)
      expect(protocol_module.optional_methods).to be_empty
    end

    it "lets `required` add method names to required_methods" do
      protocol_module.required(:foo, :bar)
      expect(protocol_module.required_methods).to include(:foo, :bar)
    end

    it "lets `optional` add method names to optional_methods" do
      protocol_module.optional(:baz)
      expect(protocol_module.optional_methods).to include(:baz)
    end

    describe "#compliance_errors" do
      it "returns an empty collection when the class implements every required method" do
        protocol_module.required(:foo)
        klass = Class.new { def foo; end }
        expect(protocol_module.compliance_errors(klass)).to be_empty
      end

      it "lists the missing methods when the class is non-conformant" do
        protocol_module.required(:foo, :bar, :baz)
        klass = Class.new { def foo; end }
        errors = protocol_module.compliance_errors(klass)
        expect(errors).to include(:bar, :baz)
        expect(errors).not_to include(:foo)
      end
    end

    describe "#assert_implemented_by!" do
      it "is a no-op when the class conforms" do
        protocol_module.required(:foo)
        klass = Class.new { def foo; end }
        expect { protocol_module.assert_implemented_by!(klass) }.not_to raise_error
      end

      it "raises ProtocolError listing the missing methods" do
        protocol_module.required(:foo, :bar)
        klass = Class.new
        expect do
          protocol_module.assert_implemented_by!(klass)
        end.to raise_error(Kotoshu::Embeddings::ProtocolError, /missing: (foo|bar), (foo|bar)/)
      end

      it "exposes the offending class, protocol, and missing methods on the error" do
        protocol_module.required(:foo)
        klass = Class.new
        begin
          protocol_module.assert_implemented_by!(klass)
        rescue Kotoshu::Embeddings::ProtocolError => e
          expect(e.klass).to eq(klass)
          expect(e.protocol).to eq(protocol_module)
          expect(e.missing_methods).to eq(%i[foo])
        else
          raise "expected ProtocolError"
        end
      end
    end
  end

  describe Kotoshu::Embeddings::ProtocolError do
    it "is a StandardError subclass" do
      expect(described_class).to be < StandardError
    end

    it "carries klass, protocol, and missing_methods as read-only attributes" do
      klass = Class.new
      protocol = Module.new
      err = described_class.new(klass, protocol, %i[foo bar])
      expect(err.klass).to eq(klass)
      expect(err.protocol).to eq(protocol)
      expect(err.missing_methods).to eq(%i[foo bar])
      expect(err.message).to eq("#{klass} missing: foo, bar")
    end
  end

  describe Kotoshu::Embeddings::EmbeddingModelProtocol do
    it "requires the documented embedding-model methods" do
      expect(described_class.required_methods).to include(
        :dimension, :language_code, :get_embedding, :get_embeddings,
        :load!, :unload!, :loaded?, :ready?
      )
    end
  end

  describe Kotoshu::Embeddings::SimilarityEngineProtocol do
    it "requires the four similarity metrics plus the normalization pair" do
      expect(described_class.required_methods).to include(
        :cosine, :dot_product, :euclidean, :manhattan,
        :pre_normalize, :normalize_and_compute
      )
    end
  end

  describe Kotoshu::Embeddings::VocabularyProtocol do
    it "requires the lookup and traversal methods" do
      expect(described_class.required_methods).to include(
        :lookup, :get_word, :include?, :size, :words,
        :valid_index?, :common_words, :to_h
      )
    end
  end

  # ---- Registry --------------------------------------------------------

  describe Kotoshu::Embeddings::Registry do
    # Snapshot the built-in registrations so each example can mutate the
    # registry freely without disturbing other tests or downstream suites.
    before do
      @saved_models = described_class.models.dup
      @saved_engines = described_class.engines.dup
      @saved_vocabs = described_class.vocabularies.dup
    end

    after do
      described_class.reset!
      @saved_models.each { |n, k| described_class.register_model(n, k) }
      @saved_engines.each { |n, k| described_class.register_engine(n, k) }
      @saved_vocabs.each { |n, k| described_class.register_vocabulary(n, k) }
    end

    describe "boot-time registration" do
      it "registers :onnx => OnnxRuntimeModel" do
        expect(described_class.model(:onnx)).to eq(Kotoshu::Embeddings::OnnxRuntimeModel)
      end

      it "registers :cosine => SimilarityEngine" do
        expect(described_class.engine(:cosine)).to eq(Kotoshu::Embeddings::SimilarityEngine)
      end

      it "registers :json => Vocabulary" do
        expect(described_class.vocabulary(:json)).to eq(Kotoshu::Embeddings::Vocabulary)
      end

      it "lists the built-in names" do
        expect(described_class.model_names).to include(:onnx)
        expect(described_class.engine_names).to include(:cosine)
        expect(described_class.vocabulary_names).to include(:json)
      end
    end

    describe ".register_model / .register_engine / .register_vocabulary" do
      it "stores the class under the given name and returns it" do
        klass = Class.new
        expect(described_class.register_model(:custom_a, klass)).to eq(klass)
        expect(described_class.model(:custom_a)).to eq(klass)
      end

      it "supports engines and vocabularies" do
        engine_klass = Class.new
        vocab_klass = Class.new
        described_class.register_engine(:custom_engine, engine_klass)
        described_class.register_vocabulary(:custom_vocab, vocab_klass)
        expect(described_class.engine(:custom_engine)).to eq(engine_klass)
        expect(described_class.vocabulary(:custom_vocab)).to eq(vocab_klass)
      end

      it "overwrites a previous registration with the new class" do
        first = Class.new
        second = Class.new
        described_class.register_model(:overwrite, first)
        described_class.register_model(:overwrite, second)
        expect(described_class.model(:overwrite)).to eq(second)
      end
    end

    describe ".create_model / .create_engine / .create_vocabulary" do
      it "instantiates the registered class with the given kwargs" do
        klass = Class.new do
          def initialize(a:, b:)
            @a = a
            @b = b
          end
          attr_reader :a, :b
        end
        described_class.register_model(:instantiable, klass)

        instance = described_class.create_model(:instantiable, a: 1, b: 2)
        expect(instance).to be_a(klass)
        expect(instance.a).to eq(1)
        expect(instance.b).to eq(2)
      end

      it "raises ArgumentError for an unknown model name" do
        expect { described_class.create_model(:nonexistent) }
          .to raise_error(ArgumentError, /Unknown model: nonexistent/)
      end

      it "raises ArgumentError for an unknown engine name" do
        expect { described_class.create_engine(:nonexistent) }
          .to raise_error(ArgumentError, /Unknown engine: nonexistent/)
      end

      it "raises ArgumentError for an unknown vocabulary name" do
        expect { described_class.create_vocabulary(:nonexistent) }
          .to raise_error(ArgumentError, /Unknown vocabulary: nonexistent/)
      end
    end

    describe ".reset!" do
      it "clears every registry" do
        described_class.reset!
        expect(described_class.models).to be_empty
        expect(described_class.engines).to be_empty
        expect(described_class.vocabularies).to be_empty
      end

      it "makes *_names return empty arrays" do
        described_class.reset!
        expect(described_class.model_names).to eq([])
        expect(described_class.engine_names).to eq([])
        expect(described_class.vocabulary_names).to eq([])
      end
    end
  end

  # ---- Search ----------------------------------------------------------

  describe Kotoshu::Embeddings::Search do
    # A real in-memory embedding "model": maps word index -> vector.
    # Not a double — it actually implements the methods Search calls.
    let(:vectors) do
      {
        0 => [1.0, 0.0, 0.0],   # "cat"   - x-axis
        1 => [0.9, 0.1, 0.0],   # "dog"   - close to cat
        2 => [0.0, 1.0, 0.0],   # "fish"  - y-axis
        3 => [0.0, 0.0, 1.0],   # "tree"  - z-axis
        4 => [0.0, 0.9, 0.1]    # "plant" - close to fish
      }
    end

    let(:vocabulary) do
      Kotoshu::Embeddings::Vocabulary.new(
        language_code: "en",
        word_to_index: { "cat" => 0, "dog" => 1, "fish" => 2, "tree" => 3, "plant" => 4 }
      )
    end

    let(:model_class) do
      Class.new do
        def initialize(vectors); @vectors = vectors; end
        def get_embedding(index); @vectors[index]; end
        def get_embeddings(indices); indices.map { |i| @vectors[i] }; end
      end
    end

    let(:model) { model_class.new(vectors) }
    let(:engine) { Kotoshu::Embeddings::SimilarityEngine.new }
    let(:search) do
      described_class.new(vocabulary: vocabulary, model: model, similarity_engine: engine)
    end

    describe "#initialize" do
      it "exposes vocabulary, model, similarity_engine, and embeddings_loaded flag" do
        expect(search.vocabulary).to eq(vocabulary)
        expect(search.model).to eq(model)
        expect(search.similarity_engine).to eq(engine)
        expect(search.embeddings_loaded).to be false
      end
    end

    describe "#find_nearest" do
      it "returns neighbors sorted by similarity descending" do
        results = search.find_nearest("cat", k: 3)
        sims = results.map { |r| r[:similarity] }
        expect(sims).to eq(sims.sort.reverse)
      end

      it "returns at most k neighbors" do
        results = search.find_nearest("cat", k: 2)
        expect(results.length).to be <= 2
      end

      it "excludes the query word by default" do
        results = search.find_nearest("cat", k: 5)
        expect(results.map { |r| r[:word] }).not_to include("cat")
      end

      it "includes the query word when exclude_self is false" do
        results = search.find_nearest("cat", k: 5, exclude_self: false)
        expect(results.map { |r| r[:word] }).to include("cat")
      end

      it "returns the most-similar word first" do
        results = search.find_nearest("cat", k: 3)
        # dog has vector [0.9, 0.1, 0.0] -> cosine with cat = 0.9938...
        expect(results.first[:word]).to eq("dog")
      end

      it "filters out neighbors below min_similarity" do
        results = search.find_nearest("cat", k: 5, min_similarity: 0.99)
        # Only "dog" is within 0.99 cosine of "cat".
        expect(results.map { |r| r[:word] }).to eq(%w[dog])
      end

      it "returns [] when the query word is not in the vocabulary" do
        expect(search.find_nearest("unknown", k: 5)).to eq([])
      end

      it "includes the vocabulary index in each result" do
        results = search.find_nearest("cat", k: 3)
        expect(results.all? { |r| r.key?(:index) }).to be true
        expect(results.find { |r| r[:word] == "dog" }[:index]).to eq(1)
      end
    end

    describe "#find_nearest_batch" do
      it "returns a per-word hash of neighbor arrays" do
        results = search.find_nearest_batch(%w[cat fish], k: 2)
        expect(results).to be_a(Hash)
        expect(results.keys).to contain_exactly("cat", "fish")
        expect(results["cat"].length).to be <= 2
      end
    end

    describe "#similarity" do
      it "returns the cosine similarity between two known words" do
        # cat and dog are very similar
        sim = search.similarity("cat", "dog")
        expect(sim).to be > 0.98
      end

      it "returns 1.0 for an identical vector" do
        expect(search.similarity("cat", "cat")).to be > 0.999
      end

      it "returns 0.0 for orthogonal vectors" do
        expect(search.similarity("cat", "fish")).to be < 0.05
      end

      it "returns nil when either word is unknown" do
        expect(search.similarity("cat", "missing")).to be_nil
        expect(search.similarity("missing", "cat")).to be_nil
      end
    end

    describe "#preload_embeddings!" do
      it "loads every embedding into the cache and flips embeddings_loaded" do
        expect(search.embeddings_loaded).to be false
        returned = search.preload_embeddings!
        expect(returned).to be(search)
        expect(search.embeddings_loaded).to be true
        expect(search.cache_size).to eq(5)
      end
    end

    describe "#clear_cache" do
      it "empties the cache and resets embeddings_loaded" do
        search.preload_embeddings!
        expect(search.clear_cache).to be(search)
        expect(search.cache_size).to eq(0)
        expect(search.embeddings_loaded).to be false
      end
    end

    describe "#to_s / #inspect" do
      it "includes vocab size and load state" do
        expect(search.to_s).to match(/ExactSearch/)
        expect(search.to_s).to match(/vocab: 5/)
        expect(search.to_s).to match(/loaded: false/)
        expect(search.inspect).to eq(search.to_s)
      end
    end

    describe Kotoshu::Embeddings::Search::MinHeap do
      it "keeps at most max_size items, sorted by similarity ascending" do
        heap = described_class.new(3)
        heap.push(similarity: 0.5)
        heap.push(similarity: 0.9)
        heap.push(similarity: 0.1)
        heap.push(similarity: 0.7)
        sims = heap.to_a.map { |i| i[:similarity] }
        # Top-3 of {0.5, 0.9, 0.1, 0.7} = {0.5, 0.9, 0.7}, kept ascending
        expect(sims.sort).to contain_exactly(0.5, 0.7, 0.9)
      end

      it "exposes size, empty?, and each" do
        heap = described_class.new(5)
        expect(heap.empty?).to be true
        heap.push(similarity: 0.1)
        heap.push(similarity: 0.2)
        expect(heap.size).to eq(2)
        collected = []
        heap.each { |i| collected << i[:similarity] }
        expect(collected).to contain_exactly(0.1, 0.2)
      end

      it "to_a returns a dup so mutations on the result don't affect the heap" do
        heap = described_class.new(5)
        heap.push(similarity: 0.1)
        snapshot = heap.to_a
        snapshot << { similarity: 99 }
        expect(heap.size).to eq(1)
      end
    end
  end

  # ---- EmbeddingPipeline ----------------------------------------------

  describe Kotoshu::Embeddings::EmbeddingPipeline do
    let(:vectors) do
      {
        0 => [1.0, 0.0],
        1 => [0.9, 0.1],
        2 => [0.0, 1.0]
      }
    end

    let(:vocabulary) do
      Kotoshu::Embeddings::Vocabulary.new(
        language_code: "en",
        word_to_index: { "apple" => 0, "pear" => 1, "sky" => 2 }
      )
    end

    # Real stub model — not a double.
    let(:model_class) do
      Class.new do
        def initialize(vectors)
          @vectors = vectors
          @loaded = false
        end

        def load!
          @loaded = true
          self
        end

        def unload!
          @loaded = false
          self
        end

        def loaded?; @loaded; end
        def ready?; @loaded; end
        def dimension; 2; end
        def language_code; "en"; end
        def model_type; "stub"; end

        def model_info
          { type: "stub", language: "en", dimension: 2, loaded: @loaded }
        end

        def get_embedding(index); @vectors[index]; end
        def get_embeddings(indices); indices.map { |i| @vectors[i] }; end

        def get_embedding_for_word(word, vocabulary)
          idx = vocabulary.lookup(word)
          return nil unless idx

          @vectors[idx]
        end
      end
    end

    let(:model) { model_class.new(vectors) }
    let(:pipeline) do
      described_class.new(vocabulary: vocabulary, model: model)
    end

    describe "#initialize" do
      it "constructs a SimilarityEngine and Search from vocabulary + model" do
        expect(pipeline.vocabulary).to eq(vocabulary)
        expect(pipeline.model).to eq(model)
        expect(pipeline.similarity_engine).to be_a(Kotoshu::Embeddings::SimilarityEngine)
        expect(pipeline.search).to be_a(Kotoshu::Embeddings::Search)
      end

      it "does not preload unless asked" do
        expect(pipeline.search.embeddings_loaded).to be false
      end

      it "preloads when preload: true is passed" do
        p = described_class.new(vocabulary: vocabulary, model: model, preload: true)
        expect(p.search.embeddings_loaded).to be true
      end
    end

    describe "#find_nearest" do
      it "delegates to the underlying search" do
        results = pipeline.find_nearest("apple", k: 2)
        expect(results.map { |r| r[:word] }).to include("pear")
      end
    end

    describe "#similarity" do
      it "delegates to the underlying search" do
        expect(pipeline.similarity("apple", "pear")).to be > 0.95
      end
    end

    describe "#include?" do
      it "checks the vocabulary" do
        expect(pipeline.include?("apple")).to be true
        expect(pipeline.include?("missing")).to be false
      end
    end

    describe "#get_embedding" do
      it "returns the model's vector for a known word" do
        expect(pipeline.get_embedding("apple")).to eq([1.0, 0.0])
      end

      it "returns nil for an unknown word" do
        expect(pipeline.get_embedding("missing")).to be_nil
      end
    end

    describe "#get_embedding_by_index" do
      it "returns the model's vector for a known index" do
        expect(pipeline.get_embedding_by_index(2)).to eq([0.0, 1.0])
      end
    end

    describe "#preload_embeddings! / #unload!" do
      it "loads the model and preloads search embeddings" do
        expect(pipeline.preload_embeddings!).to be(pipeline)
        expect(pipeline.model.loaded?).to be true
        expect(pipeline.search.embeddings_loaded).to be true
      end

      it "unload! reverses both" do
        pipeline.preload_embeddings!
        expect(pipeline.unload!).to be(pipeline)
        expect(pipeline.model.loaded?).to be false
        expect(pipeline.search.embeddings_loaded).to be false
      end
    end

    describe "#stats" do
      it "reports the documented keys" do
        stats = pipeline.stats
        expect(stats).to include(
          :language,
          :vocabulary_size,
          :embedding_dimension,
          :model_loaded,
          :embeddings_preloaded,
          :cache_stats
        )
        expect(stats[:language]).to eq("en")
        expect(stats[:vocabulary_size]).to eq(3)
        expect(stats[:embedding_dimension]).to eq(2)
      end
    end

    describe "#model_info" do
      it "delegates to the model" do
        expect(pipeline.model_info[:type]).to eq("stub")
      end
    end

    describe "#to_s / #inspect" do
      it "includes the language, vocab size, dimension, and load state" do
        s = pipeline.to_s
        expect(s).to match(/EmbeddingPipeline/)
        expect(s).to match(/language: en/)
        expect(s).to match(/vocab_size: 3/)
        expect(s).to match(/dimension: 2/)
        expect(pipeline.inspect).to eq(pipeline.to_s)
      end
    end
  end

  # ---- OnnxRuntimeModel (no-ONNX paths) --------------------------------

  describe Kotoshu::Embeddings::OnnxRuntimeModel do
    let(:tmpdir) { Dir.mktmpdir("kotoshu-onnx-spec") }

    after { FileUtils.rm_rf(tmpdir) if File.exist?(tmpdir) }

    describe "#initialize" do
      it "exposes language_code, onnx_path, dimension" do
        m = described_class.new(language_code: "en", onnx_path: "/x/m.onnx", dimension: 200)
        expect(m.language_code).to eq("en")
        expect(m.onnx_path).to eq("/x/m.onnx")
        expect(m.dimension).to eq(200)
      end

      it "defaults dimension to 300" do
        m = described_class.new(language_code: "en", onnx_path: "/x/m.onnx")
        expect(m.dimension).to eq(300)
      end

      it "starts not-loaded" do
        m = described_class.new(language_code: "en", onnx_path: "/x/m.onnx")
        expect(m.loaded?).to be false
        expect(m.ready?).to be false
      end
    end

    describe ".from_file" do
      it "raises ArgumentError when the file does not exist" do
        expect { described_class.from_file("/nonexistent/model.onnx") }
          .to raise_error(ArgumentError, /ONNX file not found/)
      end

      it "auto-detects language code from the basename (xx pattern)" do
        path = File.join(tmpdir, "fasttext.fr.onnx")
        FileUtils.touch(path)
        m = described_class.from_file(path)
        expect(m.language_code).to eq("fr")
      end

      it "defaults to 'en' when no language pattern is found in the basename" do
        path = File.join(tmpdir, "model.onnx")
        FileUtils.touch(path)
        m = described_class.from_file(path)
        expect(m.language_code).to eq("en")
      end

      it "passes through explicit language_code and dimension overrides" do
        path = File.join(tmpdir, "fasttext.fr.onnx")
        FileUtils.touch(path)
        m = described_class.from_file(path, language_code: "de", dimension: 100)
        expect(m.language_code).to eq("de")
        expect(m.dimension).to eq(100)
      end
    end

    describe "#model_info" do
      it "returns the documented shape" do
        m = described_class.new(language_code: "en", onnx_path: "/x/m.onnx", dimension: 300)
        info = m.model_info
        expect(info).to include(
          type: "onnx",
          language: "en",
          dimension: 300,
          path: "/x/m.onnx",
          loaded: false,
          inference_count: 0
        )
      end
    end

    describe "#unload!" do
      it "is a no-op when the model was never loaded, returning self" do
        m = described_class.new(language_code: "en", onnx_path: "/x/m.onnx")
        expect(m.unload!).to be(m)
        expect(m.loaded?).to be false
      end
    end

    describe "metadata methods" do
      let(:model) { described_class.new(language_code: "en", onnx_path: "/x/m.onnx") }

      it "#supports_batching? is true" do
        expect(model.supports_batching?).to be true
      end

      it "#batch_size returns the BATCH_SIZE constant" do
        expect(model.batch_size).to eq(described_class.const_get(:BATCH_SIZE))
      end

      it "#model_type returns 'onnx'" do
        expect(model.model_type).to eq("onnx")
      end

      it "#to_s includes language, dimension, and loaded state" do
        expect(model.to_s).to match(/OnnxRuntimeModel/)
        expect(model.to_s).to match(/language: en/)
        expect(model.to_s).to match(/dimension: 300/)
        expect(model.to_s).to match(/loaded: false/)
        expect(model.inspect).to eq(model.to_s)
      end
    end

    # ONNX-dependent paths: load!, get_embedding, get_embeddings,
    # preload_embeddings!, from_cache. Skipped unless ONNX_TESTS=1.
    describe "#load!", :onnx do
      it "raises OnnxUnavailable when onnxruntime is not loadable" do
        skip "onnxruntime is loaded; can't test the missing-gem path here" if Kotoshu::Models::OnnxModel::ONNX_LOADED

        m = described_class.new(language_code: "en", onnx_path: "/dev/null")
        expect { m.load! }.to raise_error(Kotoshu::Models::OnnxModel::OnnxUnavailable)
      end
    end
  end
end
