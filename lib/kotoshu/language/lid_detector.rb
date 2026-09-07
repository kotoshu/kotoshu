# frozen_string_literal: true

module Kotoshu
  module Language
    # One language detection: the top label code (ISO 639) and its
    # probability, the shape the plan-106 facade returns.
    #
    # A Struct (keyword_init) per the plain-data rule — no behavior
    # beyond readers, #to_s (the code, so string interpolation reads
    # naturally), and equality.
    Detection = Struct.new(:code, :score, keyword_init: true) do
      # The code, so `"detected #{detection}"` reads naturally.
      def to_s
        code.to_s
      end
    end

    # Document language detection through the pure-Rust LID reader
    # (plan 106).
    #
    # The gem's {LanguageIdentifier} needs the Python fastText
    # bindings (broken under numpy 2), which is why /v1/detect and the
    # CLI shipped a 7-language heuristic. The native extension now
    # wraps kotoshu-rs' `lid` reader over the
    # `kotoshu://models/lid/lid-176` registry artifact pair (the
    # ONNX-converted lid.176 model + vocab sidecar, 176 languages,
    # bit-faithful to the bindings — parity frozen by the kotoshu-rs
    # suite over the shared corpus fixture).
    #
    # Selection mirrors {NativeBackend} with one difference: the
    # native engine serves detect whenever the extension is built and
    # the artifact pair is cached — an explicitly ruby backend
    # (KOTOSHU_BACKEND=ruby) opts out, but the unset default does not,
    # because the {Detector} heuristic is strictly weaker (7 languages
    # vs 176). Pure-Ruby installs keep working unchanged — no new
    # gemspec dependency, no onnxruntime.
    #
    # Two-stage like every resource: {setup} downloads the pair once
    # (registry-resolved, sha-verified); {detect} resolves from the
    # cache only and never downloads implicitly.
    #
    # @example Setup once, then detect
    #   Kotoshu.setup_lid
    #   Kotoshu.detect_language("Der Ausschuss prüft den Vorschlag")
    #   # => #<struct Kotoshu::Language::Detection code="de", score=0.99>
    class LidDetector
      class << self
        # Detect the language of text.
        #
        # Native LID when available (see {LidDetector} for the
        # selection rules), the {Detector} heuristic otherwise.
        #
        # @param text [String] Text to analyze
        # @param config [Configuration] configuration to consult
        #   (defaults to the global instance)
        # @return [Detection] code (nil when the heuristic is
        #   uncertain) and score in [0, 1]
        def detect(text, config: Kotoshu.configuration)
          # nil is not text; an empty/blank string IS (the native
          # reader scores its EOS token row — "en", ~0.12 — exactly
          # like the fastText bindings, per the frozen corpus).
          return Detection.new(code: nil, score: 0.0) if text.nil?

          model = native_model(config: config)
          return heuristic_detection(text) unless model

          row = model.detect(text)
          Detection.new(code: row.fetch("code"), score: row.fetch("score"))
        end

        # Whether {detect} would run the native engine for this
        # configuration — the extension is built, the backend is not
        # "ruby", and the artifact pair is cached.
        #
        # @param config [Configuration]
        # @return [Boolean]
        def available?(config: Kotoshu.configuration)
          !native_model(config: config).nil?
        end

        # Download the LID artifact pair into the model cache (stage
        # one of the two-stage model; registry-resolved, sha-verified).
        #
        # @param config [Configuration]
        # @param force [Boolean] re-fetch even if already cached
        # @return [Hash] { onnx_path:, vocab_path:, metadata }
        # @raise [Kotoshu::Error] no registry entry, or offline with
        #   no cached registry (KOTOSHU_OFFLINE=1)
        # @raise [Kotoshu::IntegrityError] downloaded bytes fail the
        #   registry checksum
        def setup(config: Kotoshu.configuration, force: false)
          pair = model_cache(config: config).load_cached_lid
          return pair if pair && !force

          model_cache(config: config).download_lid(force: force)
        end

        # Whether the LID artifact pair is cached (cache-only check).
        #
        # @param config [Configuration]
        # @return [Boolean]
        def setup?(config: Kotoshu.configuration)
          model_cache(config: config).lid_cached?
        end

        # Drop the memoized native model. The next {detect} re-resolves
        # from the cache — the seam tests and embedders use after
        # {setup} or a cache purge (mirrors Kotoshu.reset_spellchecker).
        #
        # @return [nil]
        def reset
          @native_model = nil
          nil
        end

        private

        # The loaded native LID model, memoized per process — one
        # parse of the ~3 MB pair, mirroring how spellcheckers are
        # cached per language. Nil whenever the native engine cannot
        # serve: extension absent, Kotoshu::Native::LidModel missing
        # (extension predates plan 106), an explicit ruby backend, or
        # the pair not set up.
        #
        # @param config [Configuration]
        # @return [Kotoshu::Native::LidModel, nil]
        def native_model(config:)
          return nil unless native_lid_surface?
          return nil if backend_opts_out?(config)

          @native_model ||= begin
            pair = model_cache(config: config).load_cached_lid
            pair && Kotoshu::Native::LidModel.load(pair[:onnx_path], pair[:vocab_path])
          end
        end

        # Whether the extension carries the LID surface at all.
        def native_lid_surface?
          Kotoshu::Native.available? && Kotoshu::Native.const_defined?(:LidModel)
        end

        # Backend selection for LID (plan 106).
        #
        # KOTOSHU_BACKEND=ruby opts the LID out of the native engine.
        # When the backend is UNSET, LID still prefers the native
        # engine — unlike correct?/suggest, where "ruby" is the engine
        # default and "native" the explicit accelerator. The heuristic
        # is strictly weaker than the 176-language model, so it stays
        # the fallback for the cannot-serve cases (no extension, no
        # cached model), not for an unset preference.
        #
        # Explicitness is read through the resolver layers (live ENV,
        # constructor settings, CLI options) so the "ruby" DEFAULT
        # never counts as an opt-out. Mutating
        # Kotoshu.configuration.backend after construction is not
        # visible here — rebuild the configuration instead.
        def backend_opts_out?(config)
          config.backend.to_s == "ruby" && backend_set?(config)
        end

        # Whether the backend was explicitly set at any resolver layer
        # (rather than left at its "ruby" default).
        def backend_set?(config)
          resolver = config.resolver
          ENV.key?("KOTOSHU_BACKEND") ||
            resolver.programmatic.key?(:backend) ||
            resolver.cli.key?(:backend)
        end

        # The heuristic fallback, wrapped in the same {Detection}
        # shape the native path returns.
        def heuristic_detection(text)
          code, confidence = Detector.detect_with_confidence(text)
          Detection.new(code: code, score: confidence)
        end

        # A cache over the configuration's model cache path and
        # source registry (so KOTOSHU_MODELS_PIN is honored).
        def model_cache(config:)
          Cache::ModelCache.new(
            cache_path: config.cache_path,
            source_registry: config.source_registry
          )
        end
      end
    end
  end
end
