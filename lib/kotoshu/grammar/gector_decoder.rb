# frozen_string_literal: true

module Kotoshu
  module Grammar
    # Iterative GECToR-style decoding (Omelianchuk et al. 2020):
    # predict labels, apply confident corrections, re-tag, repeat —
    # multi-edit sentences converge across rounds.
    class GectorDecoder
      # @param tagger [Tagger] the trained label tagger
      # @param rounds [Integer] apply-and-retag iterations
      # @param min_confidence [Float] skip labels below this softmax
      # @param label_thresholds [Hash{String=>Float}] per-label minimum
      #   confidence (GECToR's dev-tuned thresholds); labels absent
      #   fall back to min_confidence
      def initialize(tagger:, rounds: 2, min_confidence: 0.0, label_thresholds: {})
        @tagger = tagger
        @rounds = rounds
        @min_confidence = min_confidence
        @label_thresholds = label_thresholds
      end

      # The effective confidence floor for a label.
      def threshold_for(label)
        @label_thresholds.fetch(label, @min_confidence)
      end

      # Correct a sentence: returns the corrected token list and the
      # per-round predictions.
      #
      # @param words [Array<String>]
      # @return [Hash] { corrected:, rounds: [ {index, label, confidence} ] }
      def correct(words)
        tokens = words.dup
        applied = []
        @rounds.times do
          findings = detect_with_confidence(tokens)
          changed = false
          findings.each do |f|
            next if f[:confidence] < threshold_for(f[:label])

            result = apply(f[:label], tokens, f[:index])
            next if result.nil?

            tokens = result
            applied << f
            changed = true
          end
          break unless changed
        end
        { corrected: tokens, applied: applied }
      end

      private

      # detect() plus softmax confidence per finding.
      def detect_with_confidence(words)
        ids = tokenizer.encode_words(words)
        align = tokenizer.alignment(words)
        logits = model.predict({
                                 "input_ids" => [ids],
                                 "attention_mask" => [tokenizer.mask_for(ids)]
                               })["logits"][0]
        per_word = {}
        align.each_with_index do |word_index, pos|
          next if word_index.nil?
          next if per_word.key?(word_index)

          row = logits[pos]
          exps = row.map { |v| Math.exp(v - row.max) }
          sum = exps.sum
          best = row.each_with_index.max_by { |v, _| v }[1]
          per_word[word_index] = { label_id: best, confidence: exps[best] / sum }
        end
        per_word.filter_map do |index, pred|
          label = labels[pred[:label_id].to_s]
          next if label.nil? || label == "$KEEP"

          { index: index, label: label, confidence: pred[:confidence].round(4) }
        end
      end

      # Apply one label; returns the new token list or nil.
      def apply(label, tokens, index)
        case label
        when /\A\$REPLACE_(.+)\z/ then tokens.dup.tap { |t| t[index] = Regexp.last_match(1) }
        when /\A\$APPEND_(.+)\z/
          out = tokens.dup
          out.insert(index + 1, *Regexp.last_match(1).split)
          out
        when "$DELETE" then tokens.dup.tap { |t| t.delete_at(index) }
        when "$TRANSFORM_VERB_S" then tokens.dup.tap { |t| t[index] = Morphology.inflect_3sg(t[index]) }
        when "$TRANSFORM_VERB_ED"
          tokens.dup.tap { |t| t[index] = inflect_past(t[index]) }
        when "$TRANSFORM_VERB_ING"
          tokens.dup.tap { |t| t[index] = inflect_ing(t[index]) }
        when "$TRANSFORM_VERB_BASE" then tokens.dup.tap { |t| t[index] = Morphology.uninflect_3sg(t[index]) }
        when "$TRANSFORM_CASE_CAPITALIZE" then tokens.dup.tap { |t| t[index] = t[index].capitalize }
        when "$TRANSFORM_CASE_LOWER" then tokens.dup.tap { |t| t[index] = t[index].downcase }
        when /\A\$MERGE_(.+)\z/
          return nil if index + 1 >= tokens.length

          out = tokens.dup
          out[index] = Regexp.last_match(1)
          out.delete_at(index + 1)
          out
        end
      end

      def inflect_past(word)
        base = word.downcase
        ["d", "ed"].each do |suffix|
          stem = base[0...-suffix.length]
          if base.end_with?(suffix) && !stem.empty?
            irregular = Morphology::PAST_OF[base]
            return irregular if irregular
          end
        end
        if base.end_with?("e") then "#{base}d"
        elsif base.match?(/[^aeiou]y\z/) then "#{base[0..-2]}ied"
        else "#{base}ed"
        end
      end

      def inflect_ing(word)
        base = word.downcase
        return "#{base[0..-2]}ing" if base.end_with?("e") && !base.end_with?("ee")
        return "#{base}#{base[-1]}ing" if base.match?(/[aeiou][bcdfgklmnprstvz]\z/) && base.length <= 4

        "#{base}ing"
      end

      def tokenizer
        @tagger.tokenizer
      end

      def model
        @tagger.model
      end

      def labels
        @tagger.labels
      end
    end
  end
end
