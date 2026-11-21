# frozen_string_literal: true

require "json"

module Kotoshu
  module Experimental
    # SentencePiece unigram encoder for DeBERTa-v3 vocabularies
    # (TODO 152 step 2). Encodes whitespace-pre-tokenized text with
    # Viterbi-best segmentation over a pieces table (piece, score,
    # type) — the table extracted from the trained model's vocab
    # (de-v1/pieces.json.bak-79649: 79,289 scored unigram pieces +
    # byte-fallback <0xNN> + specials).
    #
    # Conformance contract: ids match the prune_export row order
    # (pieces.json order), so the encoder feeds the pruned embedding
    # matrix directly. Reference encodes come from a reconstructed
    # sentencepiece proto (scripts/rebuild_spm_proto.py) — the replay
    # gate is the plan-131 pattern.
    class SpmUnigramEncoder
      UNK = 3 # [UNK] row (pieces table order: PAD CLS SEP UNK ...)
      MAX_PIECE_BYTES = 16

      def initialize(pieces_path)
        pieces = JSON.parse(File.read(pieces_path))
        @rows = pieces.map { |p| p["piece"] }
        # pieces.json stores log-prob scores VERBATIM (log scale);
        # Math.log of negatives = NaN = arbitrary Viterbi paths
        # (the 3/8 conformance bug). Use verbatim.
        @scores = pieces.map { |p| p["score"].to_f }
        # scores in the table are LOG-probs already? No — sentencepiece
        # exports unigram SCORES as log-probs; pieces.json stores them
        # verbatim. Guard: if any |score| < 1 they were probabilities —
        # the table stores log values, used as-is below.
        @piece_to_row = {}
        pieces.each_with_index { |p, i| @piece_to_row[p["piece"]] ||= i }
        @unk_piece_row = @piece_to_row["[UNK]"] || UNK
        @byte_fallback = {}
        pieces.each_with_index do |p, i|
          m = p["piece"].match(/\A<0x([0-9A-Fa-f]{2})>\z/)
          @byte_fallback[m[1].to_i(16)] = i if m
        end
      end

      attr_reader :rows

      # Sentencepiece semantics: the dummy prefix (▁) is prepended and
      # every space is replaced by ▁, then ONE global Viterbi pass runs
      # over the transformed string (add_dummy_prefix=true). Returns
      # flat row ids in pieces-table order.
      def encode(text)
        viterbi("▁#{text.strip.gsub(' ', '▁')}".b)
      end

      private

      # Viterbi over byte positions: best path maximizing summed log
      # scores, using table pieces at every offset + byte-fallback for
      # single bytes with no covering piece.
      def viterbi(bytes)
        n = bytes.length
        best = Array.new(n + 1, -Float::INFINITY)
        back = Array.new(n + 1, nil)
        best[0] = 0.0
        (1..n).each do |end_pos|
          max_len = [MAX_PIECE_BYTES, end_pos].min
          max_len.downto(1) do |len|
            start_pos = end_pos - len
            candidate = bytes[start_pos, len]
            row = @piece_to_row[candidate.force_encoding("UTF-8")]
            next unless row

            score = best[start_pos] + @scores[row]
            if score > best[end_pos]
              best[end_pos] = score
              back[end_pos] = [start_pos, row]
            end
          end
          # byte-fallback for the last byte if nothing covered it
          if back[end_pos].nil? && best[end_pos] == -Float::INFINITY
            fb = @byte_fallback[bytes[end_pos - 1].ord]
            row = fb || @unk_piece_row
            score = best[end_pos - 1] + (@byte_fallback[bytes[end_pos - 1].ord] ? @scores[row] : -20.0)
            best[end_pos] = score
            back[end_pos] = [end_pos - 1, row]
          end
        end
        out = []
        pos = n
        while pos > 0
          prev, row = back[pos]
          out.unshift(row)
          pos = prev
        end
        out
      end
    end
  end
end
