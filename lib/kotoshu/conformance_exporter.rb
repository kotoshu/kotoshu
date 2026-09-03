# frozen_string_literal: true

require "fileutils"
require "json"

module Kotoshu
  # Exports conformance vectors for the kotoshu-rs test suite (TODO.impl plan
  # 67, M3).
  #
  # The exporter walks the Hunspell fixture corpora that live in this
  # repository, runs the REAL engine -- one real +Spellchecker+ over one real
  # +Dictionary::Hunspell+ per fixture, no mocks or stubs anywhere -- and emits
  # one JSON object per line (JSONL).
  #
  # == Row shape (v0)
  #
  # Matches kotoshu-rs' +tests/conformance/v0-placeholders.jsonl+, plus a
  # +dictionary+ key that identifies the fixture the row was produced against
  # (without it a consumer cannot reproduce the engine call):
  #
  #   {"kind":"correct","language":"en","dictionary":"spec/integrational/fixtures/base",
  #    "input":"created","expected":true}
  #   {"kind":"suggest","language":"en","dictionary":"spec/integrational/fixtures/base",
  #    "input":"hlelo","limit":5,"expected":[{"word":"hello","distance":1,
  #    "confidence":1.0,"source":"edit_distance"}]}
  #
  # +expected+ entries for +suggest+ come from the framework serialization of
  # +Suggestions::Suggestion+ (+to_hash+, provided by lutaml-model -- nothing
  # hand-rolled here), reduced to the four keys the kotoshu-rs harness parses.
  #
  # == Semantics of +expected+ -- FROZEN ENGINE BEHAVIOR
  #
  # +expected+ records what the Ruby engine ACTUALLY returns, not what the
  # Hunspell fixture says SHOULD be returned. The point of this file is
  # cross-implementation equality (kotoshu-rs must return byte-identical
  # results), not linguistic correctness. If the Ruby engine changes behavior,
  # the vectors are re-exported and both implementations move together.
  #
  # == Corpora
  #
  # * Spylls corpus: every +spec/integrational/fixtures/*.{aff,dic}+ pair;
  #   words are taken from the matching +.good+ / +.wrong+ lists using the
  #   Spylls +read_list+ conventions (strip, drop empty lines, drop lines
  #   ending in "."). Dictionaries without word lists contribute no rows.
  # * Spec fixture corpus: +spec/fixtures/dictionaries/hunspell/test.{aff,dic}+
  #   (its .dic entries plus +spec/fixtures/words.txt+).
  #
  # == Determinism
  #
  # Corpora are iterated sorted by id, words keep fixture file order (.good
  # first, then .wrong, deduplicated), hash keys are built as stable literals,
  # and no timestamps are written. Exporting twice yields byte-identical
  # output.
  #
  # == Sync contract with kotoshu-rs
  #
  # The generated file (default +conformance/vectors.jsonl+ at the gem repo
  # root) IS committed to this repository -- conformance/ is deliberately NOT
  # gitignored. kotoshu-rs copies it into +tests/conformance/+ via its own
  # documented sync step, so its CI consumes the vectors without the gem.
  class ConformanceExporter
    # Fixed suggestion limit used for every "suggest" vector.
    SUGGEST_LIMIT = 5

    # Language recorded in every row (the engine language_code the exporter
    # passes when loading fixture dictionaries, mirroring SpyllsTestHelper).
    LANGUAGE = "en"

    # Corpus ids excluded from the default export.
    #
    # "timelimit" is Hunspell's exponential-compounding torture test
    # (COMPOUNDMIN 1 over runs of zeros): +correct?+ survives it, but
    # +suggest+ never terminates in the Ruby engine, so no vector can be
    # frozen. The fixture stays covered by spec/integrational/lookup_spec.rb.
    EXCLUDED_FIXTURES = ["spec/integrational/fixtures/timelimit"].freeze

    # Keys kept from Suggestions::Suggestion#to_hash (lutaml-model
    # serialization) in "suggest" expected payloads. Mirrors the
    # kotoshu-rs v0 placeholder schema; "metadata" is dropped.
    SUGGESTION_KEYS = %w[word distance confidence source].freeze

    # One fixture dictionary plus the words to run against it.
    Corpus = Struct.new(:id, :aff_path, :dic_path, :words, keyword_init: true)

    # Outcome of an export run.
    ExportResult = Struct.new(:path, :row_count, :corpus_count, :skipped_corpora, :skipped_words,
                              keyword_init: true)

    class << self
      # Root of the gem repository (this file lives in lib/kotoshu/).
      #
      # @return [String] Absolute path to the repo root
      def gem_root
        File.expand_path("../..", __dir__)
      end

      # Default corpora: the Spylls fixtures plus the spec fixture corpus.
      #
      # Applies EXCLUDED_FIXTURES and drops corpora with no words, so the
      # export is stable regardless of which auxiliary dictionaries happen to
      # sit in the fixture directory.
      #
      # @param gem_root [String] Repo root to resolve fixture paths against
      # @return [Array<Corpus>] Corpora sorted by id
      def default_corpora(gem_root: self.gem_root)
        spylls_corpora(gem_root: gem_root) + [spec_fixture_corpus(gem_root: gem_root)]
      end

      # Scan the Spylls fixture directory for Hunspell dictionaries.
      #
      # @param gem_root [String] Repo root
      # @return [Array<Corpus>] Non-excluded corpora with at least one word,
      #   sorted by id
      def spylls_corpora(gem_root: self.gem_root)
        dir = File.join(gem_root, "spec/integrational/fixtures")
        Dir.glob(File.join(dir, "*.dic")).filter_map do |dic_path|
          base = dic_path.delete_suffix(".dic")
          id = "spec/integrational/fixtures/#{File.basename(base)}"
          next if EXCLUDED_FIXTURES.include?(id)

          words = (read_word_list("#{base}.good") + read_word_list("#{base}.wrong")).uniq
          next if words.empty?

          Corpus.new(id: id, aff_path: "#{base}.aff", dic_path: dic_path, words: words)
        end
      end

      # The spec fixture corpus: the small Hunspell test dictionary shipped
      # under spec/fixtures, fed its own .dic entries plus words.txt.
      #
      # @param gem_root [String] Repo root
      # @return [Corpus]
      def spec_fixture_corpus(gem_root: self.gem_root)
        base = File.join(gem_root, "spec/fixtures/dictionaries/hunspell/test")
        words = (dic_headwords("#{base}.dic") + read_word_list(File.join(gem_root, "spec/fixtures/words.txt"))).uniq
        Corpus.new(id: "spec/fixtures/dictionaries/hunspell/test",
                   aff_path: "#{base}.aff", dic_path: "#{base}.dic", words: words)
      end

      # Read a Spylls word list (.good / .wrong / plain list), mirroring
      # SpyllsTestHelper#read_list: strip lines, drop empty lines and lines
      # ending in ".".
      #
      # @param path [String] List file path
      # @return [Array<String>] Words in file order
      def read_word_list(path)
        return [] unless File.file?(path)

        File.read(path, encoding: "UTF-8").split("\n").filter_map do |line|
          word = line.strip
          next if word.empty?
          next if word.end_with?(".")

          word
        end
      end

      # Extract headwords from a Hunspell .dic file: skip the count line,
      # comments and morphological continuation lines; strip affix flags.
      #
      # @param dic_path [String] .dic file path
      # @return [Array<String>] Headwords in file order
      def dic_headwords(dic_path)
        File.read(dic_path, encoding: "UTF-8").split("\n").filter_map do |line|
          entry = line.strip
          next if entry.empty?
          next if entry.start_with?("#")
          next if entry.match?(/\A\d+\z/)

          entry.split("/", 2).first
        end
      end

      # Export the default corpora to a JSONL file.
      #
      # @param path [String] Destination file path (directories are created)
      # @param corpora [Array<Corpus>] Corpora to export
      # @return [ExportResult] Row/corpus counts and anything skipped
      def export(path:, corpora: default_corpora)
        new(corpora).export(path)
      end
    end

    # @param corpora [Array<Corpus>] Corpora to export (sorted by id)
    def initialize(corpora)
      @corpora = corpora.sort_by(&:id)
      @skipped_corpora = {}
      @skipped_words = {}
    end

    # Build every vector row, deterministically ordered.
    #
    # @return [Array<Hash>] Rows in corpus-id then fixture-word order
    def rows
      @corpora.each_with_object([]) do |corpus, acc|
        checker = spellchecker_for(corpus)
        next unless checker

        corpus.words.each do |word|
          unless word.dup.force_encoding(Encoding::UTF_8).valid_encoding?
            @skipped_words[[corpus.id, word]] = "not valid UTF-8"
            next
          end

          acc << { kind: "correct", language: LANGUAGE, dictionary: corpus.id,
                   input: word, expected: checker.correct?(word) }
          acc << { kind: "suggest", language: LANGUAGE, dictionary: corpus.id,
                   input: word, limit: SUGGEST_LIMIT,
                   expected: checker.suggest(word, max_suggestions: SUGGEST_LIMIT)
                     .map { |suggestion| suggestion_payload(suggestion) } }
        end
      end
    end

    # Build the rows and write them as JSONL to +path+.
    #
    # @param path [String] Destination file path (directories are created)
    # @return [ExportResult] Row/corpus counts and anything skipped
    def export(path)
      all_rows = rows
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, all_rows.map { |row| JSON.generate(row) }.join("\n") << "\n")

      ExportResult.new(path: path, row_count: all_rows.size,
                       corpus_count: @corpora.size - @skipped_corpora.size,
                       skipped_corpora: @skipped_corpora, skipped_words: @skipped_words)
    end

    private

    # Build the real engine for a corpus: a real Hunspell dictionary wrapped
    # in a real Spellchecker. Corpus load failures are recorded and skipped
    # rather than aborting the whole export.
    #
    # @param corpus [Corpus]
    # @return [Spellchecker, nil] nil when the fixture fails to load
    def spellchecker_for(corpus)
      dictionary = Dictionary::Hunspell.new(dic_path: corpus.dic_path, aff_path: corpus.aff_path,
                                            language_code: LANGUAGE)
      Spellchecker.new(dictionary: dictionary)
    rescue StandardError => e
      @skipped_corpora[corpus.id] = "#{e.class}: #{e.message.lines.first&.strip}"
      nil
    end

    # Reduce a Suggestions::Suggestion to the four-key payload the conformance
    # vectors carry. Serialization itself is the framework's (lutaml-model
    # +to_hash+); this only selects keys from its output.
    #
    # @param suggestion [Suggestions::Suggestion]
    # @return [Hash] "word"/"distance"/"confidence"/"source" hash
    def suggestion_payload(suggestion)
      suggestion.to_hash.slice(*SUGGESTION_KEYS)
    end
  end
end
