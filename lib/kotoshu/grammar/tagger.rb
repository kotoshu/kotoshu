# frozen_string_literal: true

require "json"

module Kotoshu
  module Grammar
    # The neural detection half of the hybrid grammar checker
    # (TODO.grammar/9): a closed-class tagger that runs LOCALLY through
    # onnxruntime — nothing leaves the machine.
    #
    # The tagger detects WHICH token is wrong and NAMES the error
    # class; the concrete fix is generated deterministically from the
    # class (morphology and closed replacement sets) — the open-vocab
    # replacement problem is deliberately not in the model.
    #
    # The model directory carries: gec-tagger.int8.onnx, labels.json
    # (the trained id->label map — do not rebuild it), vocab.json,
    # merges.txt (distilroberta byte-level BPE).
    #
    # @example
    #   tagger = Grammar::Tagger.from_dir("/path/to/model-dir")
    #   tagger.detect("They was late".split)
    #   # => [{ index: 1, label: "$AGREEMENT_WAS_WERE" }]
    #   tagger.fix_for("$AGREEMENT_WAS_WERE", "was") # => ["were"]
    class Tagger
      class ModelUnavailable < StandardError; end

      CLASS_MESSAGES = {
        "$AGREEMENT_3SG" => "Subject-verb agreement",
        "$AGREEMENT_WAS_WERE" => "was/were agreement",
        "$AGREEMENT_MODAL_OF" => "Use 'have' after a modal",
        "$CAPITALIZATION" => "Capitalization",
        "$ARTICLE" => "Article (a/an)",
        "$DETERMINER_NUMBER" => "Determiner number (this/these)",
        "$SPELLING" => "Possible spelling error"
      }.freeze

      attr_reader :labels, :model, :tokenizer

      # @param model_path [String] int8 ONNX tagger
      # @param labels_path [String] labels.json shipped with the model
      # @param vocab_path [String] distilroberta vocab.json
      # @param merges_path [String] distilroberta merges.txt
      def initialize(model_path:, labels_path:, vocab_path:, merges_path:)
        require "onnxruntime"
        @model = OnnxRuntime::Model.new(model_path)
        @labels = JSON.parse(File.read(labels_path))
        @tokenizer = ByteBpe.new(vocab_path, merges_path)
      end

      # Load from a model directory laid out as from_dir expects.
      #
      # @param dir [String]
      # @return [Tagger]
      def self.from_dir(dir)
        new(
          model_path: File.join(dir, "gec-tagger.int8.onnx"),
          labels_path: File.join(dir, "labels.json"),
          vocab_path: File.join(dir, "vocab.json"),
          merges_path: File.join(dir, "merges.txt")
        )
      end

      # Detect error classes per word.
      #
      # @param words [Array<String>] the sentence's words
      # @return [Array<Hash>] [{ index:, label: }] for non-$KEEP words
      def detect(words)
        ids = @tokenizer.encode_words(words)
        align = @tokenizer.alignment(words)
        # Braces are load-bearing: the gem's Model#predict takes **run_options,
        # and a brace-less trailing hash is captured as keywords, not input_feed.
        logits = @model.predict({
                                  "input_ids" => [ids],
                                  "attention_mask" => [@tokenizer.mask_for(ids)]
                                })["logits"][0]
        per_word = {}
        align.each_with_index do |word_index, pos|
          next if word_index.nil?
          next if per_word.key?(word_index)

          per_word[word_index] = argmax(logits[pos])
        end
        per_word.filter_map do |index, label_id|
          label = @labels[label_id.to_s]
          next if label.nil? || label == "$KEEP"

          { index: index, label: label }
        end
      end

      # Deterministic fix candidates for a detected class.
      #
      # @param label [String] the error class
      # @param word [String] the flagged token
      # @return [Array<String>] replacement candidates
      def fix_for(label, word)
        case label
        when "$AGREEMENT_3SG"
          [Morphology.inflect_3sg(word), Morphology.uninflect_3sg(word)].uniq
        when "$AGREEMENT_WAS_WERE"
          word.casecmp("was").zero? ? ["were"] : ["was"]
        when "$AGREEMENT_MODAL_OF"
          ["have"]
        when "$CAPITALIZATION"
          [word.capitalize]
        when "$ARTICLE"
          word.casecmp("a").zero? ? ["an"] : ["a"]
        when "$DETERMINER_NUMBER"
          word.casecmp("this").zero? ? ["these"] : ["this"]
        else
          []
        end
      end

      # The human message for a class.
      #
      # @param label [String]
      # @return [String]
      def message_for(label)
        CLASS_MESSAGES.fetch(label, "Grammar")
      end

      private

      def argmax(row)
        row.each_with_index.max_by { |value, _| value }[1]
      end
    end
  end
end
