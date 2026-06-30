# frozen_string_literal: true

module Kotoshu
  # Multi-language document checker.
  #
  # Splits a {Documents::Document} into language-tagged segments via
  # {Language::Segmenter}, resolves a {Spellchecker} for each
  # segment's detected language, and emits a flat list of
  # {Models::SemanticError}s carrying source_range from the original
  # document. The result is one sorted stream of errors that editors
  # / plugins can highlight without caring that the document mixed
  # languages.
  #
  # Real documents mix languages routinely: code comments in English
  # embedded in French prose, a Japanese paper with an English
  # abstract, German quotes in a Spanish essay. Without per-segment
  # detection, every word from the "other" language is reported as a
  # spelling error against the wrong dictionary.
  class MultiLanguageChecker
    # @return [Language::Segmenter]
    attr_reader :segmenter

    # @return [Hash{String => Spellchecker}] per-language cache so
    #   repeated segments of the same language reuse the same checker
    attr_reader :spellcheckers

    # @param segmenter [Language::Segmenter, nil] defaults to a new
    #   Segmenter with the default Detector
    def initialize(segmenter: nil)
      @segmenter = segmenter || Language::Segmenter.new
      @spellcheckers = {}
    end

    # Check a document, returning one sorted stream of errors across
    # every detected language. Errors carry source_range resolved via
    # the document's text-node mapping.
    #
    # @param document [Kotoshu::Documents::Document]
    # @return [Array<Models::SemanticError>]
    def check(document)
      unless document.is_a?(Kotoshu::Documents::Document)
        raise ArgumentError,
              "document must be a Kotoshu::Documents::Document"
      end

      @segmenter.segment(document).flat_map do |segment|
        check_segment(segment, document)
      end.sort
    end

    private

    # Check one segment: resolve (or reuse) a Spellchecker for the
    # segment's language, walk its text nodes, and build errors with
    # source_range for every unknown word that has at least one
    # suggestion.
    def check_segment(segment, document)
      checker = spellchecker_for(segment.language_code)
      return [] unless checker

      errors = []
      segment.text_nodes.each do |node|
        tokenize_with_offsets(node.text).each do |word, offset_in_node|
          next if checker.correct?(word)

          suggestions = checker.suggest(word).to_a
          next if suggestions.empty?

          flattened_start = node.flattened_offset + offset_in_node
          flattened_end = flattened_start + word.length
          source_range = document.source_range_for(flattened_start, flattened_end)
          errors << build_error(word, suggestions, source_range, segment.language_code)
        end
      end
      errors
    end

    # Resolve a Spellchecker for a language code, memoized per
    # process. Returns nil when the language isn't set up — callers
    # silently skip unknown-language segments rather than crashing.
    def spellchecker_for(language_code)
      return @spellcheckers[language_code] if @spellcheckers.key?(language_code)

      @spellcheckers[language_code] = begin
        bundle = ResourceManager.resolve(language: language_code, want: %i[spelling])
        Spellchecker.new(resource_bundle: bundle)
      rescue StandardError
        nil
      end
    end

    # Build a SemanticError. Uses the orthographic error type (this
    # is a spelling check, not a grammar check). Confidence is a
    # fixed 0.5 (medium) since we don't compute real confidence here.
    def build_error(word, suggestions, source_range, language_code)
      Models::SemanticError.new(
        id: Digest::SHA256.hexdigest("#{language_code}-#{word}-#{source_range}")[0...16],
        source_range: source_range,
        original: word,
        suggestions: wrap_suggestions(suggestions),
        error_type: :orthographic,
        confidence: 0.5,
        context: nil
      )
    end

    # Wrap raw suggestion strings into Models::Suggestion objects so
    # the SemanticError invariant (array of Suggestion) is satisfied.
    def wrap_suggestions(words)
      words.first(5).map do |word|
        Models::Suggestion.new(word, confidence: 0.5, source: :multi_language)
      end
    end

    # Tokenize +text+ into [word, char_offset] pairs.
    def tokenize_with_offsets(text)
      return [] unless text

      text.scan(/[a-zà-ÿ]+(?:['’-][a-zà-ÿ]+)*/i).map do |match|
        [match.downcase, Regexp.last_match.offset(0).first]
      end
    end
  end
end
