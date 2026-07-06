# frozen_string_literal: true

module Kotoshu
  module Languages
    # Portuguese language implementation.
    #
    # Supports multiple dialects: pt-BR, pt-PT, pt-AO, pt-MZ, pt-GW, pt-CV
    #
    # Full Hunspell integration with spell checking, POS tagging, and grammar rules
    # specifically handling Portuguese accents and Brazilian vs European differences.
    class Portuguese < Language::Base
      # Portuguese spell checker with Hunspell integration.
      class SpellChecker < Components::SpellChecker
        attr_reader :aff_path, :dic_path, :script

        # Portuguese-specific character substitutions
        PORTUGUESE_SUBSTITUTIONS = {
          'á' => %w[a],
          'â' => %w[a],
          'ã' => %w[a],
          'à' => %w[a],
          'é' => %w[e],
          'ê' => %w[e],
          'í' => %w[i],
          'ó' => %w[o],
          'ô' => %w[o],
          'õ' => %w[o],
          'ú' => %w[u],
          'ü' => %w[u],
          'ç' => %w[c],
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

          first_form = @lookuper.good_forms(word).first
          if first_form
            { found: true, stem: first_form.stem || word, flags: first_form.flags&.to_a || [] }
          else
            { found: false, stem: nil, flags: [] }
          end
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

          # Missing accents
          word.downcase.chars.each_with_index do |char, i|
            PORTUGUESE_SUBSTITUTIONS.each do |accented, variants|
              variants.each do |variant|
                if char == variant
                  accented_word = word.dup
                  accented_word[i] = accented
                  variations << accented_word if @lookuper.good_forms(accented_word).first
                end
              end
            end
          end

          # Common substitutions
          word.chars.each_with_index do |char, i|
            next unless PORTUGUESE_SUBSTITUTIONS.key?(char.downcase)

            PORTUGUESE_SUBSTITUTIONS[char.downcase].each do |sub|
              substituted = word.dup
              substituted[i] = sub
              variations << substituted if @lookuper.good_forms(substituted).first
            end
          end

          # Doubled and deleted letters
          word.chars.each_with_index do |char, i|
            next if i == 0

            doubled = word.dup
            doubled.insert(i, char)
            variations << doubled if @lookuper.good_forms(doubled).first
          end

          (0...word.length).each do |i|
            deleted = word.dup
            deleted.slice!(i)
            next if deleted.empty?

            variations << deleted if @lookuper.good_forms(deleted).first
          end

          variations.uniq!
          variations.map do |suggestion|
            { word: suggestion, distance: calculate_distance(word, suggestion),
              score: calculate_score(word, suggestion, 0) }
          end.sort_by { |s| s[:distance] }
        end
      end

      # Portuguese tokenizer with number and date handling.
      class Tokenizer < Language::Tokenizer::PortugueseTokenizer
      end

      # Portuguese POS tagger.
      class POSTagger < Components::PosTagger
        FLAG_TO_POS = {
          'N' => 'NOUN', 'NN' => 'NOUN', 'NNS' => 'NOUN', 'NNP' => 'NOUN_PROPER',
          'V' => 'VERB', 'VB' => 'VERB', 'VBD' => 'VERB', 'VBG' => 'VERB', 'VBN' => 'VERB',
          'VBP' => 'VERB', 'VBZ' => 'VERB',
          'A' => 'ADJ', 'JJ' => 'ADJ', 'JJR' => 'ADJ', 'JJS' => 'ADJ',
          'R' => 'ADV', 'RB' => 'ADV', 'RBR' => 'ADV', 'RBS' => 'ADV',
          'D' => 'DET', 'DT' => 'DET', 'PDT' => 'DET',
          'P' => 'PRON', 'PP' => 'PRON', 'PRP' => 'PRON', 'PRP$' => 'PRON_POSS',
          'WP' => 'PRON', 'WP$' => 'PRON_POSS',
          'I' => 'PREP', 'IN' => 'PREP',
          'C' => 'CONJ', 'CC' => 'CONJ',
          'U' => 'PART', 'RP' => 'PART',
          'INTJ' => 'INTJ', 'UH' => 'INTJ',
          'CD' => 'NUM',
          'FW' => 'X',
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

        def cache_size
          @lookup_cache.size
        end

        private

        def lookup_with_pos(word)
          return { pos_tag: nil, lemma: nil } if word.nil? || word.empty?
          return @lookup_cache[word] if @lookup_cache.key?(word)

          first_form = @lookuper.good_forms(word).first
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
          return 'VERB' if suffix.match?(/^(ar|er|ir|ando|endo|indo|ado|ido)$/)
          return 'ADV' if suffix.end_with?('mente')
          return 'NOUN' if suffix.match?(/^(ção|são|mento|dade|eza|ismo|ista|or|nte)$/)
          return 'ADJ' if suffix.match?(/%(oso|ável|ível|ico|ica|ante)$/)

          nil
        end
      end

      # Portuguese grammar rules module.
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

        # Rule: Personal infinitive agreement
        class PersonalInfinitiveRule < Rule
          def initialize
            super('PT_PERSONAL_INFINITIVE', 'Personal Infinitive', 'Personal infinitive must agree with the subject.')
          end

          def check(_tokens)
            # Simplified implementation
            []
          end
        end

        # Rule: Crase (à vs a)
        class CraseRule < Rule
          def initialize
            super('PT_CRASE', 'Crase Usage', 'Use crase (à) before feminine nouns indicating place/time.')
          end

          def check(tokens)
            errors = []
            tokens.each_cons(2) do |prev_token, current_token|
              prev_word = prev_token[:token]&.downcase
              next unless %w[a ema].include?(prev_word)

              # Check if next word starts with 'a' sound and is feminine
              next_word = current_token[:token]
              next if next_word.nil? || next_word.empty?

              if next_word&.match?(/^[aáãâä]/i)
                # Suggest using crase
                errors << {
                  rule_id: @id,
                  position: prev_token[:position],
                  message: "Possible crase usage needed: '#{prev_word}' -> 'à'",
                  suggestion: 'à',
                  context: "#{prev_word} #{next_word}",
                  suggestions: ['à']
                }
              end
            end
            errors
          end
        end

        class RuleRegistry
          class << self
            def default_rules
              [PersonalInfinitiveRule.new, CraseRule.new]
            end

            def get_rule(id)
              default_rules.find { |rule| rule.id == id }
            end
          end
        end
      end

      # Registration
      register "pt"
      register "pt-BR"
      register "pt-PT"
      register "pt-AO"
      register "pt-MZ"
      register "pt-GW"
      register "pt-CV"

      HUNSPELL_DICTIONARIES = {
        'pt-BR' => {
          aff: 'spec/integrational/fixtures/pt_BR.aff',
          dic: 'spec/integrational/fixtures/pt_BR.dic'
        },
        'pt-PT' => {
          aff: 'spec/integrational/fixtures/pt_PT.aff',
          dic: 'spec/integrational/fixtures/pt_PT.dic'
        }
      }.freeze

      VARIANT_NAMES = {
        'BR' => 'Brazilian',
        'PT' => 'European',
        'AO' => 'Angolan',
        'MZ' => 'Mozambican',
        'GW' => 'Guinea-Bissau',
        'CV' => 'Cape Verdean'
      }.freeze

      def initialize(code: "pt", name: "Portuguese", variant: nil)
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
        when "pt-BR"
          ["/usr/share/dict/brazilian"]
        when "pt-PT"
          ["/usr/share/dict/portuguese"]
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
        HUNSPELL_DICTIONARIES[code] || HUNSPELL_DICTIONARIES['pt-BR']
      end
    end
  end
end
