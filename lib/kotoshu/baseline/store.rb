# frozen_string_literal: true

require "lutaml/model"
require "set"

module Kotoshu
  module Baseline
    # A baseline file: canonical JSON `{version, entries: [{file,
    # line, word, count}]}`. Serialized via lutaml-model.
    #
    # Semantics when applied to a check result (plan 82):
    # - an error passes when the baseline has budget left for it
    #   (same file + word, occurrence count not exceeded);
    # - errors beyond the budget, and unknown words, fail;
    # - a summary reports how many entries are stale (the file no
    #   longer has the error), so debt shrinks visibly.
    class Store < Lutaml::Model::Serializable
      DEFAULT_FILENAME = ".kotoshu-baseline.json"
      CURRENT_VERSION = 1

      attribute :version, :integer, default: CURRENT_VERSION
      attribute :entries, Entry, collection: true

      # Accept framework-private keywords from lutaml-model.
      def initialize(version: CURRENT_VERSION, entries: [], **kwargs)
        super
      end

      class << self
        # Read and parse a baseline file.
        #
        # @param path [String]
        # @return [Store]
        # @raise [Errno::ENOENT, Lutaml::Model::InvalidValueError] when
        #   missing or malformed — callers translate to usage errors
        def load(path)
          from_json(File.read(path))
        end

        # Build a Store from check results. +checks+ maps each checked
        # file path to a `[DocumentResult, source_text]` pair (the
        # text supplies line numbers). Entries are canonicalized: one
        # row per (file, word), count = occurrences, line = line of
        # the first occurrence, rows sorted by (file, word).
        #
        # @param checks [Hash<String => Array(Models::Result::DocumentResult, String)>]
        # @return [Store]
        def from_checks(checks)
          entries = checks.flat_map do |file, (result, text)|
            result.errors.group_by(&:word).map do |word, word_errors|
              first = word_errors.min_by { |e| e.position || 0 }
              Entry.new(
                file: file,
                line: Documents::SourcePosition.line_for_offset(text || "", first.position || 0),
                word: word,
                count: word_errors.size
              )
            end
          end
          new(entries: canonical_entries(entries))
        end

        # Collapse entries to one row per (file, word) with summed
        # counts, in canonical order.
        def canonical_entries(entries)
          entries.group_by(&:key).map do |(file, word), group|
            first_line = group.map(&:line).compact.min || 1
            Entry.new(file: file, line: first_line, word: word,
                      count: group.sum(&:count))
          end.sort_by { |e| [e.file.to_s, e.word.to_s] }
        end
      end

      # Write the baseline to +path+ (pretty JSON).
      #
      # @return [self]
      def save(path)
        File.write(path, to_json)
        self
      end

      # Entries recorded for +file+.
      def entries_for(file)
        entries.select { |entry| entry.file == file }
      end

      # Apply the baseline to +result+ (checked +file+): errors with
      # baseline budget pass (moved to `suppressed_errors`, marked
      # `suppressed_by: "baseline"`); the rest keep failing.
      # Inline-suppressed errors were already filtered upstream and
      # do not consume baseline budget.
      #
      # @param result [Models::Result::DocumentResult]
      # @param file [String] path the result was checked against
      # @return [Application]
      def apply(result, file:)
        budget = Hash.new(0)
        entries_for(file).each { |entry| budget[entry.word] += entry.count }

        occurrences = Hash.new { |hash, key| hash[key] = [] }
        result.errors.each { |error| occurrences[error.word] << error }

        absorbed = []
        occurrences.each_value do |word_errors|
          remaining = budget[word_errors.first.word]
          next if remaining <= 0

          in_order = word_errors.sort_by { |error| error.position || 0 }
          absorbed.concat(in_order.first(remaining))
        end

        stale = entries_for(file).count { |entry| occurrences[entry.word].empty? }
        absorbed_ids = absorbed.map(&:object_id).to_set

        kept = result.errors.reject { |error| absorbed_ids.include?(error.object_id) }
        suppressed = result.suppressed_errors + absorbed.map do |error|
          Models::Result::WordResult.new(
            word: error.word,
            correct: false,
            suggestions: error.suggestions.to_a,
            position: error.position,
            metadata: error.metadata,
            suppressed: true,
            suppressed_by: Models::Result::WordResult::SUPPRESSED_BY_BASELINE
          )
        end

        Application.new(
          result: Models::Result::DocumentResult.new(
            file: result.file,
            errors: kept,
            suppressed_errors: suppressed,
            word_count: result.word_count,
            metadata: result.metadata
          ),
          suppressed_count: absorbed.size,
          stale_count: stale
        )
      end
    end
  end
end
