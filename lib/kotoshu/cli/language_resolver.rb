# frozen_string_literal: true

module Kotoshu
  module Cli
    # Resolves which language a check should run in.
    #
    # The CLI's --language flag accepts:
    #   - omitted / "auto"   → detect from content, fall back if needed
    #   - "default"          → Configuration.default_language (no detection)
    #   - any other code     → used as-is
    #
    # Pure logic — no IO. Detection delegates to Kotoshu::Language.detect
    # which uses character-set heuristics and needs no model download.
    # A detection only "sticks" if the detected language is set up
    # (Kotoshu.setup? returns true); otherwise the configured default
    # is used and a fallback note is included in the result.
    class LanguageResolver
      Result = Struct.new(:language, :detected, :fallback, :note, keyword_init: true)

      # @param flag_value [String, nil] Raw --language flag value.
      # @param default_language [String, nil] Configuration.default_language.
      # @param detector [#detect] Object responding to .detect(text) -> String|nil.
      #   Defaults to Kotoshu::Language.
      # @param setup_predicate [#call] Callable returning true if a language is
      #   set up. Defaults to Kotoshu.method(:setup?).
      def initialize(flag_value:, default_language:,
                     detector: Kotoshu::Language,
                     setup_predicate: Kotoshu.method(:setup?))
        @flag_value = flag_value
        @default_language = default_language
        @detector = detector
        @setup_predicate = setup_predicate
      end

      # @param text [String] The document text, used only when flag is "auto".
      # @return [Result]
      def resolve(text:)
        case @flag_value
        when nil, "auto"
          resolve_auto(text)
        when "default"
          Result.new(language: @default_language, detected: nil, fallback: nil,
                     note: nil)
        else
          Result.new(language: @flag_value, detected: nil, fallback: nil,
                     note: nil)
        end
      end

      private

      def resolve_auto(text)
        detected = safe_detect(text)
        if detected.nil?
          return Result.new(language: @default_language, detected: nil,
                            fallback: @default_language,
                            note: "No language detected; using default '#{@default_language}'.")
        end
        if setup?(detected)
          return Result.new(language: detected, detected: detected, fallback: nil,
                            note: "Detected: #{detected}.")
        end

        Result.new(language: @default_language, detected: detected,
                   fallback: @default_language,
                   note: "Detected: #{detected} (fallback: #{@default_language}).")
      end

      def safe_detect(text)
        return nil if text.nil? || text.strip.empty?

        detected = @detector.detect(text)
        return nil if detected.nil? || detected.strip.empty?

        normalize(detected)
      rescue StandardError
        nil
      end

      def normalize(code)
        code.to_s.downcase.split(/[-_]/).first
      end

      def setup?(lang)
        return false if lang.nil? || lang.strip.empty?

        @setup_predicate.call(lang)
      end
    end
  end
end
