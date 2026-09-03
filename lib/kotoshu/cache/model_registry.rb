# frozen_string_literal: true

require "lutaml/model"

module Kotoshu
  module Cache
    # Parsed view of `registry.json` from kotoshu/models-fasttext-onnx
    # (Resource Spec v1, TODO.impl/07 of that repo; gem side: plan 67 M1).
    #
    # Shape:
    #
    #   {
    #     "spec": "kotoshu.resources/v1",
    #     "registry_version": 1,
    #     "generated_at": "2026-09-02T22:16:05Z",
    #     "release_tag": "v1.0.0",
    #     "resources": {
    #       "kotoshu://models/en/mini": {
    #         "type": "model",
    #         "language": "en",
    #         "tier": { "name": "mini", "dims": 300, ... },
    #         "version": "1.0.0",
    #         "urls": { "primary": "...", "mirror": "..." },
    #         "vocab_url": "...",
    #         "sha256": "...", "size_bytes": 3040752,
    #         "license": "CC-BY-SA-3.0",
    #         "min_engine_version": "0.7",
    #         "eval_ref": "eval/reports/en.mini.json"
    #       }
    #     }
    #   }
    #
    # Ids are stable forever (`kotoshu://models/{lang}/{tier}`); content
    # changes bump `version` and the release tag, never the id.
    #
    # Serialized via lutaml-model: use {ModelRegistry.from_json} /
    # {Resource.from_hash} for the wire forms — no hand-rolled
    # `to_h` / `from_h` on the model (see CLAUDE.md serialization rule).
    class ModelRegistry < Lutaml::Model::Serializable
      # One downloadable model artifact, keyed by its stable
      # `kotoshu://models/{lang}/{tier}` id in the parent registry.
      class Resource < Lutaml::Model::Serializable
        # Download URLs. `primary` is the GitHub Release asset;
        # `mirror` points at the git tree and is a fallback only.
        class Urls < Lutaml::Model::Serializable
          attribute :primary, :string
          attribute :mirror, :string
        end

        # Tier metadata block. `quantization` is null for the full tier.
        class Tier < Lutaml::Model::Serializable
          attribute :name, :string
          attribute :dims, :integer
          attribute :vocab_size, :integer
          attribute :quantization, :string
        end

        attribute :type, :string
        attribute :language, :string
        attribute :tier, Tier
        attribute :version, :string
        attribute :urls, Urls
        attribute :vocab_url, :string
        attribute :sha256, :string
        attribute :size_bytes, :integer
        attribute :license, :string
        attribute :min_engine_version, :string
        attribute :eval_ref, :string

        # Stable registry id for a (language, tier) pair. This is the key
        # under which the resource appears in {ModelRegistry#resources}.
        #
        # @param language [String] ISO 639-1 code
        # @param tier [String, Symbol] tier name ("mini", "fluency", "full")
        # @return [String] e.g. "kotoshu://models/en/mini"
        def self.id_for(language, tier)
          "kotoshu://models/#{language}/#{tier}"
        end
      end

      attribute :spec, :string
      attribute :registry_version, :integer
      attribute :generated_at, :string
      attribute :release_tag, :string
      # Id => per-resource hash. Values are deserialized on lookup via
      # {Resource.from_hash} (the framework API); lutaml-model 0.8 does
      # not support typed values inside a `:hash` attribute.
      attribute :resources, :hash

      # Typed lookup of a model resource by language and tier.
      #
      # @param language [String] ISO 639-1 code
      # @param tier [String, Symbol] tier name
      # @return [Resource, nil] the entry, or nil when the registry has
      #   no such (language, tier) combination
      def find(language, tier)
        raw = resources[Resource.id_for(language, tier)]
        raw && Resource.from_hash(raw)
      end

      # All languages the registry knows about (derived from ids).
      #
      # @return [Array<String>] sorted, unique language codes
      def languages
        resources.keys.map { |id| id.split("/")[3] }.compact.uniq.sort
      end
    end
  end
end
