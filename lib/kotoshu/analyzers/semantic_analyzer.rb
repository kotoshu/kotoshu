# frozen_string_literal: true

module Kotoshu
  module Analyzers
    # Unified semantic error analyzer.
    #
    # Uses word embeddings for context-aware error detection and suggestions.
    # Provides unified semantic analysis without artificial spelling/grammar split.
    #
    # @example Analyzing a document
    #   model = FastTextModel.from_github('en')
    #   analyzer = SemanticAnalyzer.new(model)
    #   errors = analyzer.analyze(document)
    #
    # @example Checking a single word
    #   suggestions = analyzer.suggest_corrections('helo', context_words: ['hello', 'world'])
    class SemanticAnalyzer
      # Similarity threshold for high-confidence suggestions
      HIGH_CONFIDENCE_THRESHOLD = 0.85

      # Similarity threshold for medium-confidence suggestions
      MEDIUM_CONFIDENCE_THRESHOLD = 0.70

      # Minimum similarity for suggestions
      MIN_SIMILARITY = 0.50

      # Default number of suggestions to generate
      DEFAULT_MAX_SUGGESTIONS = 5

      attr_reader :model, :max_suggestions

      # Create a new semantic analyzer.
      #
      # @param model [EmbeddingModel] The embedding model to use
      # @param max_suggestions [Integer] Maximum suggestions per error
      # @param min_similarity [Float] Minimum similarity threshold
      def initialize(model, max_suggestions: DEFAULT_MAX_SUGGESTIONS, min_similarity: MIN_SIMILARITY)
        raise ArgumentError, "Model must be an EmbeddingModel" unless model.is_a?(Models::EmbeddingModel)

        @model = model
        @max_suggestions = max_suggestions
        @min_similarity = min_similarity
      end

      # Analyze a {Kotoshu::Documents::Document} for semantic errors.
      #
      # Walks every {Documents::TextNode}, tokenizes its text, and for
      # each invalid word resolves a {Documents::SourceRange} via
      # `document.source_range_for` so the emitted {Models::SemanticError}
      # points at the original markup-bearing source rather than the
      # flattened text. Context for ranking is built from the
      # surrounding flattened text.
      #
      # @param document [Kotoshu::Documents::Document]
      # @return [Array<Models::SemanticError>] Sorted by source_range
      def analyze(document)
        unless document.is_a?(Kotoshu::Documents::Document)
          raise ArgumentError,
                "document must be a Kotoshu::Documents::Document"
        end

        errors = []
        flattened = document.flattened_text

        document.text_nodes.each do |text_node|
          tokenize_with_offsets(text_node.text).each do |word, offset_in_node|
            next if valid_word?(word)

            flattened_start = text_node.flattened_offset + offset_in_node
            flattened_end = flattened_start + word.length
            source_range = document.source_range_for(flattened_start, flattened_end)
            context = build_context(flattened, flattened_start, flattened_end)

            error = detect_error(word: word, source_range: source_range, context: context)
            errors << error if error
          end
        end

        errors.sort
      end

      # Detect semantic error for a single word.
      #
      # @param word [String] The word to check
      # @param source_range [Kotoshu::Documents::SourceRange, nil] Where
      #   the word lives in the original source. May be nil for
      #   word-level checks that aren't tied to a document.
      # @param context [Models::Context, nil] Context around the word
      # @return [Models::SemanticError, nil] Error object or nil if valid
      def detect_error(word:, source_range: nil, context: nil)
        return nil if valid_word?(word)

        suggestions = suggest_corrections(word, context: context)
        error_type = classify_error(word, suggestions, context)
        confidence = calculate_confidence(suggestions)

        Models::SemanticError.new(
          id: generate_error_id(word, source_range),
          source_range: source_range,
          original: word,
          suggestions: suggestions,
          error_type: error_type,
          confidence: confidence,
          context: context
        )
      rescue Models::EmptySuggestionsError
        # Word is genuinely unknown — no close matches. Skip silently
        # rather than crashing on the suggestions-cannot-be-empty
        # invariant.
        nil
      end

      # Suggest corrections for a word.
      #
      # For in-vocabulary words the embedding model returns the
      # nearest neighbors. For OOV words (the typical "misspelling"
      # case the analyzer exists to catch) the embedding model returns
      # +[]+ because it has no vector for the input. We fall back to
      # an edit-distance walk over the model's vocabulary so the OOV
      # case still produces useful candidates that the rest of the
      # pipeline (confidence scoring, context ranking) can refine.
      #
      # @param word [String] The misspelled word
      # @param context [Models::Context, nil] Context for context-aware suggestions
      # @return [Array<Models::Suggestion>] Suggested corrections
      def suggest_corrections(word, context: nil)
        return [] if word.nil? || word.empty?

        neighbors = @model.nearest_neighbors(word, k: @max_suggestions * 3)
        neighbors = edit_distance_fallback(word) if neighbors.empty?

        # Filter by minimum similarity
        neighbors = neighbors.select { |n| n.similarity >= @min_similarity }

        # If we have context, rank by contextual relevance
        if context.is_a?(Kotoshu::Models::Context)
          neighbors = rank_by_context(neighbors, context)
        end

        # Convert to Suggestions
        neighbors.first(@max_suggestions).map do |neighbor|
          Models::Suggestion.new(
            neighbor.word,
            confidence: neighbor.similarity,
            source: :semantic,
            metadata: {
              distance: neighbor.distance,
              similarity: neighbor.similarity
            }
          )
        end
      end

      # Check if a word is valid (exists in vocabulary).
      #
      # @param word [String] The word to check
      # @return [Boolean] True if word is valid
      def valid_word?(word)
        return false if word.nil? || word.empty?

        # Skip numbers
        return true if /^\d+$/.match?(word)

        # Skip single characters (likely abbreviations)
        return true if word.length == 1

        # Check if word exists in model vocabulary
        @model.has_word?(word)
      end

      # Calculate confidence score for suggestions.
      #
      # @param suggestions [Array<Models::Suggestion>] List of suggestions
      # @return [Float] Confidence score (0.0 to 1.0)
      def calculate_confidence(suggestions)
        return 0.0 unless suggestions&.any?

        # Confidence is based on top suggestion quality
        top = suggestions.first

        # High confidence: top suggestion > 0.85 similarity
        return 1.0 if top.confidence > HIGH_CONFIDENCE_THRESHOLD

        # Medium confidence: top suggestion > 0.70 similarity
        return 0.7 if top.confidence > MEDIUM_CONFIDENCE_THRESHOLD

        # Low confidence: top suggestion < 0.70
        0.5
      end

      private

      # Fallback for OOV words: walk the model's vocabulary and return
      # candidates within edit distance 2. Scored by 1/(1+distance) so
      # distance-1 matches rank above distance-2 matches. Mirrors the
      # shape {EmbeddingModel#nearest_neighbors} returns
      # (+NearestNeighbor+ instances with +similarity+ in [0, 1]).
      #
      # @param word [String] OOV query word
      # @return [Array<Models::NearestNeighbor>]
      def edit_distance_fallback(word)
        vocab = @model.vocabulary
        return [] unless vocab&.any?

        downcased = word.downcase
        candidates = vocab.each_with_object([]) do |candidate, acc|
          next if candidate == word || candidate.downcase == downcased

          distance = levenshtein(downcased, candidate.downcase)
          next unless distance.positive? && distance <= 2

          acc << Models::NearestNeighbor.new(
            word: candidate,
            similarity: 1.0 / (1.0 + distance),
            distance: distance,
            embedding: nil
          )
        end

        candidates.sort.first(@max_suggestions * 3)
      end

      # Two-row Levenshtein edit distance.
      def levenshtein(a, b)
        return b.length if a.empty?
        return a.length if b.empty?

        prev = (0..b.length).to_a
        a.each_char.with_index do |achar, i|
          curr = [i + 1]
          b.each_char.with_index do |bchar, j|
            cost = achar == bchar ? 0 : 1
            curr << [curr[j] + 1, prev[j + 1] + 1, prev[j] + cost].min
          end
          prev = curr
        end
        prev.last
      end

      # Tokenize text into [word, offset_in_text] pairs. The offset
      # is the 0-based character position of the word's first char
      # within +text+. Used by {#analyze} to compute flattened offsets
      # for source-range resolution.
      #
      # @param text [String]
      # @return [Array<Array(String, Integer)>]
      def tokenize_with_offsets(text)
        return [] unless text

        text.downcase.scan(/[a-z]+(?:['’-][a-z]+)*/i).map do |match|
          char_offset = Regexp.last_match.offset(0).first
          [match.downcase, char_offset]
        end
      end

      # Tokenize text into words. Kept for backward compat with specs.
      #
      # @param text [String] Text to tokenize
      # @return [Array<String>] Words
      def tokenize_words(text)
        tokenize_with_offsets(text).map(&:first)
      end

      # Build a {Models::Context} around a flattened-text range.
      # Slices up to 32 chars before and after the [start, end) range,
      # rounding at whitespace so the context reads naturally.
      #
      # @param flattened [String]
      # @param flattened_start [Integer]
      # @param flattened_end [Integer]
      # @return [Models::Context, nil] nil when the slice is empty
      def build_context(flattened, flattened_start, flattened_end)
        return nil if flattened.nil? || flattened.empty?

        window = 32
        before_start = [flattened_start - window, 0].max
        after_end = [flattened_end + window, flattened.length].min
        before = flattened[before_start...flattened_start] || ""
        current = flattened[flattened_start...flattened_end] || ""
        after = flattened[flattened_end...after_end] || ""
        return nil if current.empty?

        Models::Context.new(
          before: before,
          current: current,
          after: after,
          location: nil
        )
      end

      # Classify error type based on word and suggestions.
      #
      # @param word [String] The error word
      # @param suggestions [Array<Models::Suggestion>] Suggestions
      # @param context [Models::Context, nil] Context
      # @return [Symbol] Error type
      def classify_error(word, suggestions, _context)
        return :orthographic if suggestions && suggestions.empty?

        top_suggestion = suggestions.first

        # Check if it's a capitalization error
        if word.downcase == top_suggestion.word.downcase
          return :capitalization
        end

        # Check if it's a diacritic/accent error
        if similar_without_diacritics?(word, top_suggestion.word)
          return :orthographic
        end

        # Check if it's a word choice error (semantic similarity but different word)
        if suggestions.first&.source == "semantic"
          return :word_choice
        end

        # Default to orthographic (spelling)
        :orthographic
      end

      # Check if two words are similar ignoring diacritics.
      #
      # @param word1 [String] First word
      # @param word2 [String] Second word
      # @return [Boolean] True if similar without diacritics
      def similar_without_diacritics?(word1, word2)
        # Remove diacritics and compare
        normalize_diacritics(word1) == normalize_diacritics(word2)
      end

      # Normalize diacritics from a word.
      #
      # @param word [String] Word with diacritics
      # @return [String] Word without diacritics
      def normalize_diacritics(word)
        # Simple normalization (transliterate to ASCII)
        word.encode('ASCII', fallback: ->(c) {
          if c == 'ä'
            'ae'
          elsif c == 'ö'
            'oe'
          elsif c == 'ü'
            'ue'
          else
            c == 'ß' ? 'ss' : c
          end
        })
          .downcase
      end

      # Rank neighbors by contextual relevance.
      #
      # @param neighbors [Array<Models::NearestNeighbor>] Neighbors to rank
      # @param context [Models::Context] Context for ranking
      # @return [Array<Models::NearestNeighbor>] Ranked neighbors
      def rank_by_context(neighbors, context)
        # Get surrounding words
        surrounding = context.surrounding_words(3)
        return neighbors unless surrounding&.any?

        # Boost neighbors that appear in similar context
        # In full implementation, would use more sophisticated context modeling
        neighbors.map do |neighbor|
          boost = context_boost(neighbor.word, surrounding)
          # Create boosted neighbor (create new object to avoid mutation)
          boosted_similarity = [neighbor.similarity + boost, 1.0].min
          Models::NearestNeighbor.new(
            word: neighbor.word,
            similarity: boosted_similarity,
            embedding: neighbor.embedding
          )
        end.sort.reverse
      end

      # Calculate context boost for a word.
      #
      # @param word [String] Word to boost
      # @param surrounding [Array<String>] Surrounding words
      # @return [Float] Boost amount (0.0 to 0.1)
      def context_boost(word, surrounding)
        return 0.0 unless surrounding&.any?

        # Simple boost: if word is semantically similar to surrounding words
        surrounding.reduce(0.0) do |boost, surrounding_word|
          sim = @model.similarity(word, surrounding_word)
          boost + ((sim || 0.0) * 0.02) # Small boost for each similar word
        end
      end

      # Generate unique error ID.
      #
      # @param word [String] The error word
      # @param source_range [Kotoshu::Documents::SourceRange, nil]
      # @return [String] Truncated SHA-256 hex
      def generate_error_id(word, source_range)
        key = if source_range
                "#{word}-#{source_range.start.offset}-#{source_range.end.offset}"
              else
                "word:#{word}"
              end
        Digest::SHA256.hexdigest(key)[0...16]
      end
    end
  end
end
