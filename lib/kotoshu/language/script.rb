# frozen_string_literal: true

require "set"

module Kotoshu
  module Language
    # Script classification for languages without a module (plan 107).
    #
    # Language modules are the full-feature tier: they bring keyboard
    # layouts, tokenizer care and verified specimens. Every language
    # staged in the dictionaries manifest is still usable without
    # one — this module maps a language code to its writing script
    # and supplies the tokenizer the spell-check word extraction
    # (plan 91) rides on:
    #
    # - Latin, Cyrillic and Greek reuse their real tokenizer classes;
    # - other scripts get a generic {Tokenizer::ScriptTokenizer}
    #   parameterized with the script's Unicode set;
    # - unknown codes return nil and the ASCII fallback applies.
    #
    # The map covers the languages of the dictionaries manifest plus
    # their near neighbors, so a code is misclassified only when the
    # manifest grows without this file — which the
    # kotoshu:staged_languages:sync rake task surfaces.
    module Script
      # Language code -> script symbol for every manifest language.
      # Latin is the default and therefore not listed.
      SCRIPT_BY_LANGUAGE = {
        # Cyrillic (module languages bg ru sr uk plus staged mk mn).
        "bg" => :cyrillic, "ru" => :cyrillic, "sr" => :cyrillic,
        "uk" => :cyrillic, "be" => :cyrillic,
        "mk" => :cyrillic, "mn" => :cyrillic,
        # Greek (el; the manifest also stages el-polyton).
        "el" => :greek, "el-polyton" => :greek,
        # Arabic script (ar fa; fa also needs ZWNJ, which its module
        # tokenizer handles — this generic set is the module-less
        # fallback only).
        "ar" => :arabic, "fa" => :arabic, "ur" => :arabic, "ps" => :arabic,
        # Hebrew script.
        "he" => :hebrew, "yi" => :hebrew,
        # Armenian (staged hy hyw).
        "hy" => :armenian, "hyw" => :armenian,
        # Georgian (staged ka).
        "ka" => :georgian,
        # Devanagari (staged ne; hi mr sa ride the same script).
        "ne" => :devanagari, "hi" => :devanagari, "mr" => :devanagari,
        "sa" => :devanagari,
        # Hangul (staged ko).
        "ko" => :hangul
      }.freeze

      # Word-character regex per script, for the generic tokenizer.
      SCRIPT_WORD_REGEXES = {
        arabic: /\p{Arabic}/,
        hebrew: /\p{Hebrew}/,
        armenian: /\p{Armenian}/,
        georgian: /\p{Georgian}/,
        devanagari: /\p{Devanagari}/,
        hangul: /\p{Hangul}/
      }.freeze

      # Tokenizer classes reused from the dedicated script tokenizers.
      SCRIPT_TOKENIZER_CLASSES = {
        cyrillic: Tokenizer::CyrillicTokenizer,
        greek: Tokenizer::GreekTokenizer
      }.freeze

      class << self
        # The writing script of a language code (:latin default).
        #
        # @param code [String] Language code (e.g. "mk", "ko")
        # @return [Symbol] Script name (:latin, :cyrillic, ...)
        def script_for(code)
          return :latin if code.nil? || code.empty?

          SCRIPT_BY_LANGUAGE.fetch(normalized_base(code), :latin)
        end

        # The script-appropriate tokenizer for a language without a
        # module, or nil when the language is unknown (the ASCII
        # fallback then applies, exactly as before plan 107).
        #
        # Latin-script languages return the shared LatinTokenizer —
        # the same tokenizer every LatinBase module uses — so the
        # basic tier and the full-feature tier agree on word
        # extraction until a module adds language-specific care.
        #
        # @param code [String] Language code
        # @return [Tokenizer::Base, nil] Tokenizer or nil
        def tokenizer_for(code)
          return nil if code.nil? || code.empty?

          script = script_for(code)
          if script == :latin
            latin_script_languages.include?(normalized_base(code)) ? Tokenizer::LatinTokenizer.new : nil
          elsif SCRIPT_TOKENIZER_CLASSES.key?(script)
            SCRIPT_TOKENIZER_CLASSES.fetch(script).new
          elsif SCRIPT_WORD_REGEXES.key?(script)
            Tokenizer::ScriptTokenizer.new(word_regex: SCRIPT_WORD_REGEXES.fetch(script))
          end
        end

        private

        # Downcase and strip the region ("sv-FI" -> "sv", "en-GB" ->
        # "en"), mirroring ResourceManager's language normalization.
        def normalized_base(code)
          code.to_s.split("-").first.split("_").first.downcase
        end

        # Latin-script codes this module knows: the manifest's Latin
        # languages. Unknown Latin-ish codes stay nil so new manifest
        # entries do not silently widen word extraction beyond the
        # vendored list (the sync rake task refreshes it).
        def latin_script_languages
          @latin_script_languages ||= begin
            classified = SCRIPT_BY_LANGUAGE.keys.map { |k| normalized_base(k) }.to_set
            Cache::StagedLanguages::CODES.map { |c| normalized_base(c) }.uniq
              .reject { |c| classified.include?(c) }
              .to_set
          end
        end
      end
    end
  end
end
