# frozen_string_literal: true

require_relative '../../readers/lookup_builder'
require_relative '../../components/spell_checker'
require_relative '../../components/pos_tagger'
require_relative '../../language/normalizer/base'

module Kotoshu
  module Languages
    # Japanese language implementation.
    #
    # Supports ja-JP with full CJK script support.
    #
    # Uses morphological analysis via Suika gem for tokenization and POS tagging.
    # Japanese spell checking uses dictionary lookup with CJK character support.
    class Japanese < Language::Base
      # Japanese spell checker using dictionary lookup.
      #
      # Japanese uses morphological analysis rather than traditional Hunspell
      # dictionaries. Spell checking is done through dictionary lookup of segmented
      # words from the morphological analyzer.
      class SpellChecker < Components::SpellChecker
        attr_reader :dic_path, :script

        def initialize(dic_path:, script: :cjk)
          @dic_path = dic_path
          @script = script
          # Japanese dictionaries are typically in custom formats
          # Load dictionary into memory for fast lookup
          @dictionary = load_dictionary(dic_path)
        end

        def check(word)
          return { found: false, stem: nil, flags: [] } if word.nil? || word.empty?

          # Check if word exists in dictionary
          found = @dictionary.include?(word)

          if found
            { found: true, stem: word, flags: [] }
          else
            # For CJK text, we might want to check if it contains valid characters
            # but not actual word validation
            { found: false, stem: nil, flags: [] }
          end
        end

        def suggest(word, max_suggestions: 10)
          return [] if word.nil? || word.empty?
          return [] if @dictionary.include?(word)

          # Generate suggestions based on common Japanese errors
          generate_suggestions(word, max_suggestions).take(max_suggestions)
        end

        def correct?(word)
          check(word)[:found]
        end

        private

        def load_dictionary(path)
          # Simple in-memory dictionary for Japanese words
          # In production, this would use a proper CJK dictionary
          @dictionary = Set.new
          if File.exist?(path)
            File.readlines(path, encoding: 'UTF-8').each do |line|
              @dictionary.add(line.strip)
            end
          end
          @dictionary
        end

        def generate_suggestions(word, max_suggestions)
          variations = []

          # Japanese character substitutions (common errors)
          japanese_substitutions = {
            'あ' => %w[ああ],
            'い' => %w[いい],
            'う' => %w[うう],
            'え' => %w[ええ],
            'お' => %w[おお],
            'か' => %w[かが],
            'き' => %w[きぎ],
            'く' => %w[くぐ],
            'け' => %w[けげ],
            'こ' => %w[こご],
            'さ' => %w[さざ],
            'し' => %w[しじ],
            'す' => %w[すず],
            'せ' => %w[せぜ],
            'そ' => %w[そぞ],
            'た' => %w[ただ],
            'ち' => %w[ちぢ],
            'つ' => %w[つづ],
            'て' => %w[てで],
            'と' => %w[とど],
            'は' => %w[はば],
            'ひ' => %w[ひび],
            'ふ' => %w[ふぶ],
            'へ' => %w[へべ],
            'ほ' => %w[ほぼ],
            'ま' => %w[まま],
            'み' => %w[みみ],
            'む' => %w[むむ],
            'め' => %w[めめ],
            'も' => %w[もも],
            'や' => %w[やや],
            'ゆ' => %w[ゆゆ],
            'よ' => %w[よよ],
            'ら' => %w[らら],
            'り' => %w[りり],
            'る' => %w[るる],
            'れ' => %w[れれ],
            'ろ' => %w[ろろ],
            'わ' => %w[わわ],
            'を' => %w[お],
          }

          word.chars.each_with_index do |char, i|
            next unless japanese_substitutions.key?(char)
            japanese_substitutions[char].each do |sub|
              substituted = word.dup
              substituted[i] = sub
              variations << substituted if @dictionary.include?(substituted)
            end
          end

          # Suggest similar dictionary words
          if word.length >= 2
            @dictionary.each do |dict_word|
              distance = levenshtein_distance(word, dict_word)
              if distance <= 2 && distance > 0
                variations << dict_word
              end
              break if variations.length >= max_suggestions * 2
            end
          end

          variations.uniq.first(max_suggestions)
        end

        def levenshtein_distance(a, b)
          return a.length if b.empty?
          return b.length if a.empty?
          matrix = Array.new(a.length + 1) { |i| [i] + [0] * b.length }
          (1..b.length).each { |j| matrix[0][j] = j }
          (1..a.length).each do |i|
            (1..b.length).each do |j|
              cost = a[i - 1] == b[j - 1] ? 0 : 1
              matrix[i][j] = [matrix[i - 1][j] + 1, matrix[i][j - 1] + 1, matrix[i - 1][j - 1] + cost].min
            end
          end
          matrix[a.length][b.length]
        end
      end

      # Japanese tokenizer with morphological analysis.
      class Tokenizer < Language::Tokenizer::JapaneseTokenizer
      end

      # Japanese POS tagger using morphological analysis.
      #
      # Japanese POS tagging is integrated with tokenization via Suika gem,
      # which provides both segmentation and part-of-speech information.
      #
      # Suika output format: surface<TAB>POS,subcat1,subcat2,subcat3,conj_type,conj_form,lemma,reading,pronunciation
      # Example: "すもも\t名詞,一般,*,*,*,*,すもも,スモモ,スモモ"
      #
      # POS tags use universal English categories for common types, and ROMAJI
      # (Latin script) identifiers based on Japanese terminology only for
      # language-specific categories without universal equivalents.
      class POSTagger < Components::PosTagger
        # Japanese POS tag mappings from Suika to standard identifiers.
        #
        # Strategy: Use universal English POS tags (NOUN, VERB, etc.) with
        # English suffixes for subcategories. All identifiers are ASCII.
        #
        # Main categories (field 0) - universal:
        # - 名詞 → NOUN
        # - 動詞 → VERB
        # - 助詞 → PARTICLE
        # - 助動詞 → AUX
        #
        # Noun subcategories (field 1):
        # - NOUN_COMMON: 一般 - common nouns
        # - NOUN_PROPER: 固有名詞 - proper nouns
        # - NOUN_PROPER_GEOGRAPHIC: 固有名詞,地域 - proper noun, geographic
        # - NOUN_SUFFIX: 接尾 - suffixes
        # - NOUN_DEPENDENT: 非自立 - dependent nouns (cannot stand alone)
        # - NOUN_SA_CONNECTION: サ変接続 - sa-variant connection nouns
        #
        # Particle subcategories (field 1):
        # - PARTICLE_GRAMMAR: 格助詞 - grammar/case particles (が, を, に, etc.)
        # - PARTICLE_BINDING: 係助詞 - binding particles (は, も, etc.)
        # - PARTICLE_ADNOMINAL: 連体化 - adnominal particles (の)
        #
        # Verb subcategories (field 1):
        # - VERB_INDEPENDENT: 自立 - independent verbs
        FLAG_TO_POS = {
          # Main categories - universal English
          '名詞' => 'NOUN',
          '動詞' => 'VERB',
          '助詞' => 'PARTICLE',
          '助動詞' => 'AUX',

          # Noun subcategories
          '名詞,一般' => 'NOUN_COMMON',
          '名詞,固有名詞' => 'NOUN_PROPER',
          '名詞,固有名詞,地域' => 'NOUN_PROPER_GEOGRAPHIC',
          '名詞,接尾' => 'NOUN_SUFFIX',
          '名詞,非自立' => 'NOUN_DEPENDENT',
          '名詞,サ変接続' => 'NOUN_SA_CONNECTION',

          # Particle subcategories
          '助詞,格助詞' => 'PARTICLE_GRAMMAR',
          '助詞,係助詞' => 'PARTICLE_BINDING',
          '助詞,連体化' => 'PARTICLE_ADNOMINAL',

          # Verb subcategories
          '動詞,自立' => 'VERB_INDEPENDENT',
        }.freeze

        def initialize(dictionary_path: nil, flag_mapping: FLAG_TO_POS)
          @dictionary_path = dictionary_path
          @flag_mapping = flag_mapping
          @suika_tagger = nil
          @lookup_cache = {}
        end

        def tag(tokens)
          return [] if tokens.nil? || tokens.empty?

          # Initialize Suika tagger
          require "suika" unless defined?(::Suika)
          @suika_tagger ||= ::Suika::Tagger.new

          tokens.map do |token|
            word = token[:token]
            if word.nil? || word.empty?
              token.merge(pos_tag: nil, lemma: nil)
            else
              lookup_result = lookup_with_pos(word)
              token.merge(pos_tag: lookup_result[:pos_tag], lemma: lookup_result[:lemma] || word)
            end
          end
        end

        def flag_mapping
          @flag_mapping
        end

        def flag_mapping=(mapping)
          @flag_mapping = mapping
        end

        def clear_cache
          @lookup_cache.clear
        end

        private

        def lookup_with_pos(word)
          return { pos_tag: nil, lemma: nil } if word.nil? || word.empty?
          return @lookup_cache[word] if @lookup_cache.key?(word)

          # Use Suika to parse and get POS information
          parsed = @suika_tagger.parse(word)

          # Suika returns tab-separated values: surface\tfeatures
          # Features contain POS information
          pos_tag = extract_pos_from_suika(parsed)
          lemma = extract_lemma_from_suika(parsed)

          cache_result = { pos_tag: pos_tag, lemma: lemma }
          @lookup_cache[word] = cache_result
          cache_result
        end

        def extract_pos_from_suika(parsed)
          return nil unless parsed && parsed.first

          # Parse features from Suika output
          # Format: surface<TAB>POS,sub1,sub2,sub3,conj_type,conj_form,lemma,reading,pronunciation
          parts = parsed.first.split("\t")
          return nil unless parts.length > 1

          # Features are comma-separated
          # Field 0: Surface form
          # Field 1: Main POS category (e.g., 名詞, 動詞, 助詞)
          # Field 2-6: POS subcategories and conjugation info
          # Field 7: Lemma (dictionary form)
          # Field 8: Reading (katakana)
          # Field 9: Pronunciation (katakana)
          features = parts[1].split(',')

          # Build hierarchical POS paths from most specific to least specific
          # e.g., ["名詞,固有名詞,地域", "名詞,固有名詞", "名詞"]
          pos_paths = []
          6.times do |i|
            path = features[0..i].join(',')
            pos_paths << path
          end
          # Reverse to check most specific first
          pos_paths.reverse!

          # Try to match from most specific to least specific
          pos_paths.each do |pos_path|
            if FLAG_TO_POS.key?(pos_path)
              return FLAG_TO_POS[pos_path]
            end
          end

          nil
        end

        def extract_lemma_from_suika(parsed)
          return nil unless parsed && parsed.first

          parts = parsed.first.split("\t")
          return nil unless parts.length > 1

          # Extract lemma from Suika features
          # Format is complex, so simplified version
          parts[0] # Return surface form as lemma
        end
      end

      # Japanese grammar rules module.
      module GrammarRules
        class Rule
          attr_reader :id, :name, :description

          def initialize(id, name, description)
            @id = id
            @name = name
            @description = description
          end

          def check(tokens)
            raise NotImplementedError, "#{self.class} must implement #check"
          end
        end

        # Rule: Particle usage (wa vs ga)
        class ParticleRule < Rule
          def initialize
            super('JA_PARTICLE_USAGE', 'Particle Usage', 'Correct usage of topic marker は vs subject marker が.')
          end

          def check(tokens)
            # Simplified implementation
            []
          end
        end

        # Rule: Script mixing
        class ScriptMixingRule < Rule
          def initialize
            super('JA_SCRIPT_MIXING', 'Script Mixing', 'Japanese text uses multiple scripts (Hiragana, Katakana, Kanji).')
          end

          def check(tokens)
            errors = []
            tokens.each do |token|
              word = token[:token]
              next if word.nil? || word.empty?

              # Check for script mixing inconsistencies
              has_hiragana = word.match?(/[\u3040-\u309F]/)
              has_katakana = word.match?(/[\u30A0-\u30FF]/)
              has_kanji = word.match?(/[\u4E00-\u9FFF]/)

              # Words typically shouldn't mix all three scripts
              if has_hiragana && has_katakana && has_kanji
                errors << {
                  rule_id: @id,
                  position: token[:position],
                  message: "Unusual script mixing in word '#{word}'",
                  suggestion: 'Review script usage',
                  context: word,
                  suggestions: ['Use consistent script']
                }
              end
            end
            errors
          end
        end

        class RuleRegistry
          class << self
            def default_rules
              [ParticleRule.new, ScriptMixingRule.new]
            end

            def get_rule(id)
              default_rules.find { |rule| rule.id == id }
            end
          end
        end
      end

      # Registration
      register "ja"
      register "ja-JP"

      HUNSPELL_DICTIONARIES = {
        'ja-JP' => {
          # Japanese dictionaries are in custom formats
          # Suika uses its own dictionary format
        }
      }.freeze

      VARIANT_NAMES = {
        'JP' => 'Japan'
      }.freeze

      def initialize(code: "ja", name: "Japanese", variant: nil)
        variant ||= extract_region_code(code)
        super(code: code, name: name, variant: variant)
      end

      def description
        return name unless variant
        variant_name = VARIANT_NAMES[variant] || variant
        "#{name} (#{variant_name})"
      end

      def tokenizer
        @tokenizer ||= Tokenizer.new
      end

      def normalizer
        @normalizer ||= Language::Normalizer::Base.new
      end

      def dictionary_class
        Dictionary::UnixWords
      end

      def default_dictionary_paths
        ["/usr/share/dict/words"]
      end

      def script_type
        :cjk
      end

      def create_spell_checker
        # Japanese uses custom dictionary, not Hunspell format
        SpellChecker.new(
          dic_path: default_dictionary_paths.first,
          script: :cjk
        )
      end

      def create_tokenizer
        Tokenizer.new
      end

      def create_pos_tagger
        POSTagger.new(
          dictionary_path: default_dictionary_paths.first,
          flag_mapping: POSTagger::FLAG_TO_POS
        )
      end

      private

      def extract_region_code(code)
        return nil unless code.include?("-")
        code.split("-", 2).last.upcase
      end
    end
  end
end
