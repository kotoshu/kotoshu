# frozen_string_literal: true

module Kotoshu
  module Grammar
    # Sentence-level grammar checker: the public entry point of the
    # grammar engine (TODO.grammar/1 wiring).
    #
    # Segments text into sentences, tokenizes each with character
    # offsets, POS-tags the tokens, runs every enabled rule, and maps
    # matched tokens to character spans.
    #
    # @example
    #   checker = Grammar::Checker.new(language: "en")
    #   checker.check("He go to school. They was late.")
    #   # => [{ rule_id: "EN_SV_AGREEMENT_3SG", start_offset: 0, ... }, ...]
    class Checker
      SENTENCE = /[^.!?]+[.!?]*/
      TOKEN = /[[:word:]'-]+|[.,!?;:()"\/]/
      CLITIC = /\A(.*?)(n't|'s|'t|'re|'ve|'ll|'d|'m)\z/i

      # @param language [String] language code
      # @param rules [Array<PatternRule, Rule>, nil] explicit rules;
      #   defaults to the gem-bundled rules for the language
      # @param include_disabled [Boolean] load rules marked default: off
      # @param tagger [Tagger, nil] the neural closed-class detector —
      #   the residual pass behind the rules (the hybrid architecture)
      def initialize(language: "en", rules: nil, include_disabled: false, tagger: nil)
        @language = language
        @include_disabled = include_disabled
        @rules = rules || load_rules
        @tagger = tagger
      end

      # Check text and return grammar errors with character offsets.
      #
      # @param text [String] the document text
      # @return [Array<Hash>] error hashes (rule_id, start_offset,
      #   end_offset, target_word, tokens, message, suggestions, sentence)
      def check(text)
        return [] if text.nil? || text.empty?

        errors = []
        each_sentence(text) do |sentence, offset|
          tokens = tagged_tokens(tokenize_with_offsets(sentence, offset))
          next if tokens.empty?

          covered = {}
          @rules.each do |rule|
            rule.check(tokens).each do |error|
              (error[:start_index]..error[:end_index]).each { |i| covered[i] = true }
              errors << spanned_error(error, tokens, sentence)
            end
          end
          next if @tagger.nil?

          # The hybrid residual: the tagger catches what the rules
          # missed; fixes come from the class deterministically.
          words = tokens.map { |t| t[:word] }
          @tagger.detect(words).each do |finding|
            next if covered[finding[:index]]

            token = tokens[finding[:index]]
            next if token.nil?

            errors << {
              rule_id: finding[:label],
              type: "neural",
              start_offset: token[:start_offset],
              end_offset: token[:end_offset],
              target_word: token[:word],
              tokens: [token[:word]],
              message: @tagger.message_for(finding[:label]),
              suggestions: @tagger.fix_for(finding[:label], token[:word]),
              sentence: sentence
            }
          end
        end
        errors
      end

      # The loaded rule set (for introspection and tooling).
      #
      # @return [Array<PatternRule, Rule>]
      attr_reader :rules

      # The gem-bundled rules directory for a language.
      #
      # @param language [String]
      # @return [String]
      def self.rules_path_for(language)
        File.expand_path("rules/#{language}", __dir__)
      end

      private

      def load_rules
        path = self.class.rules_path_for(@language)
        engine = RuleEngine.new(language: @language, rules_path: path)
        @include_disabled ? engine.rules : engine.rules.select(&:enabled?)
      end

      def each_sentence(text)
        text.scan(SENTENCE) do
          match = Regexp.last_match
          yield match[0], match.begin(0)
        end
      end

      # Tokens with :start_offset/:end_offset; clitics split with
      # exact character spans ("Valentine's" → two tokens).
      def tokenize_with_offsets(sentence, base)
        [].tap do |tokens|
          sentence.scan(TOKEN) do
            match = Regexp.last_match
            word = match[0]
            start = match.begin(0) + base
            finish = match.end(0) + base - 1
            split = word.match(CLITIC)
            if split && split[1].length >= 2
              split_at = split[1].length
              tokens << token(word[0, split_at], start, start + split_at - 1, tokens.length, sentence)
              tokens << token(word[split_at..], start + split_at, finish, tokens.length, sentence)
            else
              tokens << token(word, start, finish, tokens.length, sentence)
            end
          end
        end
      end

      def token(word, start_offset, end_offset, index, sentence)
        { word: word, start_offset: start_offset, end_offset: end_offset,
          index: index, sentence: sentence }
      end

      # Attach POS tags from the shared tagger so the matchers consume
      # the offset-bearing tokens untouched.
      def tagged_tokens(tokens)
        return tokens if tokens.empty?

        tagged = PosTagger.new.tag(tokens.map { |t| t[:word] }.join(" "))
        return tokens if tagged.length != tokens.length

        tokens.each_with_index do |tok, i|
          tok[:pos] = tagged[i][:pos]
        end
        tokens
      end

      # Map a matcher error (token indices) to character offsets.
      def spanned_error(error, tokens, sentence)
        start = tokens[error[:start_index]] || tokens.first
        stop = tokens[error[:end_index]] || tokens.last
        {
          rule_id: error[:rule_id],
          type: error[:type],
          start_offset: start ? start[:start_offset] : 0,
          end_offset: stop ? stop[:end_offset] : 0,
          target_word: error[:target_word],
          tokens: error[:tokens],
          message: error[:message],
          suggestions: error[:suggestions],
          sentence: sentence
        }
      end
    end
  end
end
