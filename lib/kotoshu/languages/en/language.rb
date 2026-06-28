# frozen_string_literal: true

require_relative '../../readers/lookup_builder'
require_relative '../../components/spell_checker'
require_relative '../../components/whitespace_tokenizer'
require_relative '../../components/pos_tagger'
require_relative '../../language/normalizer/base'
require_relative '../../grammar'

module Kotoshu
  module Languages
    # English language implementation.
    #
    # Supports multiple dialects: en-US, en-GB, en-AU, en-CA, en-NZ, en-ZA
    #
    # @example American English
    #   lang = Kotoshu::Languages::English.new(code: "en-US")
    #   checker = lang.create_spell_checker
    #   checker.correct?("color")    # => true
    #   checker.correct?("colour")   # => false
    #
    # @example British English
    #   lang = Kotoshu::Languages::English.new(code: "en-GB")
    #   checker.correct?("colour")   # => true
    class English < Language::Base
      # English spell checker.
      #
      # Uses the Lookup algorithm with Hunspell-format dictionaries.
      class SpellChecker < Components::SpellChecker
        attr_reader :aff_path, :dic_path, :script

        def initialize(aff_path:, dic_path:, script: :latin, encoding: 'ISO-8859-1')
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
          common_substitutions = {
            'a' => %w[e i o u],
            'e' => %w[a i o u],
            'i' => %w[a e o u],
            'o' => %w[a e i u],
            'u' => %w[a e i o],
            's' => %w[z c],
            'z' => %w[s],
            'c' => %w[k s],
            'k' => %w[c],
            'ph' => %w[f],
            'f' => %w[ph]
          }
          word.chars.each_with_index do |char, i|
            next unless common_substitutions.key?(char.downcase)

            common_substitutions[char.downcase].each do |sub|
              substituted = word.dup
              substituted[i] = sub
              variations << substituted if @lookuper.good_forms(substituted).first
            end
          end
          variations.uniq!
          variations.map do |suggestion|
            { word: suggestion, distance: calculate_distance(word, suggestion),
              score: calculate_score(word, suggestion, 0) }
          end.sort_by { |s| s[:distance] }
        end
      end

      # English tokenizer with contraction handling.
      class Tokenizer < Components::WhitespaceTokenizer
        CONTRACTIONS = {
          "n't" => ['not', 'NEG'],
          "'ll" => ['will', 'MD'],
          "'ve" => ['have', 'VBP'],
          "'re" => ['are', 'VBP'],
          "'m" => ['am', 'VBP'],
          "'d" => ['would', 'MD'],
          "'s" => ['is', 'VBZ'],
          "'clock" => ['of', 'IN'],
        }.freeze
        WONT_EXCEPTION = { "won't" => ['will', 'not'] }.freeze
        CANT_EXCEPTION = { "can't" => ['can', "'t"] }.freeze
        POSSESSIVE_PATTERN = /([A-Za-z]+)('s)(?=[A-Za-z]|$)/
        CONTRACTION_WITH_S = %w[it he that what who there].freeze

        def initialize(expand_contractions: true)
          super()
          @expand_contractions = expand_contractions
        end

        def tokenize(text)
          return [] if text.nil? || text.empty?

          tokens = super
          if @expand_contractions
            tokens = expand_contractions(tokens)
          end
          tokens
        end

        private

        def expand_contractions(tokens)
          result = []
          i = 0
          while i < tokens.length
            token = tokens[i]
            if token[:token] == "won't"
              result << { token: 'will', position: token[:position], length: 5 }
              result << { token: 'not', position: token[:position] + 5, length: 3 }
              i += 1
              next
            end
            if token[:token] == "can't"
              result << { token: 'can', position: token[:position], length: 3 }
              result << { token: "'t", position: token[:position] + 3, length: 2 }
              i += 1
              next
            end
            expanded = expand_single_contraction(token)
            if expanded
              result.concat(expanded)
            else
              result << token
            end
            i += 1
          end
          result
        end

        def expand_single_contraction(token)
          word = token[:token]
          if POSSESSIVE_PATTERN.match?(word)
            base = word[0..-3]
            if CONTRACTION_WITH_S.include?(base.downcase)
              return [{ token: base, position: token[:position], length: base.length },
                      { token: "'s", position: token[:position] + base.length, length: 2 }]
            else
              return [{ token: base, position: token[:position], length: base.length },
                      { token: "'s", position: token[:position] + base.length, length: 2 }]
            end
          end
          CONTRACTIONS.each do |suffix, _expansion|
            next if ["'s", "'clock"].include?(suffix)

            if word.end_with?(suffix) && word.length > suffix.length
              prefix = word[0...-suffix.length]
              return [{ token: prefix, position: token[:position], length: prefix.length },
                      { token: suffix, position: token[:position] + prefix.length, length: suffix.length }]
            end
          end
          nil
        end
      end

      # English POS tagger.
      class POSTagger < Components::PosTagger
        FLAG_TO_POS = {
          'N' => 'NOUN', 'NN' => 'NOUN', 'NNS' => 'NOUN', 'NNP' => 'NOUN', 'NP' => 'NOUN_PROPER',
          'V' => 'VERB', 'VB' => 'VERB', 'VBD' => 'VERB', 'VBG' => 'VERB', 'VBN' => 'VERB',
          'VBP' => 'VERB', 'VBZ' => 'VERB', 'MD' => 'VERB_MODAL',
          'A' => 'ADJ', 'JJ' => 'ADJ', 'JJR' => 'ADJ', 'JJS' => 'ADJ',
          'R' => 'ADV', 'RB' => 'ADV', 'RBR' => 'ADV', 'RBS' => 'ADV',
          'D' => 'DET', 'DT' => 'DET', 'PDT' => 'DET',
          'P' => 'PRON', 'PP' => 'PRON', 'PRP' => 'PRON', 'PRP$' => 'PRON_POSS',
          'WP' => 'PRON', 'WP$' => 'PRON_POSS',
          'I' => 'PREP', 'IN' => 'PREP',
          'C' => 'CONJ', 'CC' => 'CONJ',
          'U' => 'PART', 'RP' => 'PART',
          'INTJ' => 'INTJ', 'UH' => 'INTJ',
          'CD' => 'NUM', 'FW' => 'X',
          'PUNCT' => 'PUNCT', '.' => 'PUNCT', ',' => 'PUNCT', '!' => 'PUNCT',
          '?' => 'PUNCT', ';' => 'PUNCT', ':' => 'PUNCT'
        }.freeze

        attr_reader :aff_path, :dic_path, :script

        def initialize(aff_path:, dic_path:, script: :latin, encoding: 'ISO-8859-1', flag_mapping: FLAG_TO_POS)
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
          if suffix
            # suffix is a Hash with :add, :strip, :type keys
            suffix_text = suffix[:add] || suffix['add']
            return guess_pos_from_suffix(suffix_text) if suffix_text
          end
          prefix = result.prefix
          return nil unless prefix

          nil
        end

        def guess_pos_from_suffix(suffix)
          return nil unless suffix.is_a?(String)
          return 'VERB' if suffix.match?(/^(ing|ed|es|s)$/)
          return 'ADV' if suffix.end_with?('ly')
          return 'NOUN' if suffix.match?(/^(tion|sion|ment|ness|ity|ship|er|or|ist)$/)
          return 'ADJ' if suffix.match?(/^(able|ible|al|ial|ic|ive|ful|less|ous)$/)

          nil
        end
      end

      # Registration and configuration
      register "en"
      register "en-US"
      register "en-GB"
      register "en-AU"
      register "en-CA"
      register "en-NZ"
      register "en-ZA"

      HUNSPELL_DICTIONARIES = {
        'en-US' => {
          aff: 'spec/integrational/fixtures/en_US.aff',
          dic: 'spec/integrational/fixtures/en_US.dic'
        },
      }.freeze

      VARIANT_NAMES = {
        'US' => 'American',
        'GB' => 'British',
        'CA' => 'Canadian',
        'AU' => 'Australian',
        'NZ' => 'New Zealand',
        'ZA' => 'South African'
      }.freeze

      def initialize(code: "en", name: "English", variant: nil)
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
        when "en-GB", "en-AU", "en-NZ", "en-ZA"
          ["/usr/share/dict/british-english"]
        when "en-US", "en-CA"
          ["/usr/share/dict/american-english"]
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
          flag_mapping: english_pos_flag_mapping
        )
      end

      def create_grammar_rules
        Grammar::RuleEngine.new(language: 'en')
      end

      def valid_in_other_variant?(word)
        return nil if @variant.nil? || @code == 'en'

        HUNSPELL_DICTIONARIES.each do |variant_code, paths|
          next if variant_code == @code
          next unless File.exist?(paths[:aff]) && File.exist?(paths[:dic])

          checker = SpellChecker.new(aff_path: paths[:aff], dic_path: paths[:dic], script: :latin,
                                     encoding: 'ISO-8859-1')
          if checker.correct?(word)
            region = variant_code.split('-').last.upcase
            variant_name = VARIANT_NAMES[region] || variant_code
            return { variant: variant_name, code: "en-#{region}" }
          end
        end
        nil
      end

      private

      def extract_region_code(code)
        return nil unless code.include?("-")

        code.split("-", 2).last.upcase
      end

      def resolve_hunspell_paths(code)
        HUNSPELL_DICTIONARIES[code] || HUNSPELL_DICTIONARIES['en-US']
      end

      def english_pos_flag_mapping
        mappings = POSTagger::FLAG_TO_POS.dup
        mappings.merge!(
          'VBD' => 'VERB', 'VBG' => 'VERB', 'VBN' => 'VERB',
          'VBP' => 'VERB', 'VBZ' => 'VERB',
          'DT' => 'DET', 'WDT' => 'DET',
          'PRP' => 'PRON', 'PRP$' => 'PRON_POSS',
          'WP' => 'PRON', 'WP$' => 'PRON_POSS'
        )
      end
    end
  end
end
