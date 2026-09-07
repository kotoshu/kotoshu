# frozen_string_literal: true

require "spec_helper"
require "kotoshu"

# Korean and Nepali specimen verification (plan 108): the
# misspelling -> correction pairs below were verified against the
# staged dictionaries through the real engine during development, and
# this spec re-runs the same round trips — correct? on both sides
# plus a suggest() that surfaces the correction in the top 5 — for
# the two languages this plan promotes to full feature.
#
# The spec is tagged :network (dictionaries download from
# kotoshu/dictionaries on first run; the cache serves them after
# that). The Korean typos are syllable transpositions and vowel-slip
# forms of common eojeol; the Nepali typos drop or slip a matra or a
# conjunct member of common words.
RSpec.describe "ko and ne specimens through the engine", :network do
  KO_NE_SPECIMENS = {
    "ko" => [
      %w[국한어 한국어], %w[랑사 사랑], %w[족가 가족], %w[부공 공부],
      %w[생선님 선생님], %w[간시 시간], %w[람사 사람]
    ],
    "ne" => [
      %w[नमसते नमस्ते], %w[विदयालय विद्यालय], %w[पानि पानी]
    ]
  }.freeze

  # One real sentence per language carrying its first specimen typo,
  # proving word extraction through Kotoshu.check: exactly the typo
  # surfaces, no false positives on the surrounding eojeol/words.
  KO_NE_SENTENCES = {
    "ko" => ["생선님 안녕하세요 학생", "생선님"],
    "ne" => ["म नमसते गर्छु", "नमसते"]
  }.freeze

  KO_NE_SPECIMENS.each do |lang, pairs|
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
        text, typo = KO_NE_SENTENCES.fetch(lang)
        result = Kotoshu.check(text, language: lang)
        expect(result.errors.map(&:word)).to eq([typo])
      end
    end
  end
end
