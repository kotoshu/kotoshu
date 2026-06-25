# frozen_string_literal: true

require_relative '../../readers/lookup_builder'
require_relative '../../components/spell_checker'
require_relative '../../components/pos_tagger'
require_relative '../../language/normalizer/base'

module Kotoshu
  module Languages
    # French language implementation.
    #
    # Supports multiple dialects: fr-FR, fr-CA, fr-BE, fr-CH, fr-LU, fr-MC
    #
    # Full Hunspell integration with spell checking, POS tagging, and grammar rules.
    class French < Language::Base
      # French spell checker with Hunspell integration.
      #
      # Uses the Lookup algorithm with Hunspell-format dictionaries
      # and French-specific character handling (accents, ligatures).
      class SpellChecker < Components::SpellChecker
        attr_reader :aff_path, :dic_path, :script

        # French-specific character substitutions for suggestions
        FRENCH_SUBSTITUTIONS = {
          'à' => %w[a],
          'â' => %w[a],
          'ä' => %w[a],
          'é' => %w[e],
          'è' => %w[e],
          'ê' => %w[e],
          'ë' => %w[e],
          'î' => %w[i],
          'ï' => %w[i],
          'ô' => %w[o],
          'ö' => %w[o],
          'ù' => %w[u],
          'û' => %w[u],
          'ü' => %w[u],
          'ç' => %w[c],
          'œ' => %w[oe],
          'æ' => %w[ae],
          # Common French errors
          'c' => %w[ç],  # garçon vs garcon
          'e' => %w[é è ê],  # café vs caffe
          'a' => %w[à],  # à vs a
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

        def calculate_score(original, suggestion, rank)
          distance = calculate_distance(original, suggestion)
          max_len = [original.length, suggestion.length].max
          distance_score = 1.0 - (distance.to_f / max_len)
          rank_penalty = rank * 0.05
          [distance_score - rank_penalty, 0.0].max
        end

        def generate_suggestions(word, max_suggestions)
          variations = []

          # Missing accents
          word.downcase.chars.each_with_index do |char, i|
            FRENCH_SUBSTITUTIONS.each do |accented, unaccented_variants|
              unaccented_variants.each do |variant|
                if char == variant
                  unaccented_word = word.dup
                  unaccented_word[i] = accented
                  variations << unaccented_word if @lookuper.good_forms(unaccented_word).first
                end
              end
            end
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

          # Common substitutions
          word.chars.each_with_index do |char, i|
            next unless FRENCH_SUBSTITUTIONS.key?(char.downcase)
            FRENCH_SUBSTITUTIONS[char.downcase].each do |sub|
              substituted = word.dup
              substituted[i] = sub
              variations << substituted if @lookuper.good_forms(substituted).first
            end
          end

          variations.uniq!
          variations.map do |suggestion|
            { word: suggestion, distance: calculate_distance(word, suggestion), score: calculate_score(word, suggestion, 0) }
          end.sort_by { |s| s[:distance] }
        end
      end

      # French tokenizer with contraction handling.
      class Tokenizer < Language::Tokenizer::FrenchTokenizer
      end

      # French POS tagger.
      #
      # Derives POS tags from Hunspell flags using French-specific mappings.
      class POSTagger < Components::PosTagger
        # French POS flag mappings based on Hunspell French dictionaries
        FLAG_TO_POS = {
          # Nouns
          'N' => 'NOUN', 'NN' => 'NOUN', 'NNS' => 'NOUN', 'NNP' => 'NOUN_PROPER',
          # Verbs
          'V' => 'VERB', 'VB' => 'VERB', 'VBD' => 'VERB', 'VBG' => 'VERB', 'VBN' => 'VERB',
          'VBP' => 'VERB', 'VBZ' => 'VERB',
          # Adjectives
          'A' => 'ADJ', 'JJ' => 'ADJ', 'JJR' => 'ADJ', 'JJS' => 'ADJ',
          # Adverbs
          'R' => 'ADV', 'RB' => 'ADV', 'RBR' => 'ADV', 'RBS' => 'ADV',
          # Determiners
          'D' => 'DET', 'DT' => 'DET', 'PDT' => 'DET',
          # Pronouns
          'P' => 'PRON', 'PP' => 'PRON', 'PRP' => 'PRON', 'PRP$' => 'PRON_POSS',
          'WP' => 'PRON', 'WP$' => 'PRON_POSS',
          # Prepositions
          'I' => 'PREP', 'IN' => 'PREP',
          # Conjunctions
          'C' => 'CONJ', 'CC' => 'CONJ',
          # Particles
          'U' => 'PART', 'RP' => 'PART',
          # Interjections
          'INTJ' => 'INTJ', 'UH' => 'INTJ',
          # Numbers
          'CD' => 'NUM',
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
          # French suffix patterns
          return 'VERB' if suffix.match?(/^(er|ir|re|is|it|issent|issons|issez)$/)
          return 'ADV' if suffix.end_with?('ment')
          return 'NOUN' if suffix.match?(/^(tion|sion|ment|age|ure|ée|ée)$/)
          return 'ADJ' if suffix.match?(/^(if|ive|eux|euse|able|ible)$/)
          nil
        end
      end

      # French grammar rules module.
      module GrammarRules
        # Base class for French grammar rules.
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

          def applies?(tokens, index)
            true
          end
        end

        # Rule: Article agreement with gender/number.
        class ArticleAgreementRule < Rule
          MASCULINE_SINGULAR = %w[le un].freeze
          FEMININE_SINGULAR = %w[la une].freeze
          PLURAL = %w[les des].freeze

          def initialize
            super('FR_ARTICLE_AGREEMENT', 'Article Agreement', 'Articles must agree with noun gender and number.')
          end

          def check(tokens)
            errors = []
            tokens.each_cons(2) do |article_token, noun_token|
              article = article_token[:token]&.downcase
              next unless MASCULINE_SINGULAR.include?(article) ||
                          FEMININE_SINGULAR.include?(article) ||
                          PLURAL.include?(article)

              # This is a simplified check - full implementation would need dictionary lookup
              # for gender/number information
              next unless article_token[:pos_tag] == 'DET'

              noun = noun_token[:token]
              # Check for common patterns
              if noun&.end_with?('e') && MASCULINE_SINGULAR.include?(article)
                # Possibly incorrect: masculine article with feminine-looking noun
                errors << {
                  rule_id: @id,
                  position: article_token[:position],
                  message: "Article agreement: check if '#{noun}' is feminine",
                  suggestion: nil,
                  context: "#{article} #{noun}",
                  suggestions: ['la', 'une']
                }
              end
            end
            errors
          end
        end

        # Rule: Double negation in French (correct usage).
        class FrenchNegationRule < Rule
          NEGATION_PARTICLES = %w[ne n'].freeze
          SECOND_PARTICLES = %w[pas plus jamais rien personne].freeze

          def initialize
            super('FR_NEGATION', 'French Negation', 'French uses double negation (ne...pas).')
          end

          def check(tokens)
            errors = []
            tokens.each_with_index do |token, idx|
              word = token[:token]&.downcase
              next unless NEGATION_PARTICLES.include?(word)

              # Check if second negation particle exists within reasonable distance
              found_second = false
              ((idx + 1)...[idx + 5, tokens.length].min).each do |j|
                next_word = tokens[j][:token]&.downcase
                if SECOND_PARTICLES.include?(next_word)
                  found_second = true
                  break
                end
              end

              unless found_second
                errors << {
                  rule_id: @id,
                  position: token[:position],
                  message: "Incomplete negation: French requires double negation (ne...pas)",
                  suggestion: 'Add pas or another negation particle',
                  context: word,
                  suggestions: ['ne...pas', 'ne...pas']
                }
              end
            end
            errors
          end
        end

        # Rule registry for French.
        class RuleRegistry
          class << self
            def default_rules
              [ArticleAgreementRule.new, FrenchNegationRule.new]
            end

            def get_rule(id)
              default_rules.find { |rule| rule.id == id }
            end
          end
        end
      end

      # Registration
      register "fr"
      register "fr-FR"
      register "fr-CA"
      register "fr-BE"
      register "fr-CH"
      register "fr-LU"
      register "fr-MC"

      HUNSPELL_DICTIONARIES = {
        'fr-FR' => {
          aff: 'spec/integrational/fixtures/fr_FR.aff',
          dic: 'spec/integrational/fixtures/fr_FR.dic'
        },
        'fr-CA' => {
          aff: 'spec/integrational/fixtures/fr_CA.aff',
          dic: 'spec/integrational/fixtures/fr_CA.dic'
        }
      }.freeze

      VARIANT_NAMES = {
        'FR' => 'France',
        'CA' => 'Canadian',
        'BE' => 'Belgian',
        'CH' => 'Swiss',
        'LU' => 'Luxembourgish',
        'MC' => 'Monégasque'
      }.freeze

      def initialize(code: "fr", name: "French", variant: nil)
        variant ||= extract_region_code(code)
        super(code: code, name: name, variant: variant)
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
        when "fr-FR"
          ["/usr/share/dict/french"]
        when "fr-CA"
          ["/usr/share/dict/french-CA"]
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
        HUNSPELL_DICTIONARIES[code] || HUNSPELL_DICTIONARIES['fr-FR']
      end
    end
  end
end
