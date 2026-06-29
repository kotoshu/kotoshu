# frozen_string_literal: true

require "kotoshu"

# Trigger autoload of the grammar namespace.
Kotoshu::Grammar::RuleEngine

# Direct spec for the grammar/ namespace: Rule, RuleEngine, RuleLoader,
# PatternMatchers::{BaseMatcher,VowelSoundMatcher,PossessiveContextMatcher,
# DoubleNegativeMatcher}.
#
# These are exercised indirectly via spec/kotoshu/languages/en/grammar_rules_spec.rb,
# but had no direct spec. This file pins the public contract of each class
# using in-memory Rule instances built from YAML-shape hashes — no fixture
# file IO, no language coupling.
RSpec.describe Kotoshu::Grammar do
  # ---- helpers -----------------------------------------------------------

  def build_rule(overrides = {})
    config = {
      "id" => "TEST_RULE",
      "name" => "test rule",
      "category" => "test",
      "severity" => "suggestion",
      "description" => "for testing",
      "patterns" => [],
      "exceptions" => {},
      "message" => "test message",
      "suggestion" => nil
    }.merge(overrides)
    Kotoshu::Grammar::Rule.from_yaml(config)
  end

  def vowel_rule
    build_rule(
      "id" => "A_VS_AN",
      "patterns" => [{
        "conditions" => [{ "type" => "vowel_check" }]
      }],
      "exceptions" => {
        "consonant_sound_exceptions" => %w[unicorn one],
        "silent_consonant_exceptions" => %w[hour]
      },
      "message" => 'Use "{expected}" before "{word}"'
    )
  end

  def there_their_rule
    build_rule(
      "id" => "THERE_THEIR",
      "patterns" => [{
        "conditions" => [{ "type" => "context_check" }]
      }],
      "exceptions" => {
        "location_indicators" => {
          "verbs" => %w[is are was were goes went be been being exist exists],
          "possessive_nouns" => %w[car dog house]
        }
      },
      "message" => 'Did you mean "their"?',
      "suggestion" => "their"
    )
  end

  def double_negative_rule(max_distance: 15)
    build_rule(
      "id" => "DOUBLE_NEG",
      "patterns" => [{
        "conditions" => [
          { "type" => "distance_check", "max_distance" => max_distance }
        ]
      }],
      "exceptions" => {
        "phrases" => ["not only...but also"]
      },
      "message" => "Avoid double negatives",
      "suggestion" => "rewrite"
    )
  end

  # Single-pattern hash for constructing matchers directly. Each matcher
  # is instantiated as `Matcher.new(pattern_hash, exceptions_hash)` — the
  # same way Rule#create_matcher does it internally.
  def vowel_pattern
    { "conditions" => [{ "type" => "vowel_check" }] }
  end

  def vowel_exceptions
    {
      "consonant_sound_exceptions" => %w[unicorn one],
      "silent_consonant_exceptions" => %w[hour]
    }
  end

  def possessive_pattern
    { "conditions" => [{ "type" => "context_check" }] }
  end

  def possessive_exceptions
    {
      "location_indicators" => {
        "verbs" => %w[is are was were goes went be been being exist exists],
        "possessive_nouns" => %w[car dog house]
      }
    }
  end

  def double_negative_pattern(max_distance: 15)
    { "conditions" => [{ "type" => "distance_check",
                         "max_distance" => max_distance }] }
  end

  def double_negative_exceptions
    { "phrases" => ["not only...but also"] }
  end

  def tok(word, position: 0, pos_tag: nil, length: word.length)
    { token: word, position: position, pos_tag: pos_tag, length: length }
  end

  # ---- Rule --------------------------------------------------------------

  describe Kotoshu::Grammar::Rule do
    describe ".from_yaml" do
      it "builds a Rule from a YAML-shaped config hash" do
        rule = described_class.from_yaml(
          "id" => "X", "name" => "n", "category" => "c", "severity" => "s",
          "description" => "d", "patterns" => [], "message" => "m",
          "suggestion" => "fix", "exceptions" => { "foo" => ["bar"] }
        )
        expect(rule.id).to eq("X")
        expect(rule.name).to eq("n")
        expect(rule.category).to eq("c")
        expect(rule.severity).to eq("s")
        expect(rule.description).to eq("d")
        expect(rule.message).to eq("m")
        expect(rule.suggestion).to eq("fix")
        expect(rule.exceptions).to eq("foo" => ["bar"])
      end

      it "defaults exceptions to {} when not provided" do
        rule = described_class.from_yaml(
          "id" => "X", "name" => "n", "category" => "c", "severity" => "s",
          "description" => "d", "patterns" => [], "message" => "m",
          "suggestion" => nil
        )
        expect(rule.exceptions).to eq({})
      end
    end

    describe "#check" do
      it "returns an empty array when there are no patterns" do
        rule = build_rule("patterns" => [])
        expect(rule.check([tok("hello")])).to eq([])
      end

      it "aggregates errors from every pattern" do
        rule = build_rule(
          "id" => "R",
          "patterns" => [
            { "conditions" => [{ "type" => "vowel_check" }] },
            { "conditions" => [{ "type" => "vowel_check" }] }
          ],
          "exceptions" => { "consonant_sound_exceptions" => [],
                            "silent_consonant_exceptions" => [] },
          "message" => 'Use "{expected}" before "{word}"'
        )
        tokens = [tok("a", pos_tag: "DET"), tok("elephant", pos_tag: "NOUN")]
        errors = rule.check(tokens)
        # Both patterns fire on the same "a elephant" → 2 errors.
        expect(errors.length).to eq(2)
        expect(errors).to all(include(rule_id: "R", suggestion: "an"))
      end

      it "selects the matcher based on condition type" do
        # The same shape, but different condition types must produce different
        # matcher classes (verified by behavior, not internals).
        vowel_rule = build_rule(
          "id" => "V",
          "patterns" => [{ "conditions" => [{ "type" => "vowel_check" }] }],
          "exceptions" => { "consonant_sound_exceptions" => [],
                            "silent_consonant_exceptions" => [] },
          "message" => 'Use "{expected}" before "{word}"'
        )
        possessive_rule = build_rule(
          "id" => "P",
          "patterns" => [{ "conditions" => [{ "type" => "context_check" }] }],
          "exceptions" => { "location_indicators" => {
            "verbs" => [], "possessive_nouns" => %w[dog]
          } },
          "message" => "use their", "suggestion" => "their"
        )
        double_neg_rule = build_rule(
          "id" => "D",
          "patterns" => [{ "conditions" => [{ "type" => "distance_check",
                                              "max_distance" => 10 }] }],
          "exceptions" => { "phrases" => [] },
          "message" => "double neg", "suggestion" => "rewrite"
        )
        # Each rule fires only on its target shape.
        expect(vowel_rule.check([tok("a", pos_tag: "DET"),
                                 tok("elephant")]).length).to eq(1)
        expect(possessive_rule.check([tok("there"),
                                      tok("dog")]).length).to eq(1)
        expect(double_neg_rule.check([tok("not", position: 0),
                                      tok("never", position: 5)]).length).to eq(1)
      end

      it "falls back to BaseMatcher for an unknown condition type" do
        rule = build_rule(
          "id" => "U",
          "patterns" => [{ "conditions" => [{ "type" => "totally_unknown" }] }]
        )
        expect(rule.check([tok("anything")])).to eq([])
      end

      it "uses BaseMatcher when conditions is empty" do
        rule = build_rule(
          "id" => "B",
          "patterns" => [{ "conditions" => [] }]
        )
        expect(rule.check([tok("anything")])).to eq([])
      end
    end
  end

  # ---- PatternMatchers::BaseMatcher --------------------------------------

  describe Kotoshu::Grammar::PatternMatchers::BaseMatcher do
    describe "#match" do
      it "returns an empty array by default (subclass responsibility)" do
        matcher = described_class.new({})
        expect(matcher.match([tok("x")], build_rule)).to eq([])
      end
    end

    describe "#extract_tokens_from_context (protected)" do
      it "is exposed for subclass reuse" do
        # Subclass using the helper to filter target tokens.
        klass = Class.new(described_class) do
          def filter(tokens, target)
            extract_tokens_from_context(tokens, [{ "target_token" => target }])
          end
        end
        matcher = klass.new({})
        tokens = [tok("foo"), tok("bar"), tok("foo")]
        result = matcher.filter(tokens, "foo")
        expect(result.length).to eq(2)
        expect(result.dig(0, :token, :token)).to eq("foo")
        expect(result.dig(0, :index)).to eq(0)
        expect(result.dig(1, :index)).to eq(2)
      end

      it "matches case-insensitively" do
        klass = Class.new(described_class) do
          def filter(tokens, target)
            extract_tokens_from_context(tokens, [{ "target_token" => target }])
          end
        end
        matcher = klass.new({})
        tokens = [tok("Foo"), tok("FOO")]
        expect(matcher.filter(tokens, "foo").length).to eq(2)
      end
    end
  end

  # ---- VowelSoundMatcher -------------------------------------------------

  describe Kotoshu::Grammar::PatternMatchers::VowelSoundMatcher do
    let(:rule) { vowel_rule }

    def matcher
      described_class.new(vowel_pattern, vowel_exceptions)
    end

    it 'flags "a" before a vowel-initial word' do
      tokens = [tok("a", pos_tag: "DET"), tok("elephant", pos_tag: "NOUN")]
      errors = matcher.match(tokens, rule)
      expect(errors.length).to eq(1)
      expect(errors.first[:suggestion]).to eq("an")
      expect(errors.first[:rule_id]).to eq("A_VS_AN")
      expect(errors.first[:message]).to include("Use \"an\" before \"elephant\"")
    end

    it 'flags "an" before a consonant-initial word' do
      tokens = [tok("an", pos_tag: "DET"), tok("dog", pos_tag: "NOUN")]
      errors = matcher.match(tokens, rule)
      expect(errors.length).to eq(1)
      expect(errors.first[:suggestion]).to eq("a")
    end

    it "passes through correct usage" do
      expect(matcher.match([tok("a", pos_tag: "DET"), tok("dog")], rule)).to eq([])
      expect(matcher.match([tok("an", pos_tag: "DET"), tok("elephant")], rule)).to eq([])
    end

    it "respects consonant-sound exceptions (uses 'a' before 'unicorn')" do
      # 'unicorn' starts with a vowel letter but a consonant sound.
      expect(matcher.match([tok("a", pos_tag: "DET"), tok("unicorn")], rule)).to eq([])
      errors = matcher.match([tok("an", pos_tag: "DET"), tok("unicorn")], rule)
      expect(errors.first[:suggestion]).to eq("a")
    end

    it "respects silent-consonant exceptions (uses 'an' before 'hour')" do
      # 'hour' starts with a consonant letter but a vowel sound.
      expect(matcher.match([tok("an", pos_tag: "DET"), tok("hour")], rule)).to eq([])
      errors = matcher.match([tok("a", pos_tag: "DET"), tok("hour")], rule)
      expect(errors.first[:suggestion]).to eq("an")
    end

    it "ignores the article when its pos_tag is non-DET and non-nil" do
      tokens = [tok("a", pos_tag: "NOUN"), tok("elephant")]
      expect(matcher.match(tokens, rule)).to eq([])
    end

    it "ignores empty/nil next-word tokens" do
      tokens = [tok("a", pos_tag: "DET"), tok("")]
      expect(matcher.match(tokens, rule)).to eq([])
    end

    it 'flags multiple "a elephant" pairs in the same stream' do
      tokens = [
        tok("a", pos_tag: "DET", position: 0),  tok("elephant", position: 2),
        tok("a", pos_tag: "DET", position: 11), tok("apple",    position: 13)
      ]
      errors = matcher.match(tokens, rule)
      expect(errors.length).to eq(2)
    end

    it "interpolates {expected} and {word} into the rule message" do
      tokens = [tok("a", pos_tag: "DET"), tok("elephant")]
      error = matcher.match(tokens, rule).first
      expect(error[:message]).to eq('Use "an" before "elephant"')
    end
  end

  # ---- PossessiveContextMatcher ------------------------------------------

  describe Kotoshu::Grammar::PatternMatchers::PossessiveContextMatcher do
    let(:rule) { there_their_rule }

    def matcher
      described_class.new(possessive_pattern, possessive_exceptions)
    end

    it 'flags "there" + possessive-noun-list word (word-list fallback)' do
      tokens = [tok("there"), tok("dog")]
      errors = matcher.match(tokens, rule)
      expect(errors.length).to eq(1)
      expect(errors.first[:suggestion]).to eq("their")
    end

    it 'flags "there" + NOUN pos-tag' do
      tokens = [tok("there"), tok("dog", pos_tag: "NOUN")]
      expect(matcher.match(tokens, rule).length).to eq(1)
    end

    it 'flags "there" + NOUN_PROPER pos-tag' do
      tokens = [tok("there"), tok("Dog", pos_tag: "NOUN_PROPER")]
      expect(matcher.match(tokens, rule).length).to eq(1)
    end

    it 'flags "there" + ADJ pos-tag' do
      tokens = [tok("there"), tok("big", pos_tag: "ADJ")]
      expect(matcher.match(tokens, rule).length).to eq(1)
    end

    it 'does NOT flag "there" + verb (location context)' do
      tokens = [tok("there"), tok("is", pos_tag: "VERB")]
      expect(matcher.match(tokens, rule)).to eq([])
    end

    it "does not flag when 'there' is the last token" do
      expect(matcher.match([tok("there")], rule)).to eq([])
    end

    it "matches 'there' case-insensitively" do
      tokens = [tok("There"), tok("dog")]
      expect(matcher.match(tokens, rule).length).to eq(1)
    end

    it "reports the rule's suggestion and message verbatim" do
      tokens = [tok("there"), tok("dog")]
      error = matcher.match(tokens, rule).first
      expect(error[:message]).to eq('Did you mean "their"?')
      expect(error[:suggestion]).to eq("their")
      expect(error[:suggestions]).to eq(["their"])
    end
  end

  # ---- DoubleNegativeMatcher ---------------------------------------------

  describe Kotoshu::Grammar::PatternMatchers::DoubleNegativeMatcher do
    let(:rule) { double_negative_rule(max_distance: 10) }

    def matcher
      described_class.new(double_negative_pattern(max_distance: 10),
                          double_negative_exceptions)
    end

    it "flags two negatives within the max-distance window" do
      tokens = [tok("not", position: 0), tok("never", position: 5)]
      errors = matcher.match(tokens, rule)
      expect(errors.length).to eq(1)
      expect(errors.first[:suggestion]).to eq("rewrite")
    end

    it "does not flag two negatives outside the window" do
      tokens = [tok("not", position: 0), tok("never", position: 20)]
      expect(matcher.match(tokens, rule)).to eq([])
    end

    it 'flags contractions ending in "n\'t"' do
      tokens = [tok("didn't", position: 0), tok("never", position: 7)]
      expect(matcher.match(tokens, rule).length).to eq(1)
    end

    it "recognizes the full negative word list" do
      %w[not no neither nobody never nothing nowhere hardly barely scarcely].each do |w|
        tokens = [tok(w, position: 0), tok("nothing", position: 5)]
        expect(matcher.match(tokens, rule).length).to eq(1),
                                                      "expected #{w.inspect} to count as a negative"
      end
    end

    it "skips negatives that sit between 'not' and 'only'" do
      # The exception check is `tokens[idx-1] == 'not' && tokens[idx+1] == 'only'`,
      # which fires on the shape `not [current_negative] only`. This is a
      # narrow shape (the real "not only... but also" idiom has 'not' and
      # 'only' adjacent), but it's what the matcher implements. Pin the
      # current behavior here; fixing the exception check is follow-up.
      tokens = [
        tok("not", position: 0),
        tok("never", position: 4),
        tok("only", position: 11)
      ]
      # 'never' (idx 1) is between 'not' and 'only' → exception fires,
      # 'never' is not added to negative_indices. Only 'not' (idx 0)
      # remains — no pairs → 0 errors.
      expect(matcher.match(tokens, rule)).to eq([])
    end

    it "aggregates multiple negative pairs" do
      tokens = [
        tok("not", position: 0),
        tok("never", position: 4),
        tok("nothing", position: 11)
      ]
      errors = matcher.match(tokens, rule)
      # (not, never) + (never, nothing) → 2 errors.
      expect(errors.length).to eq(2)
    end

    it "ignores empty/nil words" do
      tokens = [tok("", position: 0), tok("not", position: 1)]
      expect(matcher.match(tokens, rule)).to eq([])
    end

    it "uses the rule's message and suggestion verbatim" do
      tokens = [tok("not", position: 0), tok("never", position: 4)]
      error = matcher.match(tokens, rule).first
      expect(error[:message]).to eq("Avoid double negatives")
      expect(error[:suggestions]).to eq(["rewrite"])
    end
  end

  # ---- RuleLoader --------------------------------------------------------

  describe Kotoshu::Grammar::RuleLoader do
    def write_rules(dir, rules_yaml)
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "rules.yaml"), rules_yaml)
    end

    after do
      # Clean up the tmp dir we wrote to (per-test isolation).
      @tmpdir&.then { |d| FileUtils.rm_rf(d) if File.exist?(d) }
    end

    let(:tmpdir) do
      require "tmpdir"
      @tmpdir = Dir.mktmpdir("kotoshu-grammar-spec")
      @tmpdir
    end

    it "loads rules from rules.yaml" do
      dir = tmpdir
      write_rules(dir, <<~YAML)
        rules:
          - id: A
            name: "a"
            category: cat
            severity: warning
            description: d
            patterns: []
            message: m
            suggestion: s
          - id: B
            name: "b"
            category: cat
            severity: warning
            description: d
            patterns: []
            message: m
            suggestion: s
      YAML
      loader = described_class.new(dir)
      rules = loader.load_rules
      expect(rules.length).to eq(2)
      expect(rules.map(&:id)).to eq(%w[A B])
    end

    it "returns [] when rules.yaml does not exist" do
      loader = described_class.new(tmpdir)
      expect(loader.load_rules).to eq([])
    end

    it "returns [] when rules.yaml is empty" do
      dir = tmpdir
      write_rules(dir, "")
      expect(described_class.new(dir).load_rules).to eq([])
    end

    it "returns [] when rules.yaml has no 'rules' key" do
      dir = tmpdir
      write_rules(dir, "metadata:\n  language: en\n")
      expect(described_class.new(dir).load_rules).to eq([])
    end

    it "returns [] when rules.yaml has a null rules value" do
      dir = tmpdir
      write_rules(dir, "rules:\n")
      expect(described_class.new(dir).load_rules).to eq([])
    end

    it "defaults exceptions to {} when not present in a rule config" do
      dir = tmpdir
      write_rules(dir, <<~YAML)
        rules:
          - id: A
            name: "a"
            category: cat
            severity: warning
            description: d
            patterns: []
            message: m
            suggestion: s
      YAML
      rule = described_class.new(dir).load_rules.first
      expect(rule.exceptions).to eq({})
    end
  end

  # ---- RuleEngine --------------------------------------------------------

  describe Kotoshu::Grammar::RuleEngine do
    # We point the engine at a tmpdir containing our own test rules.yaml,
    # so the engine tests don't depend on the production data/grammar files.
    let(:rules_dir) do
      require "tmpdir"
      dir = Dir.mktmpdir("kotoshu-engine-spec")
      File.write(File.join(dir, "rules.yaml"), <<~YAML)
        rules:
          - id: T_A_AN
            name: "a vs an"
            category: articles
            severity: suggestion
            description: d
            patterns:
              - conditions:
                  - type: vowel_check
            exceptions:
              consonant_sound_exceptions: []
              silent_consonant_exceptions: []
            message: 'Use "{expected}" before "{word}"'
            suggestion: null
      YAML
      dir
    end
    let(:engine) { described_class.new(language: "xx", rules_path: rules_dir) }

    after { FileUtils.rm_rf(rules_dir) if File.exist?(rules_dir) }

    describe "#initialize" do
      it "loads rules eagerly from rules_path" do
        expect(engine.rules.length).to eq(1)
        expect(engine.rules.first.id).to eq("T_A_AN")
      end

      it "exposes the language code" do
        expect(engine.language).to eq("xx")
      end
    end

    describe "#check" do
      it "runs every loaded rule and aggregates errors" do
        tokens = [tok("a", pos_tag: "DET"), tok("elephant", pos_tag: "NOUN")]
        errors = engine.check(tokens)
        expect(errors.length).to eq(1)
        expect(errors.first[:rule_id]).to eq("T_A_AN")
        expect(errors.first[:suggestion]).to eq("an")
      end

      it "returns [] when no rules fire" do
        tokens = [tok("a", pos_tag: "DET"), tok("dog", pos_tag: "NOUN")]
        expect(engine.check(tokens)).to eq([])
      end
    end

    describe "#rule_names" do
      it "returns the list of rule ids" do
        expect(engine.rule_names).to eq(%w[T_A_AN])
      end
    end

    describe "#get_rule" do
      it "returns the rule with the given id" do
        expect(engine.get_rule("T_A_AN").id).to eq("T_A_AN")
      end

      it "returns nil for an unknown id" do
        expect(engine.get_rule("NOPE")).to be_nil
      end
    end

    describe "#rule_exists?" do
      it "is true for a loaded rule" do
        expect(engine.rule_exists?("T_A_AN")).to be true
      end

      it "is false for an unknown rule" do
        expect(engine.rule_exists?("NOPE")).to be false
      end
    end

    describe "rules_path resolution" do
      it "joins dictionaries_base/<language>/grammar when no rules_path is given" do
        # Use a dictionaries_path that doesn't exist; engine should still
        # construct (and just load zero rules).
        base = Dir.mktmpdir("kotoshu-base")
        begin
          engine = described_class.new(language: "yy",
                                       dictionaries_path: base)
          expect(engine.rules).to eq([])
          expect(engine.language).to eq("yy")
        ensure
          FileUtils.rm_rf(base)
        end
      end
    end
  end
end
