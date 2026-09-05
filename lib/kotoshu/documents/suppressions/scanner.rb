# frozen_string_literal: true

module Kotoshu
  module Documents
    module Suppressions
      # Line-oriented scanner for inline ignore directives.
      #
      # ONE shared implementation of the directive semantics; the only
      # per-format knowledge is how to find a comment on a line:
      #
      # - :plain — a line whose trimmed content IS the directive
      #   (whole-line only; trailing directives would be ambiguous in
      #   prose)
      # - :markdown — HTML comments `<!-- ... -->`, whole-line or
      #   trailing
      # - :asciidoc — `//` line comments, whole-line or trailing
      #   (the marker must be at line start or preceded by whitespace,
      #   so URLs like https://example.com are not comments)
      # - :auto — all of the above. The Spellchecker facade uses this
      #   profile because it checks raw text without a parser.
      #
      # Inside a comment the directive must appear at the very start:
      # prose that merely mentions `kotoshu:disable-line` is not a
      # directive.
      #
      # Word lists are only meaningful on `disable-next-line` (the one
      # form the plan defines them for); extra words after the other
      # directives are ignored.
      class Scanner
        DIRECTIVE_PATTERN =
          /\Akotoshu:(disable-line|disable-next-line|disable-file|enable-file)\b[ \t]*(.*)\z/
        HTML_COMMENT_BODIES = /<!--\s*(.*?)\s*-->/
        ASCII_DOC_COMMENT_BODY = /(?:\A|[ \t])\/\/[ \t]?(?<body>.*)\Z/

        PROFILE = {
          plain: %i[bare],
          markdown: %i[html_comment],
          asciidoc: %i[line_comment],
          auto: %i[bare html_comment line_comment]
        }.freeze

        EMPTY = [].freeze
        private_constant :EMPTY

        class << self
          # Scan +source+ and return the suppressions its directives
          # produce, in source order.
          #
          # @param source [String, nil]
          # @param format [Symbol] :plain, :markdown, :asciidoc, :auto
          #   (unknown symbols fall back to :auto)
          # @return [Array<Suppression>] frozen
          def scan(source, format: :auto)
            return EMPTY if source.nil? || source.empty?

            extractors = PROFILE.fetch(format.to_sym, PROFILE[:auto])
            suppressions = []
            open_blocks = []
            last_line = 1

            source.each_line.with_index(1) do |line, lineno|
              last_line = lineno
              directives_on(line, extractors).each do |action, words|
                case action
                when :disable_line
                  suppressions << Suppression.new(
                    kind: :line, directive_line: lineno,
                    start_line: lineno, end_line: lineno
                  )
                when :disable_next_line
                  suppressions << Suppression.new(
                    kind: :next_line, directive_line: lineno,
                    start_line: lineno + 1, end_line: lineno + 1,
                    words: words
                  )
                when :disable_file
                  open_blocks << lineno
                when :enable_file
                  close_block(open_blocks.pop, lineno, suppressions)
                end
              end
            end

            open_blocks.each { |start| push_file_block(start, last_line, suppressions) }
            suppressions.freeze
          end

          private

          # All directives found on +line+, in order, as
          # [action_symbol, word_list] pairs.
          def directives_on(line, extractors)
            directives = []
            extractors.each do |extractor|
              comment_bodies(line, extractor).each do |body|
                match = body.match(DIRECTIVE_PATTERN)
                next unless match

                action = match[1].tr("-", "_").to_sym
                words = action == :disable_next_line ? match[2].split : []
                directives << [action, words]
              end
            end
            directives
          end

          # Comment bodies on +line+ for one extractor kind.
          def comment_bodies(line, extractor)
            case extractor
            when :bare
              [line.strip]
            when :html_comment
              line.scan(HTML_COMMENT_BODIES).flatten
            when :line_comment
              match = line.match(ASCII_DOC_COMMENT_BODY)
              match ? [match[:body]] : []
            end
          end

          def close_block(start_line, enable_line, suppressions)
            return unless start_line

            # The enable-file line itself belongs to the block:
            # directive text is never spellchecked.
            push_file_block(start_line, [enable_line, start_line].max, suppressions)
          end

          def push_file_block(start_line, end_line, suppressions)
            suppressions << Suppression.new(
              kind: :file, directive_line: start_line,
              start_line: start_line, end_line: end_line
            )
          end
        end
      end
    end
  end
end
