# frozen_string_literal: true

require "spec_helper"
require "kotoshu"

# Batch-3 specimen verification (plan 100): the misspelling ->
# correction pairs below were verified against the staged dictionaries
# through the real engine during development, and this spec re-runs
# the same round trips — correct? on both sides plus a suggest() that
# surfaces the correction in the top 5 — for every language the batch
# promotes to full-feature.
#
# The spec is tagged :network (dictionaries download from
# kotoshu/dictionaries on first run; the cache serves them after
# that). The typos are delete/transpose slips of common words — the
# classic single-edit forms the Damerau sweep exists for.
RSpec.describe "batch-3 language specimens through the engine", :network do
  SPECIMENS = {
    "ar" => [
      %w[مدسرة مدرسة], %w[جيمل جميل], %w[كيبر كبير], %w[ثكير كثير], %w[دجيد جديد]
    ],
    "fa" => [
      %w[مدسره مدرسه], %w[زیاب زیبا], %w[بزگر بزرگ], %w[سلما سلام], %w[خاهن خانه], %w[زبنا زبان]
    ],
    "he" => [
      %w[שלםו שלום], %w[עוםל עולם], %w[מםי מים], %w[יאשה אישה], %w[רפח פרח]
    ],
    "id" => [
      %w[buuk buku], %w[ruamh rumah], %w[beasr besar], %w[inadh indah]
    ],
    "bg" => [
      %w[кнгиа книга], %w[учлище училище], %w[глям голям], %w[крсив красив]
    ],
    "sr" => [
      %w[књгиа књига], %w[шклоа школа], %w[велкии велики], %w[свте свет], %w[куаћ кућа]
    ],
    "hr" => [
      %w[kniga knjiga], %w[škloa škola], %w[veilk velik], %w[ljep lijep]
    ],
    "sk" => [
      %w[knhia kniha], %w[škloa škola], %w[vekľý veľký], %w[pkný pekný]
    ],
    "sl" => [
      %w[knjgia knjiga], %w[šoal šola], %w[veilk velik], %w[svte svet]
    ],
    "lt" => [
      %w[kngya knyga], %w[moykla mokykla], %w[mokkyla mokykla], %w[didleis didelis]
    ],
    "lv" => [
      %w[grāamta grāmata], %w[skloa skola], %w[liles liels], %w[skists skaists]
    ],
    "et" => [
      %w[ramat raamat], %w[raaamt raamat], %w[sur suur], %w[ilsu ilus]
    ]
  }.freeze

  SPECIMENS.each do |lang, pairs|
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
    end
  end

  describe "RTL text round trips (tokenizer through the engine)" do
    it "flags the misspelling inside a real Arabic sentence" do
      Kotoshu.setup("ar", want: [:spelling])
      result = Kotoshu.check("هذه مدسرة جميلة", language: "ar")
      expect(result.errors.map(&:word)).to include("مدسرة")
    end

    it "flags the misspelling inside a real Persian sentence" do
      Kotoshu.setup("fa", want: [:spelling])
      result = Kotoshu.check("این یک مدسره است", language: "fa")
      expect(result.errors.map(&:word)).to include("مدسره")
    end

    it "flags the misspelling inside a real Hebrew sentence" do
      Kotoshu.setup("he", want: [:spelling])
      result = Kotoshu.check("זה שלםו גדול", language: "he")
      expect(result.errors.map(&:word)).to include("שלםו")
    end
  end
end
