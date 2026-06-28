# frozen_string_literal: true

require_relative '../../readers/lookup_builder'
require_relative '../../components/spell_checker'
require_relative '../../components/pos_tagger'
require_relative '../../language/normalizer/base'

module Kotoshu
  module Languages
    # German language implementation.
    #
    # Supports multiple dialects: de-DE, de-AT, de-CH, de-BE, de-IT, de-LI, de-LU
    #
    # Full Hunspell integration with spell checking, POS tagging, and grammar rules
    # specifically handling German compound words and capitalization.
    class German < Language::Base
      # German spell checker with Hunspell integration.
      #
      # Uses the Lookup algorithm with Hunspell-format dictionaries
      # and handles German-specific features (umlauts, ß, compound words).
      class SpellChecker < Components::SpellChecker
        attr_reader :aff_path, :dic_path, :script

        # German-specific character substitutions for suggestions
        GERMAN_SUBSTITUTIONS = {
          # Umlauts
          'ä' => %w[a ae],
          'ö' => %w[o oe],
          'ü' => %w[u ue],
          'ß' => %w[ss sz],
          # Common German errors
          'a' => %w[ä],
          'o' => %w[ö],
          'u' => %w[ü],
          's' => %w[ß],
        }.freeze

        def initialize(aff_path:, dic_path:, script: :latin, encoding: 'UTF-8')
          @aff_path = aff_path
          @dic_path = dic_path
          @script = script
          @encoding = encoding
          @lookuper = Readers::LookupBuilder.new(aff_path, dic_path, encoding: encoding, script: script).build
        end

        def check(word)
          return { found: false, stem: nil, flags: [] } if word.nil? || word.empty?

          # Try exact match first
          first_form = @lookuper.good_forms(word).first
          return { found: true, stem: first_form.stem || word, flags: first_form.flags&.to_a || [] } if first_form

          # Try lowercase version (German nouns are capitalized)
          unless word == word.downcase
            lowercase_form = @lookuper.good_forms(word.downcase).first
            if lowercase_form
              return { found: true, stem: lowercase_form.stem || word.downcase,
                       flags: lowercase_form.flags&.to_a || [] }
            end
          end

          { found: false, stem: nil, flags: [] }
        end

        def suggest(word, max_suggestions: 10)
          return [] if word.nil? || word.empty?

          first_form = @lookuper.good_forms(word).first
          return [] if first_form

          generate_suggestions(word, max_suggestions).take(max_suggestions)
        end

        def correct?(word)
          check(word)[:found]
        end

        def lookuper
          @lookuper
        end

        private

        def calculate_distance(a, b)
          return a.length if b.empty?
          return b.length if a.empty?

          matrix = Array.new(a.length + 1) { |i| [i] + ([0] * b.length) }
          (1..b.length).each { |j| matrix[0][j] = j }
          (1..a.length).each do |i|
            (1..b.length).each do |j|
              cost = a[i - 1] == b[j - 1] ? 0 : 1
              matrix[i][j] = [matrix[i - 1][j] + 1, matrix[i][j - 1] + 1, matrix[i - 1][j - 1] + cost].min
            end
          end
          matrix[a.length][b.length]
        end

        def calculate_score(original, suggestion, rank)
          distance = calculate_distance(original, suggestion)
          max_len = [original.length, suggestion.length].max
          distance_score = 1.0 - (distance.to_f / max_len)
          rank_penalty = rank * 0.05
          [distance_score - rank_penalty, 0.0].max
        end

        def generate_suggestions(word, _max_suggestions)
          variations = []

          # Missing umlauts
          word.downcase.chars.each_with_index do |char, i|
            GERMAN_SUBSTITUTIONS.each do |umlaut, variants|
              variants.each do |variant|
                if char == variant
                  umlaut_word = word.dup
                  umlaut_word[i] = umlaut
                  variations << umlaut_word if @lookuper.good_forms(umlaut_word).first
                end
              end
            end
          end

          # ß vs ss
          if word.include?('ss')
            eszett_word = word.gsub('ss', 'ß')
            variations << eszett_word if @lookuper.good_forms(eszett_word).first
          elsif word.include?('ß')
            double_s_word = word.gsub('ß', 'ss')
            variations << double_s_word if @lookuper.good_forms(double_s_word).first
          end

          # Capitalization (German nouns are capitalized)
          if word == word.downcase
            capitalized_word = word.capitalize
            variations << capitalized_word if @lookuper.good_forms(capitalized_word).first
          end

          # Doubled letters
          word.chars.each_with_index do |char, i|
            next if i == 0

            doubled = word.dup
            doubled.insert(i, char)
            variations << doubled if @lookuper.good_forms(doubled).first
          end

          # Deleted letters
          (0...word.length).each do |i|
            deleted = word.dup
            deleted.slice!(i)
            next if deleted.empty?

            variations << deleted if @lookuper.good_forms(deleted).first
          end

          # Compound word splitting (German has long compound words)
          if word.length > 10
            # Try splitting common compound patterns
            common_prefixes = %w[Arbeits Baum Bau Bauern Berg Buch Dach Dollar Dorf Ein Frauen Feuer Finanz Flug Franz
                                 Frei Haupt Haus Hoch Jahr Jung Kinder Klein Konsum Land Lehr Leben Leute Mann MarktMein Milli
                                 Morgen Mutter Natur Papier Polizei Post Post Problem Recht Rhein Rot Sache Schule Schiff Schritt
                                 Schiff See Sozial Stadt Stein Steuer Strom Tag Teil Tier Tor Tour Typ Uhr Umwelt Unter Volk
                                 Wasser Weg Welt Wein Welt Zeit]
            common_prefixes.each do |prefix|
              if word.start_with?(prefix)
                split_word = prefix + ' ' + word[prefix.length..]
                # Check if both parts are valid
                prefix_valid = @lookuper.good_forms(prefix).first
                suffix_valid = @lookuper.good_forms(word[prefix.length..]).first
                if prefix_valid && suffix_valid
                  variations << split_word
                end
              end
            end
          end

          variations.uniq!
          variations.map do |suggestion|
            { word: suggestion, distance: calculate_distance(word, suggestion),
              score: calculate_score(word, suggestion, 0) }
          end.sort_by { |s| s[:distance] }
        end
      end

      # German tokenizer with special character handling.
      class Tokenizer < Language::Tokenizer::GermanTokenizer
      end

      # German POS tagger.
      #
      # Derives POS tags from Hunspell flags using German-specific mappings.
      class POSTagger < Components::PosTagger
        # German POS flag mappings based on Hunspell German dictionaries
        FLAG_TO_POS = {
          # Nouns (German nouns are capitalized)
          'N' => 'NOUN', 'NN' => 'NOUN', 'NNS' => 'NOUN', 'NNP' => 'NOUN_PROPER',
          'Sub' => 'NOUN',
          # Verbs
          'V' => 'VERB', 'VB' => 'VERB', 'VBD' => 'VERB', 'VBG' => 'VERB', 'VBN' => 'VERB',
          'VBP' => 'VERB', 'VBZ' => 'VERB',
          'Vfin' => 'VERB', 'Vinf' => 'VERB', 'Vpp' => 'VERB',
          # Adjectives
          'A' => 'ADJ', 'JJ' => 'ADJ', 'JJR' => 'ADJ', 'JJS' => 'ADJ',
          'Adj' => 'ADJ',
          # Adverbs
          'R' => 'ADV', 'RB' => 'ADV', 'RBR' => 'ADV', 'RBS' => 'ADV',
          'Adv' => 'ADV',
          # Determiners
          'D' => 'DET', 'DT' => 'DET', 'PDT' => 'DET',
          'Art' => 'DET',
          # Pronouns
          'P' => 'PRON', 'PP' => 'PRON', 'PRP' => 'PRON', 'PRP$' => 'PRON_POSS',
          'WP' => 'PRON', 'WP$' => 'PRON_POSS',
          'Pro' => 'PRON',
          # Prepositions
          'I' => 'PREP', 'IN' => 'PREP',
          'Prä' => 'PREP',
          # Conjunctions
          'C' => 'CONJ', 'CC' => 'CONJ',
          'Kon' => 'CONJ',
          # Particles
          'U' => 'PART', 'RP' => 'PART',
          'Pt' => 'PART',
          # Interjections
          'INTJ' => 'INTJ', 'UH' => 'INTJ',
          'Int' => 'INTJ',
          # Numbers
          'CD' => 'NUM',
          'Num' => 'NUM',
          # Foreign words
          'FW' => 'X',
          # Punctuation
          'PUNCT' => 'PUNCT', '.' => 'PUNCT', ',' => 'PUNCT', '!' => 'PUNCT',
          '?' => 'PUNCT', ';' => 'PUNCT', ':' => 'PUNCT'
        }.freeze

        attr_reader :aff_path, :dic_path, :script

        def initialize(aff_path:, dic_path:, script: :latin, encoding: 'UTF-8', flag_mapping: FLAG_TO_POS)
          @aff_path = aff_path
          @dic_path = dic_path
          @script = script
          @encoding = encoding
          @flag_mapping = flag_mapping
          @lookuper = Readers::LookupBuilder.new(aff_path, dic_path, encoding: encoding, script: script).build
          @lookup_cache = {}
        end

        def tag(tokens)
          return [] if tokens.nil? || tokens.empty?

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

          # German nouns are capitalized - try lowercase if capitalized doesn't work
          first_form = @lookuper.good_forms(word).first
          if !first_form && word == word.capitalize && word.length > 1
            first_form = @lookuper.good_forms(word.downcase).first
          end

          pos_tag = derive_pos_tag(first_form)
          cache_result = { pos_tag: pos_tag, lemma: first_form&.stem }
          @lookup_cache[word] = cache_result
          cache_result
        end

        def derive_pos_tag(result)
          return nil unless result

          flags = result.flags&.to_a || []
          return guess_pos_from_affix(result) if flags.empty?

          flags.each do |flag|
            pos_tag = flag_to_pos(flag)
            return pos_tag if pos_tag
          end
          guess_pos_from_affix(result)
        end

        def flag_to_pos(flag)
          return @flag_mapping[flag] if @flag_mapping.key?(flag)

          first_char = flag[0]
          @flag_mapping[first_char]
        end

        def guess_pos_from_affix(result)
          suffix = result.suffix
          return guess_pos_from_suffix(suffix) if suffix

          nil
        end

        def guess_pos_from_suffix(suffix)
          # German suffix patterns
          return 'VERB' if suffix.match?(/^(en|eln|ern|ten|tet|t|is|ieren)$/)
          return 'ADV' if suffix.match?(/^(lich|weise|lings|maß|mäßig)$/)
          return 'NOUN' if suffix.match?(/^(ung|heit|keit|schaft|tion|ismus|tum|ling|ner|eur)$/)
          return 'ADJ' if suffix.match?(/^(isch|ig|lich|bar|sam|haft|los|mäßig)$/)

          nil
        end
      end

      # German grammar rules module.
      module GrammarRules
        # Base class for German grammar rules.
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

          def applies?(_tokens, _index)
            true
          end
        end

        # Rule: German noun capitalization.
        class NounCapitalizationRule < Rule
          # Common German noun suffixes
          NOUN_SUFFIXES = %w[ung heit keit schaft tion ismus tum ling ner eur
                             able ibil ig igkeit lich sam los losung].freeze

          def initialize
            super('DE_NOUN_CAPITALIZATION', 'Noun Capitalization', 'German nouns must be capitalized.')
          end

          def check(tokens)
            errors = []
            tokens.each_with_index do |token, idx|
              word = token[:token]
              next if word.nil? || word.empty?
              next if word == word.capitalize # Already capitalized
              next if word.length < 3 # Too short
              next unless word.match?(/^[a-zäöüß]+$/i) # Only letters

              # Check if it looks like a noun (has noun suffix or is in noun position)
              if word.end_with?(*NOUN_SUFFIXES)
                errors << {
                  rule_id: @id,
                  position: token[:position],
                  message: "German nouns must be capitalized: '#{word}'",
                  suggestion: word.capitalize,
                  context: word,
                  suggestions: [word.capitalize]
                }
              end

              # Check position: after determiners often indicates a noun
              if idx > 0
                prev_token = tokens[idx - 1][:token]&.downcase
                if %w[der die das ein eine einem einen einer
                      eines].include?(prev_token) && word == word.downcase && word.length > 2
                  errors << {
                    rule_id: @id,
                    position: token[:position],
                    message: "German nouns must be capitalized after articles: '#{word}'",
                    suggestion: word.capitalize,
                    context: "#{prev_token} #{word}",
                    suggestions: [word.capitalize]
                  }
                end
              end
            end
            errors
          end
        end

        # Rule: Compound word spacing (German compounds are written together).
        class CompoundSpacingRule < Rule
          def initialize
            super('DE_COMPOUND_SPACING', 'Compound Spacing', 'German compound words should not have spaces.')
          end

          def check(tokens)
            errors = []
            tokens.each_with_index do |token, idx|
              next unless idx < tokens.length - 1

              word1 = token[:token]
              word2 = tokens[idx + 1][:token]
              next if word1.nil? || word2.nil?

              # Check if both are lowercase (might be parts of a compound)
              if word1.match?(/^[a-zäöüß]+$/) && word2.match?(/^[a-zäöüß]+$/)
                # Suggest they might be a compound word
                compound = word1 + word2
                errors << {
                  rule_id: @id,
                  position: token[:position],
                  message: "Possible compound word: '#{word1} #{word2}' should be '#{compound}'",
                  suggestion: compound,
                  context: "#{word1} #{word2}",
                  suggestions: [compound]
                }
              end
            end
            errors
          end
        end

        # Rule registry for German.
        class RuleRegistry
          class << self
            def default_rules
              [NounCapitalizationRule.new, CompoundSpacingRule.new]
            end

            def get_rule(id)
              default_rules.find { |rule| rule.id == id }
            end
          end
        end
      end

      # Registration
      register "de"
      register "de-DE"
      register "de-AT"
      register "de-CH"
      register "de-BE"
      register "de-IT"
      register "de-LI"
      register "de-LU"

      HUNSPELL_DICTIONARIES = {
        'de-DE' => {
          aff: 'spec/integrational/fixtures/de_DE.aff',
          dic: 'spec/integrational/fixtures/de_DE.dic'
        },
        'de-AT' => {
          aff: 'spec/integrational/fixtures/de_AT.aff',
          dic: 'spec/integrational/fixtures/de_AT.dic'
        },
        'de-CH' => {
          aff: 'spec/integrational/fixtures/de_CH.aff',
          dic: 'spec/integrational/fixtures/de_CH.dic'
        }
      }.freeze

      VARIANT_NAMES = {
        'DE' => 'German',
        'AT' => 'Austrian',
        'CH' => 'Swiss',
        'BE' => 'Belgian',
        'IT' => 'South Tyrolean',
        'LI' => 'Liechtenstein',
        'LU' => 'Luxembourgish'
      }.freeze

      def initialize(code: "de", name: "German", variant: nil)
        variant ||= extract_region_code(code)
        super
        @hunspell_paths = resolve_hunspell_paths(code)
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
        case code
        when "de-DE", "de-AT", "de-BE"
          ["/usr/share/dict/german"]
        when "de-CH"
          ["/usr/share/dict/swiss-german"]
        else
          ["/usr/share/dict/words"]
        end
      end

      def script_type
        :latin
      end

      def create_spell_checker
        SpellChecker.new(
          aff_path: @hunspell_paths[:aff],
          dic_path: @hunspell_paths[:dic],
          script: :latin
        )
      end

      def create_tokenizer
        Tokenizer.new
      end

      def create_pos_tagger
        POSTagger.new(
          aff_path: @hunspell_paths[:aff],
          dic_path: @hunspell_paths[:dic],
          script: :latin,
          flag_mapping: POSTagger::FLAG_TO_POS
        )
      end

      private

      def extract_region_code(code)
        return nil unless code.include?("-")

        code.split("-", 2).last.upcase
      end

      def resolve_hunspell_paths(code)
        HUNSPELL_DICTIONARIES[code] || HUNSPELL_DICTIONARIES['de-DE']
      end
    end
  end
end
