# frozen_string_literal: true

module Kotoshu
  module Languages
    # Spanish language implementation.
    #
    # Supports multiple dialects: es-ES, es-MX, es-AR, es-CO, es-PE, es-VE, es-CL, es-EC
    #
    # Full Hunspell integration with spell checking, POS tagging, and grammar rules
    # specifically handling Spanish inverted punctuation and diacritics.
    class Spanish < Language::Base
      # Spanish spell checker with Hunspell integration.
      class SpellChecker < Components::SpellChecker
        attr_reader :aff_path, :dic_path, :script

        # Spanish-specific character substitutions
        SPANISH_SUBSTITUTIONS = {
          'á' => %w[a],
          'é' => %w[e],
          'í' => %w[i],
          'ó' => %w[o],
          'ú' => %w[u],
          'ü' => %w[u],
          'ñ' => %w[n],
          '¿' => [],
          '¡' => [],
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

          # Missing accents and ñ
          word.downcase.chars.each_with_index do |char, i|
            SPANISH_SUBSTITUTIONS.each do |accented, variants|
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
            next unless SPANISH_SUBSTITUTIONS.key?(char.downcase)

            SPANISH_SUBSTITUTIONS[char.downcase].each do |sub|
              next if sub.empty?

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

      # Spanish tokenizer with ordinal and decimal handling.
      class Tokenizer < Language::Tokenizer::SpanishTokenizer
      end

      # Spanish POS tagger.
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
          '¿' => 'PUNCT', '¡' => 'PUNCT', '?' => 'PUNCT', ';' => 'PUNCT', ':' => 'PUNCT'
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
          # Spanish suffix patterns
          return 'VERB' if suffix.match?(/^(ar|er|ir|ando|iendo|ado|ido|ó)$/)
          return 'ADV' if suffix.match?(/^(mente)$/)
          return 'NOUN' if suffix.match?(/^(ción|sión|miento|dad|eza|ismo|ista|or|nte|aje)$/)
          return 'ADJ' if suffix.match?(/%(oso|oso|able|ible|ble|ico|ica|ante)$/)

          nil
        end
      end

      # Spanish grammar rules module.
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

        # Rule: Inverted punctuation (¡, ¿)
        class InvertedPunctuationRule < Rule
          def initialize
            super('ES_INVERTED_PUNCTUATION', 'Inverted Punctuation', 'Spanish requires inverted punctuation marks (¡, ¿) at the start of exclamations/questions.')
          end

          def check(tokens)
            errors = []
            tokens.each_with_index do |token, idx|
              word = token[:token]
              next if word.nil? || word.empty?

              # Check for standard ? or ! without corresponding inverted marks
              if ['?', '!'].include?(word)
                # Look backwards to see if there's an inverted mark
                found_inverted = false
                (0...idx).reverse_each do |j|
                  check_token = tokens[j][:token]
                  if (word == '?' && check_token == '¿') || (word == '!' && check_token == '¡')
                    found_inverted = true
                    break
                  end
                  # Stop checking if we hit another sentence-ending punctuation
                  break if %w[. ? !].include?(check_token)
                end

                unless found_inverted
                  errors << {
                    rule_id: @id,
                    position: token[:position],
                    message: "Missing inverted punctuation mark: use '#{word == '?' ? '¿' : '¡'}' at the start",
                    suggestion: word == '?' ? '¿...?' : '¡...!',
                    context: word,
                    suggestions: [word == '?' ? '¿...?' : '¡...!']
                  }
                end
              end
            end
            errors
          end
        end

        # Rule: Gender agreement
        class GenderAgreementRule < Rule
          def initialize
            super('ES_GENDER_AGREEMENT', 'Gender Agreement', 'Nouns and adjectives must agree in gender.')
          end

          def check(_tokens)
            # Simplified implementation
            []
          end
        end

        class RuleRegistry
          class << self
            def default_rules
              [InvertedPunctuationRule.new, GenderAgreementRule.new]
            end

            def get_rule(id)
              default_rules.find { |rule| rule.id == id }
            end
          end
        end
      end

      # Registration
      register "es"
      register "es-ES"
      register "es-MX"
      register "es-AR"
      register "es-CO"
      register "es-PE"
      register "es-VE"
      register "es-CL"
      register "es-EC"
      register "es-GT"
      register "es-CU"
      register "es-BO"
      register "es-DO"
      register "es-HN"
      register "es-PY"
      register "es-SV"
      register "es-NI"
      register "es-CR"
      register "es-PA"
      register "es-UY"
      register "es-PR"

      HUNSPELL_DICTIONARIES = {
        'es-ES' => {
          aff: 'spec/integrational/fixtures/es_ES.aff',
          dic: 'spec/integrational/fixtures/es_ES.dic'
        },
        'es-MX' => {
          aff: 'spec/integrational/fixtures/es_MX.aff',
          dic: 'spec/integrational/fixtures/es_MX.dic'
        }
      }.freeze

      VARIANT_NAMES = {
        'ES' => 'European',
        'MX' => 'Mexican',
        'AR' => 'Argentinian',
        'CO' => 'Colombian',
        'PE' => 'Peruvian',
        'VE' => 'Venezuelan',
        'CL' => 'Chilean',
        'EC' => 'Ecuadorian',
        'GT' => 'Guatemalan',
        'CU' => 'Cuban',
        'BO' => 'Bolivian',
        'DO' => 'Dominican',
        'HN' => 'Honduran',
        'PY' => 'Paraguayan',
        'SV' => 'Salvadoran',
        'NI' => 'Nicaraguan',
        'CR' => 'Costa Rican',
        'PA' => 'Panamanian',
        'UY' => 'Uruguayan',
        'PR' => 'Puerto Rican'
      }.freeze

      def initialize(code: "es", name: "Spanish", variant: nil)
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
        when "es-ES"
          ["/usr/share/dict/spanish"]
        when "es-MX"
          ["/usr/share/dict/mexican"]
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
        HUNSPELL_DICTIONARIES[code] || HUNSPELL_DICTIONARIES['es-ES']
      end
    end
  end
end
