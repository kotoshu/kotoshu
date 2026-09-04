# frozen_string_literal: true

require "json"

module Kotoshu
  # Replays the committed conformance vectors through one backend (or both)
  # and reports differences — the dual-backend suite of plan 66
  # (TODO.impl 05 P4b).
  #
  # The vectors (conformance/vectors.jsonl, exported by
  # {ConformanceExporter} and committed) freeze Ruby engine behavior. This
  # runner replays every vector through a backend and compares the actual
  # against the frozen expectation, so:
  #
  # * rake kotoshu:conformance:ruby   — the pure-Ruby engine must reproduce
  #   the vectors (guards against accidental behavior drift).
  # * rake kotoshu:conformance:native — the native engine
  #   ({NativeBackend} via a real {Spellchecker} with backend "native")
  #   must reproduce them too.
  # * rake kotoshu:conformance:compare — both engines run side by side and
  #   every row must agree: expected == ruby == native. Any difference is
  #   a backend divergence; the task exits nonzero.
  #
  # Everything here runs the real engines over the real fixture
  # dictionaries — no doubles anywhere.
  class ConformanceRunner
    # Default vectors path: the committed file at the gem repo root.
    #
    # @return [String]
    def self.default_path
      File.join(ConformanceExporter.gem_root, "conformance", "vectors.jsonl")
    end

    # One vector whose replay disagreed with its expectation (or, in a
    # {CompareResult}, with the other backend — then +expected+ is the Ruby
    # actual and +actual+ the native actual).
    Failure = Struct.new(:index, :kind, :dictionary, :input, :expected, :actual, keyword_init: true)

    # Outcome of replaying the vectors through one backend.
    RunResult = Struct.new(:backend, :row_count, :failures, :actuals, keyword_init: true) do
      def ok?
        failures.empty?
      end
    end

    # Outcome of {#compare}: both runs plus the rows where the backends
    # disagree with each other.
    CompareResult = Struct.new(:ruby, :native, :divergences, keyword_init: true) do
      def ok?
        ruby.ok? && native.ok? && divergences.empty?
      end
    end

    # @param path [String] JSONL vectors file to replay
    def initialize(path: self.class.default_path)
      @path = path
      @rows = File.readlines(path, chomp: true).map { |line| JSON.parse(line) }
    end

    # @return [Integer] vector count
    def row_count
      @rows.size
    end

    # Replay every vector through one backend, comparing against the frozen
    # expectations.
    #
    # @param backend [String, Symbol] "ruby" or "native"
    # @return [RunResult]
    # @raise [Native::Unavailable] backend "native" and the extension is
    #   not built
    def run(backend:)
      backend_name = backend.to_s
      if backend_name == "native" && !Kotoshu::Native.available?
        raise Native::Unavailable,
              "native backend requested but the extension is not built " \
              "(rake compile) — cannot run the native conformance suite"
      end

      failures = []
      engines = {}
      actuals = @rows.each_with_index.map do |row, index|
        actual = replay(engine_for(row, backend_name, engines), row)
        if actual != row["expected"]
          failures << Failure.new(index: index, kind: row["kind"], dictionary: row["dictionary"],
                                  input: row["input"], expected: row["expected"], actual: actual)
        end
        actual
      end
      RunResult.new(backend: backend_name, row_count: @rows.size, failures: failures, actuals: actuals)
    end

    # Run both backends and cross-check every row.
    #
    # @return [CompareResult]
    # @raise [Native::Unavailable] the extension is not built
    def compare
      ruby_result = run(backend: :ruby)
      native_result = run(backend: :native)

      divergences = @rows.each_index.filter_map do |index|
        ruby_actual = ruby_result.actuals[index]
        native_actual = native_result.actuals[index]
        next if ruby_actual == native_actual

        row = @rows[index]
        Failure.new(index: index, kind: row["kind"], dictionary: row["dictionary"],
                    input: row["input"], expected: ruby_actual, actual: native_actual)
      end

      CompareResult.new(ruby: ruby_result, native: native_result, divergences: divergences)
    end

    private

    # The engine for a row's dictionary, built once per dictionary.
    #
    # @param row [Hash] vector row
    # @param backend [String] "ruby" or "native"
    # @param engines [Hash] cache keyed by dictionary id
    # @return [Spellchecker, String] the engine, or an error marker for
    #   dictionaries that fail to load
    def engine_for(row, backend, engines)
      dictionary_id = row["dictionary"]
      engines[dictionary_id] ||= build_engine(dictionary_id, backend)
    end

    # Build the real engine for a dictionary id from the vectors file: a
    # real {Dictionary::Hunspell} over the fixture files, wrapped in a real
    # {Spellchecker} pinned to the requested backend (pinning overrides any
    # KOTOSHU_BACKEND env so the task measures what it names).
    #
    # @param dictionary_id [String] dictionary path relative to gem root
    # @param backend [String] "ruby" or "native"
    # @return [Spellchecker, String] the engine or a failure description
    def build_engine(dictionary_id, backend)
      base = File.join(ConformanceExporter.gem_root, dictionary_id)
      dictionary = Dictionary::Hunspell.new(
        dic_path: "#{base}.dic", aff_path: "#{base}.aff",
        language_code: ConformanceExporter::LANGUAGE
      )
      Spellchecker.new(dictionary: dictionary, config: Configuration.new(backend: backend))
    rescue StandardError => e
      "#{e.class}: #{e.message.lines.first&.strip}"
    end

    # Replay one vector through an engine.
    #
    # @param engine [Spellchecker, String] engine or load-failure marker
    # @param row [Hash] vector row
    # @return [Boolean, Array<Hash>] the actual result
    def replay(engine, row)
      return "dictionary failed to load: #{engine}" if engine.is_a?(String)

      case row["kind"]
      when "correct"
        engine.correct?(row["input"])
      when "suggest"
        engine.suggest(row["input"], max_suggestions: row["limit"])
          .map { |suggestion| suggestion_payload(suggestion) }
      else
        "unknown vector kind: #{row['kind'].inspect}"
      end
    end

    # Reduce a Suggestion to the four-key conformance payload — the same
    # selection {ConformanceExporter} applies (lutaml-model +to_hash+,
    # slice to SUGGESTION_KEYS).
    #
    # @param suggestion [Suggestions::Suggestion]
    # @return [Hash]
    def suggestion_payload(suggestion)
      suggestion.to_hash.slice(*ConformanceExporter::SUGGESTION_KEYS)
    end
  end
end
