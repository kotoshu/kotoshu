# frozen_string_literal: true

require "spec_helper"

# Vendored snapshot of the dictionaries manifest languages (plan 107):
# the offline-safe source LanguageCache::AVAILABLE_LANGUAGES derives
# from, refreshed by `rake kotoshu:staged_languages:sync`.
RSpec.describe Kotoshu::Cache::StagedLanguages do
  describe "CODES" do
    it "is frozen and sorted" do
      expect(described_class::CODES).to be_frozen
      expect(described_class::CODES).to eq(described_class::CODES.sort)
    end

    it "carries every manifest language, including module-less ones" do
      aggregate_failures "staged module-less codes" do
        %w[br cy eo eu fo fur fy ga gd gl hy hyw ia ie is ka ko la lb
           ltg mk mn nds ne nn oc rw sr-Latn sv-FI tk tlh].each do |code|
          expect(described_class::CODES).to include(code), code
        end
      end
    end

    it "still carries every full-feature module language" do
      %w[ar bg ca cs da de el en es et fa fr he hr hu id it lt lv nb
         nl nn pl pt ro ru sk sl sr sv tr uk vi].each do |code|
        expect(described_class::CODES).to include(code), code
      end
    end
  end
end

RSpec.describe Kotoshu::Cache::LanguageCache do
  describe "AVAILABLE_LANGUAGES (plan 107)" do
    it "derives from the vendored manifest snapshot" do
      expect(described_class::AVAILABLE_LANGUAGES)
        .to eq(Kotoshu::Cache::StagedLanguages::CODES)
    end

    it "lists module-less staged languages as downloadable" do
      cache = described_class.new(cache_path: Dir.mktmpdir)

      aggregate_failures "basic tier" do
        %w[is cy gd eo ga fo la mk ko ne nn hy ka].each do |code|
          expect(cache.available_languages).to include(code), code
          expect(cache.supports_resource?("#{code}:spelling")).to be(true), code
        end
      end
    end

    it "rejects languages the manifest does not stage" do
      cache = described_class.new(cache_path: Dir.mktmpdir)

      expect(cache.available_languages).not_to include("xx")
      expect(cache.supports_resource?("xx:spelling")).to be(false)
    end
  end

  describe ".full_feature_languages" do
    it "lists the module languages present in the manifest" do
      full = described_class.full_feature_languages

      expect(full).to include("en", "de", "ru", "ar", "vi")
      expect(full).to include("nn") # wired by plan 107
      expect(full).to include("ko", "ne") # wired by plan 108
      expect(full).not_to include("ja") # module but no staged dictionary
      expect(full).not_to include("is", "cy", "gd", "mk", "xx")
    end
  end
end
