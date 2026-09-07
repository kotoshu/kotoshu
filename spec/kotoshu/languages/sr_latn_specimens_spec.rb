# frozen_string_literal: true

require "spec_helper"
require "kotoshu"

# Serbian Latin specimen verification (plan 110): the misspelling ->
# correction pairs below were verified against the staged sr-Latn
# dictionary through the real engine during development, and this
# spec re-runs the same round trips — correct? on both sides plus a
# suggest() that surfaces the correction in the top 5.
#
# The spec is tagged :network (the dictionary downloads from
# kotoshu/dictionaries on first run; the cache serves it after
# that). The typos are delete/transpose slips of common words — the
# classic single-edit forms the Damerau sweep exists for. The
# specimens are Serbian ekavian Latin spellings (lepo veliki svet),
# the vocabulary the sr-Latn dictionary carries — not the Croatian
# ijekavian forms (lijep veliki svijet) the hr specimens use.
RSpec.describe "sr-Latn specimens through the engine", :network do
  SR_LATN_SPECIMENS = {
    "sr-Latn" => [
      %w[kniga knjiga], %w[škloa škola], %w[veilk veliki],
      %w[svte svet], %w[kuać kuća], %w[držva država]
    ]
  }.freeze

  # One real sentence carrying the first specimen typo, proving word
  # extraction through Kotoshu.check: exactly the typo surfaces, no
  # false positives on the surrounding words.
  SR_LATN_SENTENCES = {
    "sr-Latn" => ["Ovo je kniga iz škole", "kniga"]
  }.freeze

  SR_LATN_SPECIMENS.each do |lang, pairs|
    describe lang do
      before { Kotoshu.setup(lang, want: [:spelling]) }

      it "corrects the misspellings and keeps the corrections valid" do
        pairs.each do |typo, correction|
          expect(Kotoshu.correct?(correction, language: lang)).to be(true),
                                                                  "#{lang}: #{correction} must be a real word"
          expect(Kotoshu.correct?(typo, language: lang)).to be(false),
                                                            "#{lang}: #{typo} must be rejected"
        end
      end

      it "suggests the correction in the top 5" do
        pairs.each do |typo, correction|
          words = Kotoshu.suggest(typo, language: lang).to_words
          expect(words.first(5)).to include(correction),
                                    "#{lang}: #{typo} -> #{words.first(5).join(', ')}"
        end
      end

      it "flags exactly the typo inside a real sentence" do
        text, typo = SR_LATN_SENTENCES.fetch(lang)
        result = Kotoshu.check(text, language: lang)
        expect(result.errors.map(&:word)).to eq([typo])
      end
    end
  end
end
