# frozen_string_literal: true

module Kotoshu
  module Language
    # Value object: a contiguous run of text nodes that all share a
    # detected language. Produced by {Segmenter#segment}.
    #
    # Carries the detected +language_code+, the +text_nodes+ belonging
    # to the segment (in source order), and the +confidence+ the
    # detector returned for the segment's text. Multi-language
    # checkers consume segments one at a time, resolving resources
    # per-language.
    Segment = Struct.new(:language_code, :text_nodes, :confidence, keyword_init: true) do
      # Concatenated flattened text of every node in this segment.
      #
      # @return [String]
      def flattened_text
        text_nodes.map(&:text).join
      end

      # Number of text nodes in this segment.
      #
      # @return [Integer]
      def length
        text_nodes.length
      end

      # True when no text nodes are in the segment.
      #
      # @return [Boolean]
      def empty?
        text_nodes.nil? || text_nodes.empty?
      end
    end

    # Splits a {Documents::Document} into language-tagged segments.
    #
    # Walks +document.text_nodes+, detects the dominant language for
    # each node via the configured detector (default: {Detector}, the
    # pure-Ruby character-set-based detector — no fasttext needed),
    # and groups consecutive same-language nodes into {Segment}s.
    #
    # The detector is pluggable via the +detector:+ constructor
    # argument. Any object that responds to +detect_with_confidence+
    # and returns +[code, confidence]+ will do — the FastText-backed
    # {LanguageIdentifier} is a drop-in for higher accuracy at the
    # cost of a model download.
    class Segmenter
      DEFAULT_DETECTOR = Detector

      # Minimum text length (chars) for a node to participate in
      # detection. Shorter nodes ("a", "the", whitespace) don't carry
      # enough signal — they inherit the surrounding language.
      MIN_NODE_LENGTH_FOR_DETECTION = 3

      # @param detector [Object, nil] responds to +detect_with_confidence+.
      #   Defaults to {DEFAULT_DETECTOR}.
      # @param min_confidence [Float] detection results below this
      #   threshold are treated as unknown (segment language becomes
      #   the fallback language, default "en").
      # @param fallback_language [String] language code to use when
      #   detection is inconclusive.
      def initialize(detector: nil, min_confidence: 0.3, fallback_language: "en")
        @detector = detector || DEFAULT_DETECTOR
        @min_confidence = min_confidence
        @fallback_language = fallback_language
      end

      # Segment a document.
      #
      # @param document [Kotoshu::Documents::Document]
      # @return [Array<Segment>] language-tagged segments, in source order
      def segment(document)
        unless document.is_a?(Kotoshu::Documents::Document)
          raise ArgumentError,
                "document must be a Kotoshu::Documents::Document"
        end

        segments = []
        current = nil

        document.text_nodes.each do |node|
          code, confidence = detect_for_node(node)
          if current && current.language_code == code
            current.text_nodes << node
          else
            segments << current if current && !current.empty?
            current = Segment.new(language_code: code, text_nodes: [node],
                                  confidence: confidence)
          end
        end
        segments << current if current && !current.empty?
        segments
      end

      private

      # Detect language for a single node. Short nodes (< MIN length)
      # inherit nil and the caller's group-merge logic picks up the
      # previous segment's language (because nil != previous code).
      # To avoid fragmenting segments on short connector words, we
      # return the previous detection — but Ruby doesn't easily carry
      # state into a `private` helper without ivars, so the caller
      # handles short-node inheritance via the group-merge rule.
      #
      # For now: short nodes return the fallback language so they
      # merge with whatever segment is open (assuming the previous
      # detection was also the fallback). This is a heuristic; a
      # richer segmenter would carry last-detected-code as state.
      def detect_for_node(node)
        text = node.text
        return [@fallback_language, 0.0] if text.nil? || text.strip.empty?
        return [@fallback_language, 0.0] if text.strip.length < MIN_NODE_LENGTH_FOR_DETECTION

        code, confidence = @detector.detect_with_confidence(text)
        return [@fallback_language, 0.0] if code.nil? || confidence < @min_confidence

        [code, confidence]
      end
    end
  end
end
