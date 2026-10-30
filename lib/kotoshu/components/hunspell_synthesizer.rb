# frozen_string_literal: true

require_relative "synthesizer"

module Kotoshu
  module Components
    # Concrete synthesizer driven by Hunspell affix rules: expands a
    # lemma into its surface forms by applying the SFX/PFX flags carried
    # on the dictionary stem (forward direction of Hunspell stemming).
    #
    # Condition semantics (full form):
    #   "."      — any stem
    #   "abc"    — stripped stem ends with the literal suffix "abc"
    #   "[abc]"  — stripped stem ends with one of a, b, c
    #   "[^abc]" — stripped stem ends with a character NOT in a, b, c
    # When the lemma is not itself a dictionary stem, synthesis
    # degrades to [lemma] — callers treat that as "no expansion
    # available" rather than failure.
    class HunspellSynthesizer < Synthesizer
      Condition = Struct.new(:strip, :append, :kind, :chars, keyword_init: true)

      MAX_FORMS = 64

      # @param aff_path [String] e.g. en_US.aff
      # @param dic_path [String] e.g. en_US.dic
      def initialize(aff_path:, dic_path:)
        @suffixes = {} # flag => [Condition]
        @prefixes = {}
        @stems = {}    # stem => [flag strings]
        parse_aff(File.read(aff_path))
        parse_dic(File.read(dic_path))
      end

      def synthesize(lemma, _pos_tag = nil)
        flags = @stems[lemma]
        return [lemma] unless flags

        out = [lemma]
        flags.flat_map { |f| f.to_s.split("") }.uniq.each do |flag|
          (@suffixes[flag] || []).each { |c| out << apply(lemma, c, suffix: true) }
          (@prefixes[flag] || []).each { |c| out << apply(lemma, c, suffix: false) }
        end
        out.compact.uniq.first(MAX_FORMS)
      end

      private

      def apply(stem, cond, suffix:)
        stripped =
          if cond.strip.empty?
            stem
          elsif suffix
            stem.end_with?(cond.strip) ? stem.delete_suffix(cond.strip) : nil
          else
            stem.start_with?(cond.strip) ? stem.delete_prefix(cond.strip) : nil
          end
        return nil if stripped.nil? || stripped.empty?

        # Hunspell checks the condition against the ORIGINAL stem,
        # before the affix is removed.
        anchor = suffix ? stem[-1] : stem[0]
        pass = case cond.kind
               when :any then true
               when :literal then suffix ? stem.end_with?(cond.chars) : stem.start_with?(cond.chars)
               when :class then cond.chars.include?(anchor)
               when :negclass then !cond.chars.include?(anchor)
               end
        pass ? (suffix ? stripped + cond.append : cond.append + stripped) : nil
      end

      def parse_cond(field)
        return { kind: :any, chars: "" } if field == "." || field.nil? || field.empty?

        if (neg = field[/\A\[\^([^\]]*)\]\z/, 1])
          { kind: :negclass, chars: neg }
        elsif (pos = field[/\A\[([^\]]*)\]\z/, 1])
          { kind: :class, chars: pos }
        else
          { kind: :literal, chars: field }
        end
      end

      def parse_aff(text)
        text.each_line do |line|
          parts = line.split
          next unless %w[SFX PFX].include?(parts[0]) && parts.length >= 5

          strip = parts[2] == "0" ? "" : parts[2]
          append = parts[3] == "0" ? "" : parts[3]
          cond = Condition.new(**parse_cond(parts[4]), strip:, append:)
          table = parts[0] == "SFX" ? @suffixes : @prefixes
          (table[parts[1]] ||= []) << cond
        end
      end

      def parse_dic(text)
        text.each_line.with_index do |line, i|
          next if i.zero? # count header

          stem, flags = line.split("/", 2)
          stem = stem.to_s.strip
          next if stem.empty?

          (@stems[stem] ||= []) << flags.to_s
        end
      end
    end
  end
end
