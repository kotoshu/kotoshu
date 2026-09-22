# frozen_string_literal: true

require "json"

module Kotoshu
  module Suggestions
    # CJK confusion sets (TODO.sota/4 v1): pinyin homophone tables
    # built from the CC-CEDICT pinyin column, embedded frozen (the
    # FrozenTiers precedent - deterministic, no network). A
    # confusion-hit outranks an equal-distance non-hit: Chinese
    # errors are same-pinyin (IME) or look-alike phenomena, not edit
    # distance phenomena.
    class ConfusionSet
      TABLE_PATH = File.expand_path("../data/confusion/pinyin.json", __dir__).freeze

      def self.for(language_code)
        @sets ||= {}
        @sets[language_code] ||= build(language_code)
      end

      def self.build(language_code)
        base = language_code.to_s.split("-").first
        return NULL_SET unless %w[zh ja].include?(base)

        new(JSON.parse(File.read(TABLE_PATH, encoding: "UTF-8")))
      rescue Errno::ENOENT
        NULL_SET
      end

      # Miss-evidence object with nil-for-all methods (no
      # respond_to? probing at call sites).
      NullSet = Struct.new(:available?) do
        def char_pinyin(_ch) = nil
        def homophones(_ch) = []
        def confusion_hit?(_typo, _cand) = false
      end
      NULL_SET = NullSet.new(false).freeze

      def initialize(table)
        @char_pinyin = table["char_pinyin"]
        @syllable_chars = table["syllable_chars"]
      end

      def available? = true

      def char_pinyin(ch)
        @char_pinyin[ch]
      end

      def homophones(ch)
        (@char_pinyin[ch] || []).flat_map { |s| @syllable_chars[s] }.uniq - [ch]
      end

      # True when every differing position between typo and candidate
      # is a pinyin-homophone substitution (the IME error class).
      def confusion_hit?(typo, candidate)
        t = typo.downcase.chars
        c = candidate.downcase.chars
        return false unless t.length == c.length

        diffs = t.zip(c).reject { |a, b| a == b }
        return false if diffs.empty? || diffs.length > 2

        diffs.all? { |(a, b)| homophones(a).include?(b) }
      end
    end
  end
end
