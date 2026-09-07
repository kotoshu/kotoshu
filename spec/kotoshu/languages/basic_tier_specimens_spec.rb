# frozen_string_literal: true

require "spec_helper"
require "kotoshu"

# Basic-tier specimen verification (plan 107): the misspelling ->
# correction pairs below were verified against the staged dictionaries
# through the real engine during development, and this spec re-runs
# the same round trips — correct? on both sides plus a suggest() that
# surfaces the correction in the top 5 — for languages the plan
# opens. is cy gd ride the module-less basic tier (script fallback
# tokenizer + generic keyboard); nn is the module wired while here.
#
# The spec is tagged :network (dictionaries download from
# kotoshu/dictionaries on first run; the cache serves them after
# that). The typos are delete/transpose slips of common words — the
# classic single-edit forms the Damerau sweep exists for.
RSpec.describe "basic-tier language specimens through the engine", :network do
  BASIC_TIER_SPECIMENS = {
    "is" => [
      %w[þeta þetta], %w[tstofu stofu], %w[kenari kennari], %w[faeleg falleg]
    ],
    "cy" => [
      %w[hfal hafal], %w[llfr llyfr], %w[giriadur geiriadur]
    ],
    "gd" => [
      %w[lebhar leabhar], %w[leabhr leabhar], %w[leahar leabhar]
    ],
    "nn" => [
      %w[nyorsk nynorsk], %w[pråk språk], %w[uhs hus], %w[obk bok]
    ]
  }.freeze

  # One real sentence per language carrying one of its specimen
  # typos, proving word extraction through Kotoshu.check: exactly the
  # typo surfaces, no false positives on the surrounding words.
  BASIC_TIER_SENTENCES = {
    "is" => ["Þetta er kenari íslenskur", "kenari"],
    "cy" => ["Mae hwn yn hfal Gymraeg", "hfal"],
    "gd" => ["Seo lebhar Gàidhlig", "lebhar"],
    "nn" => ["Eg skriv nyorsk i dag", "nyorsk"]
  }.freeze

  BASIC_TIER_SPECIMENS.each do |lang, pairs|
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
        text, typo = BASIC_TIER_SENTENCES.fetch(lang)
        result = Kotoshu.check(text, language: lang)
        expect(result.errors.map(&:word)).to eq([typo])
      end
    end
  end
end
