# frozen_string_literal: true

module Kotoshu
  module Components
    # Reader for the CLE POS-tagged Urdu corpus format (issue #278).
    #
    # Delivery format, per the complimentary human-verified sample
    # (pk-cle-urdu, 2026-11-20): UTF-8 (with BOM), one document per
    # file, space-separated `word/TAG` pairs where TAG is from the CLE
    # Urdu POS Tagset (Grammar::PosTagset::Ur). The forward-slash joins
    # with rpartition, so slashes inside words cannot corrupt the split.
    #
    # The purchased 100K-word review rides the same format; files land
    # in this reader unchanged.
    module CLEPosReader
      # Parse one document's text into tagged pairs.
      #
      # @param text [String] document text (BOM tolerated)
      # @param strict [Boolean] raise on unknown tags (default false:
      #   collect them into the second return value)
      # @return [Array<Array<String, String>>, Array<String>] pairs of
      #   [word, tag] plus any tags not in the tagset
      def self.parse(text, strict: false)
        require "kotoshu/grammar"
        words = text.gsub(/^﻿/, "").split
        pairs = []
        unknown = []
        words.each do |tok|
          word, _, tag = tok.rpartition("/")
          next if word.empty? || tag.empty?

          if Grammar::PosTagset::Ur.tag?(tag)
            pairs << [word, tag]
          else
            unknown << tag
            pairs << [word, tag] unless strict
          end
        end
        raise Kotoshu::Error, "unknown CLE tags: #{unknown.uniq.join(', ')}" if strict && unknown.any?

        [pairs, unknown]
      end

      # Parse a file path.
      #
      # @param path [String]
      # @param strict [Boolean]
      # @return [Array<Array<String, String>>, Array<String>]
      def self.parse_file(path, strict: false)
        parse(File.read(path, encoding: "bom|utf-8"), strict: strict)
      end

      # Parse a whole delivery directory (one .txt per document).
      #
      # @param dir [String]
      # @param strict [Boolean]
      # @return [Hash<String, Array>] path => pairs
      def self.parse_dir(dir, strict: false)
        Dir.glob(File.join(dir, "**/*.txt")).each_with_object({}) do |path, out|
          out[path] = parse_file(path, strict: strict).first
        end
      end
    end
  end
end
