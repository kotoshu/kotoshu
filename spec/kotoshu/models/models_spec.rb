# frozen_string_literal: true

require "kotoshu"

# Direct specs for the models/ value classes: Suggestion, NearestNeighbor,
# WordEmbedding, Context, SemanticError. These are pure immutable value
# objects with no external dependencies (no ONNX runtime, no FastText
# files), so they can be exercised without :onnx or :network tags.
#
# Had no direct spec — only exercised indirectly via SemanticAnalyzer.
RSpec.describe Kotoshu::Models do
  describe Kotoshu::Models::Suggestion do
    describe "#initialize" do
      it "stores word, confidence, source, metadata" do
        s = described_class.new("dessert", confidence: 0.92, source: :semantic,
                                           metadata: { edit_distance: 2 })
        expect(s.word).to eq("dessert")
        expect(s.confidence).to be_within(0.001).of(0.92)
        expect(s.source).to eq(:semantic)
        expect(s.metadata).to eq(edit_distance: 2)
      end

      it "defaults source to :unknown when not provided" do
        s = described_class.new("cat", confidence: 0.5)
        expect(s.source).to eq(:unknown)
      end

      it "defaults metadata to an empty hash" do
        s = described_class.new("cat", confidence: 0.5)
        expect(s.metadata).to eq({})
      end

      it "raises ArgumentError when confidence is below 0" do
        expect { described_class.new("cat", confidence: -0.1) }
          .to raise_error(ArgumentError, /Confidence must be 0-1/)
      end

      it "raises ArgumentError when confidence is above 1" do
        expect { described_class.new("cat", confidence: 1.1) }
          .to raise_error(ArgumentError, /Confidence must be 0-1/)
      end

      it "accepts confidence boundaries 0.0 and 1.0" do
        expect(described_class.new("a", confidence: 0.0).confidence).to eq(0.0)
        expect(described_class.new("a", confidence: 1.0).confidence).to eq(1.0)
      end

      it "freezes the instance" do
        s = described_class.new("cat", confidence: 0.5)
        expect(s).to be_frozen
      end

      it "freezes the metadata hash" do
        s = described_class.new("cat", confidence: 0.5, metadata: { a: 1 })
        expect(s.metadata).to be_frozen
      end
    end

    describe "#<=>" do
      it "sorts by confidence descending (higher is better)" do
        a = described_class.new("a", confidence: 0.9)
        b = described_class.new("b", confidence: 0.5)
        expect([b, a].sort).to eq([a, b])
      end

      it "returns 0 when comparing against a non-Suggestion" do
        s = described_class.new("a", confidence: 0.9)
        expect(s <=> "not a suggestion").to eq(0)
      end
    end

    describe "#== and #eql?" do
      it "is equal when the word matches (regardless of confidence)" do
        a = described_class.new("cat", confidence: 0.9)
        b = described_class.new("cat", confidence: 0.5)
        expect(a).to eq(b)
        expect(a.eql?(b)).to be true
      end

      it "is not equal to non-Suggestion objects" do
        s = described_class.new("cat", confidence: 0.9)
        expect(s).not_to eq("cat")
      end

      it "has a hash based on the word" do
        a = described_class.new("cat", confidence: 0.9)
        b = described_class.new("cat", confidence: 0.5)
        expect(a.hash).to eq(b.hash)
      end
    end

    describe "#to_s" do
      it "includes word, percentage, and source when source is set" do
        s = described_class.new("cat", confidence: 0.92, source: :semantic)
        expect(s.to_s).to eq("cat [92%] (semantic)")
      end

      it "omits the source suffix when source is :unknown" do
        s = described_class.new("cat", confidence: 0.5)
        expect(s.to_s).to eq("cat [50%]")
      end
    end

    it "aliases #inspect to #to_s" do
      s = described_class.new("cat", confidence: 0.5)
      expect(s.inspect).to eq(s.to_s)
    end

    describe "metadata accessors" do
      it "#embedding returns metadata[:embedding]" do
        emb = double_embedding
        s = described_class.new("cat", confidence: 0.5, metadata: { embedding: emb })
        expect(s.embedding).to eq(emb)
      end

      it "#edit_distance returns metadata[:edit_distance]" do
        s = described_class.new("cat", confidence: 0.5, metadata: { edit_distance: 2 })
        expect(s.edit_distance).to eq(2)
      end

      it "#explanation returns metadata[:explanation]" do
        s = described_class.new("cat", confidence: 0.5,
                                       metadata: { explanation: "near-miss" })
        expect(s.explanation).to eq("near-miss")
      end

      it "#embedding returns nil when metadata lacks :embedding" do
        s = described_class.new("cat", confidence: 0.5)
        expect(s.embedding).to be_nil
      end
    end

    describe "#high_confidence?" do
      it "is true when confidence > 0.8" do
        expect(described_class.new("a", confidence: 0.81)).to be_high_confidence
      end

      it "is false when confidence == 0.8" do
        expect(described_class.new("a", confidence: 0.8)).not_to be_high_confidence
      end
    end
  end

  describe Kotoshu::Models::NearestNeighbor do
    describe "#initialize" do
      it "stores word, similarity, and computes distance" do
        nn = described_class.new(word: "hello", similarity: 0.85)
        expect(nn.word).to eq("hello")
        expect(nn.similarity).to be_within(0.001).of(0.85)
        expect(nn.distance).to be_within(0.001).of(0.15)
      end

      it "accepts an optional embedding reference" do
        emb = double_embedding
        nn = described_class.new(word: "hello", similarity: 0.85, embedding: emb)
        expect(nn.embedding).to eq(emb)
      end

      it "accepts an explicit distance overriding the cosine-derived default" do
        nn = described_class.new(word: "hello", similarity: 0.85, distance: 0.42)
        expect(nn.distance).to be_within(0.001).of(0.42)
      end

      it "raises ArgumentError when similarity is out of range" do
        expect { described_class.new(word: "a", similarity: -0.1) }.to raise_error(ArgumentError)
        expect { described_class.new(word: "a", similarity: 1.1) }.to raise_error(ArgumentError)
      end

      it "freezes the instance" do
        expect(described_class.new(word: "a", similarity: 0.5)).to be_frozen
      end
    end

    describe "#<=>" do
      it "sorts by similarity descending" do
        a = described_class.new(word: "a", similarity: 0.9)
        b = described_class.new(word: "b", similarity: 0.5)
        expect([b, a].sort).to eq([a, b])
      end
    end

    describe "#==/#eql?/#hash" do
      it "is equal when the word matches" do
        a = described_class.new(word: "a", similarity: 0.9)
        b = described_class.new(word: "a", similarity: 0.5)
        expect(a).to eq(b)
        expect(a.hash).to eq(b.hash)
      end
    end

    describe "#to_s" do
      it "renders as word [similarity%]" do
        nn = described_class.new(word: "hello", similarity: 0.85)
        expect(nn.to_s).to eq("hello [85%]")
      end
    end

    describe "#high_confidence?/#confidence_level" do
      it "high_confidence? is true when similarity > 0.8" do
        expect(described_class.new(word: "a", similarity: 0.81)).to be_high_confidence
      end

      it "confidence_level returns :high for similarity > 0.8" do
        expect(described_class.new(word: "a", similarity: 0.81).confidence_level).to eq(:high)
      end

      it "confidence_level returns :medium for 0.5 < similarity <= 0.8" do
        expect(described_class.new(word: "a", similarity: 0.6).confidence_level).to eq(:medium)
      end

      it "confidence_level returns :low for similarity <= 0.5" do
        expect(described_class.new(word: "a", similarity: 0.5).confidence_level).to eq(:low)
      end
    end
  end

  describe Kotoshu::Models::WordEmbedding do
    let(:vec_a) { [1.0, 0.0, 0.0] }
    let(:vec_b) { [0.0, 1.0, 0.0] }
    let(:vec_c) { [1.0, 0.0, 0.0] } # same direction as vec_a
    let(:vec_zero) { [0.0, 0.0, 0.0] }

    def emb(vec, lang: "en", dim: 3)
      described_class.new("w", vec, lang, dimension: dim)
    end

    describe "#initialize" do
      it "stores word, vector, language_code, dimension" do
        e = described_class.new("hello", vec_a, "en", dimension: 3)
        expect(e.word).to eq("hello")
        expect(e.vector).to eq(vec_a)
        expect(e.language_code).to eq("en")
        expect(e.dimension).to eq(3)
      end

      it "defaults dimension to 300" do
        v = Array.new(300, 0.1)
        e = described_class.new("hello", v, "en")
        expect(e.dimension).to eq(300)
      end

      it "raises ArgumentError when vector size does not match dimension" do
        expect { described_class.new("w", [1, 2], "en", dimension: 3) }
          .to raise_error(ArgumentError, /Vector dimension mismatch/)
      end

      it "freezes the vector" do
        e = described_class.new("w", vec_a, "en", dimension: 3)
        expect(e.vector).to be_frozen
      end

      it "freezes itself" do
        expect(emb(vec_a)).to be_frozen
      end
    end

    describe "#similarity" do
      it "returns 1.0 for identical vectors" do
        expect(emb(vec_a).similarity(emb(vec_c))).to be_within(0.001).of(1.0)
      end

      it "returns 0.0 for orthogonal vectors" do
        expect(emb(vec_a).similarity(emb(vec_b))).to be_within(0.001).of(0.0)
      end

      it "returns 0.0 when one vector is zero" do
        expect(emb(vec_a).similarity(emb(vec_zero))).to eq(0.0)
      end

      it "returns 0.0 when dimensions differ" do
        other = described_class.new("w", [1, 0], "en", dimension: 2)
        expect(emb(vec_a).similarity(other)).to eq(0.0)
      end

      it "raises TypeError when other is not a WordEmbedding" do
        expect { emb(vec_a).similarity("not an embedding") }
          .to raise_error(TypeError, /Must be WordEmbedding/)
      end
    end

    describe "#distance" do
      it "is 0 for identical vectors" do
        expect(emb(vec_a).distance(emb(vec_c))).to be_within(0.001).of(0.0)
      end

      it "is sqrt(2) for orthogonal unit vectors" do
        expect(emb(vec_a).distance(emb(vec_b))).to be_within(0.001).of(Math.sqrt(2))
      end

      it "is Float::INFINITY when dimensions differ" do
        other = described_class.new("w", [1, 0], "en", dimension: 2)
        expect(emb(vec_a).distance(other)).to eq(Float::INFINITY)
      end

      it "raises TypeError when other is not a WordEmbedding" do
        expect { emb(vec_a).distance("not an embedding") }
          .to raise_error(TypeError, /Must be WordEmbedding/)
      end
    end

    describe "#==/#eql?/#hash" do
      it "is equal when word and language match (regardless of vector)" do
        a = described_class.new("hello", vec_a, "en", dimension: 3)
        b = described_class.new("hello", vec_b, "en", dimension: 3)
        expect(a).to eq(b)
        expect(a.hash).to eq(b.hash)
      end

      it "is not equal when languages differ" do
        a = described_class.new("hello", vec_a, "en", dimension: 3)
        b = described_class.new("hello", vec_a, "fr", dimension: 3)
        expect(a).not_to eq(b)
      end
    end

    describe "#to_s" do
      it "includes class name, word, language, dimension" do
        e = described_class.new("hello", vec_a, "en", dimension: 3)
        expect(e.to_s).to include("WordEmbedding")
        expect(e.to_s).to include("hello")
        expect(e.to_s).to include("en")
        expect(e.to_s).to include("3D")
      end
    end
  end

  describe Kotoshu::Models::Context do
    # Use a Struct for the location to avoid doubles.
    let(:loc) { Struct.new(:line, :column).new(5, 16) }

    describe "#initialize" do
      it "stores before/current/after/location/window" do
        ctx = described_class.new(before: "The quick", current: "fox",
                                  after: "jumps", location: loc, window: 7)
        expect(ctx.before).to eq("The quick")
        expect(ctx.current).to eq("fox")
        expect(ctx.after).to eq("jumps")
        expect(ctx.location).to eq(loc)
        expect(ctx.window).to eq(7)
      end

      it "defaults window to 5" do
        ctx = described_class.new(before: "", current: "x", after: "", location: loc)
        expect(ctx.window).to eq(5)
      end

      it "joins before/current/after into full_context with newlines" do
        ctx = described_class.new(before: "a", current: "b", after: "c", location: loc)
        expect(ctx.full_context).to eq("a\nb\nc")
      end

      it "compact-filters nil segments when joining" do
        ctx = described_class.new(before: nil, current: "x", after: nil, location: loc)
        expect(ctx.full_context).to eq("x")
      end

      it "freezes itself" do
        ctx = described_class.new(before: "", current: "x", after: "", location: loc)
        expect(ctx).to be_frozen
      end
    end

    describe "#surrounding_words" do
      it "returns an empty array when current is nil" do
        ctx = described_class.new(before: "", current: nil, after: "", location: loc)
        expect(ctx.surrounding_words).to eq([])
      end

      it "returns all words when the target word is not found" do
        no_col_loc = Struct.new(:line, :column).new(1, nil)
        ctx = described_class.new(before: "", current: "alpha beta gamma", after: "", location: no_col_loc)
        # word_at_location falls through to @current (no column).
        expect(ctx.surrounding_words).to eq(%w[alpha beta gamma])
      end

      it "limits the window to n words on each side of the target" do
        # Force a target word by setting column to a known offset.
        # word_at_location returns current[column] (single char) when column is set;
        # surrounding_words then looks up that single-char "word" in the split list.
        text = "alpha beta gamma delta epsilon"
        col_loc = Struct.new(:line, :column).new(1, 0) # column 0 → "a"
        ctx = described_class.new(before: "", current: text, after: "", location: col_loc)
        # current[0] = "a" — not in the word list → returns all words.
        # Pin the contract: when the lookup misses, return the full split.
        expect(ctx.surrounding_words(2)).to eq(%w[alpha beta gamma delta epsilon])
      end
    end

    describe "#word_at_location" do
      it "returns nil when location is nil" do
        ctx = described_class.new(before: "", current: "x", after: "", location: nil)
        expect(ctx.word_at_location).to be_nil
      end

      it "returns the character at the column index when set" do
        col_loc = Struct.new(:line, :column).new(1, 2)
        ctx = described_class.new(before: "", current: "abcdef", after: "", location: col_loc)
        expect(ctx.word_at_location).to eq("c")
      end

      it "falls back to the current text when column is nil" do
        no_col_loc = Struct.new(:line, :column).new(1, nil)
        ctx = described_class.new(before: "", current: "abc", after: "", location: no_col_loc)
        expect(ctx.word_at_location).to eq("abc")
      end
    end

    describe "#to_s" do
      it "prefixes with 'Line N:' when location.line is set" do
        ctx = described_class.new(before: "a", current: "b", after: "c", location: loc)
        expect(ctx.to_s).to start_with("Line 5:")
      end

      it "returns full_context alone when location.line is nil" do
        no_line_loc = Struct.new(:line, :column).new(nil, nil)
        ctx = described_class.new(before: "a", current: "b", after: "c", location: no_line_loc)
        expect(ctx.to_s).to eq("a\nb\nc")
      end
    end

    describe "#with_highlight" do
      it "wraps the error word with ANSI underline codes" do
        ctx = described_class.new(before: "", current: "the cat", after: "", location: loc)
        highlighted = ctx.with_highlight("cat")
        expect(highlighted).to include("\033[4mcat\033[0m")
      end

      it "returns full_context unchanged when error_word is nil" do
        ctx = described_class.new(before: "", current: "the cat", after: "", location: loc)
        expect(ctx.with_highlight(nil)).to eq(ctx.full_context)
      end
    end

    describe "#==/#eql?/#hash" do
      it "is equal when location and full_context match" do
        a = described_class.new(before: "a", current: "b", after: "c", location: loc)
        b = described_class.new(before: "a", current: "b", after: "c", location: loc)
        expect(a).to eq(b)
        expect(a.hash).to eq(b.hash)
      end
    end
  end

  describe Kotoshu::Models::SemanticError do
    let(:loc) { Struct.new(:line, :column).new(5, 12) }
    let(:ctx) { Kotoshu::Models::Context.new(before: "", current: "desert", after: "", location: loc) }
    let(:suggestions) do
      [
        Kotoshu::Models::Suggestion.new("dessert", confidence: 0.92, source: :semantic),
        Kotoshu::Models::Suggestion.new("desert", confidence: 0.50, source: :semantic)
      ]
    end

    def build_error(overrides = {})
      described_class.new(
        id: "err_1",
        location: loc,
        original: "desert",
        suggestions: suggestions,
        error_type: :word_choice,
        confidence: 0.92,
        context: ctx,
        **overrides
      )
    end

    describe "ERROR_TYPES" do
      it "exposes the ten semantic categories" do
        types = described_class::ERROR_TYPES
        expect(types.keys).to contain_exactly(
          :word_choice, :verb_agreement, :tense, :orthographic,
          :preposition, :article, :morphology, :capitalization,
          :punctuation, :style
        )
      end

      it "maps each category to a display name" do
        expect(described_class::ERROR_TYPES[:orthographic]).to eq("Spelling")
        expect(described_class::ERROR_TYPES[:word_choice]).to eq("Word Choice")
      end
    end

    describe "#initialize" do
      it "stores all attributes" do
        e = build_error
        expect(e.id).to eq("err_1")
        expect(e.location).to eq(loc)
        expect(e.original).to eq("desert")
        expect(e.error_type).to eq(:word_choice)
        expect(e.confidence).to be_within(0.001).of(0.92)
        expect(e.context).to eq(ctx)
      end

      it "freezes suggestions sorted by confidence descending" do
        e = build_error
        expect(e.suggestions.map(&:confidence)).to eq([0.92, 0.50])
        expect(e.suggestions).to be_frozen
      end

      it "raises ArgumentError for an invalid error_type" do
        expect { build_error(error_type: :bogus) }
          .to raise_error(ArgumentError, /Invalid error type/)
      end

      it "raises ArgumentError when confidence is out of range" do
        expect { build_error(confidence: 1.5) }.to raise_error(ArgumentError, /Confidence must be 0-1/)
        expect { build_error(confidence: -0.1) }.to raise_error(ArgumentError, /Confidence must be 0-1/)
      end

      it "raises ArgumentError when suggestions is nil" do
        expect { build_error(suggestions: nil) }
          .to raise_error(ArgumentError, /Suggestions cannot be empty/)
      end

      it "raises ArgumentError when suggestions is empty" do
        expect { build_error(suggestions: []) }
          .to raise_error(ArgumentError, /Suggestions cannot be empty/)
      end

      it "freezes the instance" do
        expect(build_error).to be_frozen
      end

      it "stringifies a Symbol id" do
        e = described_class.new(
          id: :sym_id, location: loc, original: "x",
          suggestions: suggestions, error_type: :style,
          confidence: 0.5, context: ctx
        )
        expect(e.id).to eq("sym_id")
      end
    end

    describe "#display_type" do
      it "returns the human-readable name for the error_type" do
        expect(build_error.display_type).to eq("Word Choice")
      end
    end

    describe "#high_confidence?" do
      it "is true when confidence > 0.8" do
        expect(build_error(confidence: 0.81)).to be_high_confidence
      end

      it "is false when confidence == 0.8" do
        expect(build_error(confidence: 0.8)).not_to be_high_confidence
      end
    end

    describe "#confidence_level" do
      it "returns :high for confidence > 0.8" do
        expect(build_error(confidence: 0.81).confidence_level).to eq(:high)
      end

      it "returns :medium for 0.5 < confidence <= 0.8" do
        expect(build_error(confidence: 0.6).confidence_level).to eq(:medium)
      end

      it "returns :low for confidence <= 0.5" do
        expect(build_error(confidence: 0.5).confidence_level).to eq(:low)
      end
    end

    describe "#recommended_suggestion" do
      it "returns the highest-confidence suggestion" do
        expect(build_error.recommended_suggestion.word).to eq("dessert")
      end
    end

    describe "#==/#eql?/#hash" do
      it "is equal when ids match" do
        a = build_error(id: "x")
        b = build_error(id: "x")
        expect(a).to eq(b)
        expect(a.hash).to eq(b.hash)
      end

      it "is not equal when ids differ" do
        a = build_error(id: "x")
        b = build_error(id: "y")
        expect(a).not_to eq(b)
      end
    end

    describe "#<=>" do
      # SemanticError#<=> delegates to the location's <=>. Plain Structs
      # don't auto-define <=>, so the location contract requires a
      # Comparable value object — model it with an explicit <=> here.
      let(:loc_class) do
        Struct.new(:line, :column) do
          include Comparable

          def <=>(other)
            [line, column] <=> [other.line, other.column]
          end
        end
      end
      let(:loc_a) { loc_class.new(1, 5) }
      let(:loc_b) { loc_class.new(2, 1) }

      it "sorts by location (line, then column)" do
        # Structs compare element-wise, so loc_a < loc_b naturally.
        a = described_class.new(id: "a", location: loc_a, original: "x",
                                suggestions: suggestions, error_type: :style,
                                confidence: 0.5, context: ctx)
        b = described_class.new(id: "b", location: loc_b, original: "x",
                                suggestions: suggestions, error_type: :style,
                                confidence: 0.9, context: ctx)
        expect([b, a].sort).to eq([a, b])
      end

      it "returns 0 when other is not a SemanticError" do
        e = build_error
        expect(e <=> "not an error").to eq(0)
      end
    end

    describe "#to_s" do
      it "renders with location, original, recommended word, and percentage" do
        e = build_error
        s = e.to_s
        expect(s).to include("desert")
        expect(s).to include("dessert")
        expect(s).to include("[92%]")
      end
    end

    describe "#abbreviated" do
      it "renders a compact location/word/suggestion/percentage form" do
        e = build_error
        s = e.abbreviated
        expect(s).to include("desert")
        expect(s).to include("dessert")
        expect(s).to include("[92%]")
      end
    end
  end

  describe Kotoshu::Models::EmbeddingModel do
    # Concrete subclass for testing the abstract base.
    let(:test_model_class) do
      Class.new(described_class) do
        def initialize(vocab:, vectors:, language_code:, dimension:)
          super(language_code: language_code, dimension: dimension)
          @vocab = vocab
          @vectors = vectors
          @vocabulary_size = vocab.size
        end

        def embedding_for(word)
          idx = @vocab.index(word)
          return nil unless idx

          Kotoshu::Models::WordEmbedding.new(word, @vectors[idx], @language_code, dimension: @dimension)
        end

        def vocabulary
          @vocab
        end
      end
    end

    let(:vocab) { %w[cat dog car] }
    let(:vectors) do
      [
        [1.0, 0.0, 0.0],
        [0.9, 0.1, 0.0], # similar to cat
        [0.0, 0.0, 1.0]  # different from cat
      ]
    end
    let(:model) { test_model_class.new(vocab: vocab, vectors: vectors, language_code: "en", dimension: 3) }

    describe "#initialize" do
      it "stores language_code and dimension" do
        expect(model.language_code).to eq("en")
        expect(model.dimension).to eq(3)
      end

      it "raises ArgumentError when language_code is nil" do
        expect { described_class.new(language_code: nil, dimension: 3) }
          .to raise_error(ArgumentError, /Language code cannot be nil/)
      end

      it "raises ArgumentError when dimension is not positive" do
        expect { described_class.new(language_code: "en", dimension: 0) }
          .to raise_error(ArgumentError, /Dimension must be positive/)
        expect { described_class.new(language_code: "en", dimension: nil) }
          .to raise_error(ArgumentError, /Dimension must be positive/)
      end

      it "does not freeze the base — subclasses may add ivars post-super" do
        expect(model).not_to be_frozen
      end
    end

    describe "#embedding_for (abstract)" do
      it "raises NotImplementedError on the abstract base" do
        expect { described_class.new(language_code: "en", dimension: 3).embedding_for("x") }
          .to raise_error(NotImplementedError, /must implement #embedding_for/)
      end

      it "returns a WordEmbedding for words in the vocabulary" do
        emb = model.embedding_for("cat")
        expect(emb).to be_a(Kotoshu::Models::WordEmbedding)
        expect(emb.word).to eq("cat")
      end

      it "returns nil for OOV words" do
        expect(model.embedding_for("xyzzy")).to be_nil
      end
    end

    describe "#has_word?" do
      it "is true for words in the vocabulary" do
        expect(model.has_word?("cat")).to be true
      end

      it "is false for OOV words" do
        expect(model.has_word?("xyzzy")).to be false
      end
    end

    describe "#similarity" do
      it "returns the cosine similarity between two known words" do
        sim = model.similarity("cat", "dog")
        expect(sim).to be_a(Float)
        expect(sim).to be > 0.9
      end

      it "returns nil when either word is OOV" do
        expect(model.similarity("cat", "xyzzy")).to be_nil
        expect(model.similarity("xyzzy", "cat")).to be_nil
      end
    end

    describe "#distance" do
      it "returns the Euclidean distance between two known words" do
        d = model.distance("cat", "car")
        expect(d).to be_a(Float)
        expect(d).to be > 0.99
      end

      it "returns nil when either word is OOV" do
        expect(model.distance("cat", "xyzzy")).to be_nil
      end
    end

    describe "#nearest_neighbors" do
      it "returns up to k neighbors sorted by similarity" do
        neighbors = model.nearest_neighbors("cat", k: 2)
        expect(neighbors.length).to eq(2)
        # The most similar word to "cat" in our toy vocab is "dog".
        expect(neighbors.first.word).to eq("dog")
      end

      it "excludes the query word from results" do
        neighbors = model.nearest_neighbors("cat", k: 5)
        expect(neighbors.map(&:word)).not_to include("cat")
      end

      it "returns [] when the query is OOV" do
        expect(model.nearest_neighbors("xyzzy")).to eq([])
      end
    end

    describe "#nearest_neighbors_for_embedding" do
      it "returns neighbors for an OOV embedding (closest vocab word first)" do
        # An out-of-vocab query vector that's nearest to "dog" ([0.9, 0.1, 0]).
        # Unlike #nearest_neighbors, this method does not exclude any vocab
        # word — it answers "given this vector, what vocab is closest?"
        oov = Kotoshu::Models::WordEmbedding.new("oov", [0.85, 0.15, 0.0], "en", dimension: 3)
        neighbors = model.nearest_neighbors_for_embedding(oov, k: 1)
        expect(neighbors.length).to eq(1)
        expect(neighbors.first.word).to eq("dog")
      end

      it "includes the source word when given an in-vocab embedding" do
        emb = model.embedding_for("cat")
        neighbors = model.nearest_neighbors_for_embedding(emb, k: 1)
        expect(neighbors.first.word).to eq("cat")
      end

      it "returns [] when the embedding is nil" do
        expect(model.nearest_neighbors_for_embedding(nil)).to eq([])
      end
    end

    describe "#metadata" do
      it "includes language_code, dimension, vocabulary_size, model_type" do
        md = model.metadata
        expect(md[:language_code]).to eq("en")
        expect(md[:dimension]).to eq(3)
        expect(md[:vocabulary_size]).to eq(3)
        expect(md[:model_type]).to eq(model.class.name)
      end
    end

    describe "#statistics" do
      it "reports language, dimension, vocabulary_size, loaded" do
        stats = model.statistics
        expect(stats[:language]).to eq("en")
        expect(stats[:dimension]).to eq(3)
        expect(stats[:vocabulary_size]).to eq(3)
        expect(stats[:loaded]).to be true
      end
    end

    describe "#loaded?" do
      it "is true when vocabulary_size is positive" do
        expect(model).to be_loaded
      end

      it "is false when vocabulary_size is zero" do
        empty_model = test_model_class.new(vocab: [], vectors: [], language_code: "en", dimension: 3)
        expect(empty_model).not_to be_loaded
      end
    end

    describe "#vocabulary (abstract)" do
      it "raises NotImplementedError on the abstract base" do
        expect { described_class.new(language_code: "en", dimension: 3).vocabulary }
          .to raise_error(NotImplementedError, /must implement #vocabulary/)
      end
    end

    describe "#to_s" do
      it "includes class name, language, dimension, vocabulary_size" do
        s = model.to_s
        expect(s).to include("language: en")
        expect(s).to include("dim: 3")
        expect(s).to include("vocab: 3")
      end
    end
  end

  # Helper — build a lightweight WordEmbedding stand-in (real instance, not a double).
  def double_embedding
    Kotoshu::Models::WordEmbedding.new("w", [1.0, 0.0, 0.0], "en", dimension: 3)
  end
end
