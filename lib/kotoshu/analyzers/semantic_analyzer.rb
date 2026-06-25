# frozen_string_literal: true

require_relative '../models/embedding_model'
require_relative '../models/semantic_error'
require_relative '../models/context'
require_relative '../documents/document'

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

      # Analyze a document for semantic errors.
      #
      # @param document [Document] The document to analyze
      # @return [Array<Models::SemanticError>] List of errors found
      def analyze(document)
        errors = []

        # Get text nodes from document
        document.text_nodes.each do |text_node|
          # Tokenize and check each word
          words = tokenize_words(text_node.text)

          words.each do |word|
            next if valid_word?(word)

            # Detect error
            error = detect_error(
              word: word,
              location: text_node.location,
              context: document.context_for(text_node.location)
            )

            errors << error if error
          end
        end

        # Sort errors by location and confidence
        errors.sort
      end

      # Detect semantic error for a single word.
      #
      # @param word [String] The word to check
      # @param location [Location] Error location
      # @param context [Models::Context, nil] Context around the word
      # @return [Models::SemanticError, nil] Error object or nil if valid
      def detect_error(word:, location:, context: nil)
        return nil if valid_word?(word)

        # Get suggestions
        suggestions = suggest_corrections(word, context: context)

        # Determine error type based on analysis
        error_type = classify_error(word, suggestions, context)

        # Calculate confidence based on suggestions
        confidence = calculate_confidence(suggestions)

        # Create error object
        Models::SemanticError.new(
          id: generate_error_id(word, location),
          location: location,
          original: word,
          suggestions: suggestions,
          error_type: error_type,
          confidence: confidence,
          context: context
        )
      end

      # Suggest corrections for a word.
      #
      # @param word [String] The misspelled word
      # @param context [Models::Context, nil] Context for context-aware suggestions
      # @return [Array<Models::Suggestion>] Suggested corrections
      def suggest_corrections(word, context: nil)
        return [] if word.nil? || word.empty?

        # Get nearest neighbors from embedding model
        neighbors = @model.nearest_neighbors(word, k: @max_suggestions * 3)

        # Filter by minimum similarity
        neighbors = neighbors.select { |n| n.similarity >= @min_similarity }

        # If we have context, rank by contextual relevance
        if context && context.respond_to?(:surrounding_words)
          neighbors = rank_by_context(neighbors, context)
        end

        # Convert to Suggestions
        neighbors.first(@max_suggestions).map do |neighbor|
          Models::Suggestion.new(
            word: neighbor.word,
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
        return true if word =~ /^\d+$/

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

      # Tokenize text into words.
      #
      # @param text [String] Text to tokenize
      # @return [Array<String>] Words
      def tokenize_words(text)
        return [] unless text

        # Simple word tokenization (splits on non-word characters)
        # In full implementation, would use language-specific tokenization
        text.downcase.scan(/[a-z]+(?:['’-][a-z]+)*/i)
      end

      # Classify error type based on word and suggestions.
      #
      # @param word [String] The error word
      # @param suggestions [Array<Models::Suggestion>] Suggestions
      # @param context [Models::Context, nil] Context
      # @return [Symbol] Error type
      def classify_error(word, suggestions, context)
        return :orthographic if suggestions&.empty?

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
        if suggestions.first&.source == :semantic
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
        word.encode('ASCII', fallback: ->(c) { c == 'ä' ? 'ae' : c == 'ö' ? 'oe' : c == 'ü' ? 'ue' : c == 'ß' ? 'ss' : c })
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
          boost + (sim || 0.0) * 0.02  # Small boost for each similar word
        end
      end

      # Generate unique error ID.
      #
      # @param word [String] The error word
      # @param location [Location] Error location
      # @return [String] Unique ID
      def generate_error_id(word, location)
        # Create ID from word and location hash
        base = "#{word}-#{location}"
        Digest::SHA256.hexdigest(base)[0...16]
      end
    end
  end
end
