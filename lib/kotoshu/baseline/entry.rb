# frozen_string_literal: true

require "lutaml/model"

module Kotoshu
  module Baseline
    # One baseline record: +count+ occurrences of +word+ in +file+ are
    # known debt. +line+ is the first occurrence at the time the
    # baseline was written — informational only, matching is
    # count-based (stable across reformatting).
    #
    # Serialized via lutaml-model; the canonical JSON shape is
    # `{"file": ..., "line": ..., "word": ..., "count": ...}`.
    class Entry < Lutaml::Model::Serializable
      attribute :file, :string
      attribute :line, :integer, default: 1
      attribute :word, :string, default: ""
      attribute :count, :integer, default: 1

      # Accept framework-private keywords (e.g. +lutaml_register+)
      # from lutaml-model so from_hash round-trips without lutaml
      # having to poke ivars directly.
      def initialize(file: nil, line: 1, word: "", count: 1, **kwargs)
        super(file: file, line: line, word: word.to_s, count: count, **kwargs)
      end

      # Entries are keyed by (file, word); counts merge on key.
      def key
        [file.to_s, word.to_s]
      end
    end
  end
end
