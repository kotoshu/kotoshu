# frozen_string_literal: true

module Kotoshu
  module Cli
    # Matcher for .gitignore / .ignore files — the standard glob
    # subset, implemented in Ruby (no shelling out to git).
    #
    # Supported subset (documented honestly):
    # - one pattern per line; blank lines and lines starting with #
    #   are ignored
    # - leading ! negates a pattern; a leading backslash escapes a
    #   literal ! or #
    # - a trailing / restricts the pattern to directories
    # - a leading / anchors the pattern to the ignore file's
    #   directory; any pattern containing an interior / is anchored
    # - * matches anything except /; ? matches one non-/ character
    # - ** as a whole path segment: **/x matches x at any depth, x/**
    #   matches everything below x, a/**/b matches b at any depth
    #   under a
    # - the last matching pattern wins (later lines override earlier
    #   ones), like git
    #
    # Like git, a file cannot be re-included once a parent directory
    # is excluded: the walker never descends into an ignored
    # directory, so a negation deeper in the tree has no effect
    # there.
    #
    # Each matcher is scoped to the directory holding its ignore
    # file; paths are matched relative to that directory.
    class IgnoreMatcher
      IGNORE_FILENAMES = %w[.gitignore .ignore].freeze

      # One compiled ignore pattern.
      class Pattern
        attr_reader :source, :negated, :dir_only, :regex

        # Compile one ignore-file line.
        #
        # @param line [String] the raw line from the ignore file
        def initialize(line)
          @source = line
          escaped = line.match?(/\A\\[!#]/)
          body = escaped ? line[1..] : line
          @negated = !escaped && body.start_with?("!")
          body = body.delete_prefix("!") if @negated
          @dir_only = body.end_with?("/")
          body = body.sub(%r{/+\z}, "")
          anchored = body.start_with?("/") || body.include?("/")
          body = body.delete_prefix("/")
          @regex = build_regex(body, anchored: anchored)
        end

        # Whether this pattern matches a path relative to the ignore
        # file's directory.
        #
        # Directory-only patterns are evaluated solely against
        # directories. Otherwise, a pattern matching any ancestor
        # directory covers everything below it (gitignore
        # semantics).
        #
        # @param relative [String] relative path
        # @param directory [Boolean] whether the path is a directory
        # @return [Boolean]
        def matches?(relative, directory: false)
          return false if @dir_only && !directory

          return true if @regex.match?(relative)

          segments = relative.split("/")
          segments.first(segments.length - 1).each_with_object(+"") do |segment, prefix|
            prefix << (prefix.empty? ? segment : "/#{segment}")
            return true if @regex.match?(prefix)
          end
          false
        end

        private

        # Compile the glob body into a Regexp.
        #
        # @param body [String] glob without negation/trailing-slash
        #   markers
        # @param anchored [Boolean] whether the pattern is anchored
        #   to the ignore file's directory
        # @return [Regexp]
        def build_regex(body, anchored:)
          translated = self.class.glob_body(body)
          anchored ? /\A#{translated}\z/ : /(?:\A|\/)#{translated}\z/
        end

        class << self
          # Translate a gitignore glob body into a regex source.
          #
          # @param body [String] glob body
          # @return [String] regex source
          def glob_body(body)
            parts = body.split("/")
            out = +""
            parts.each_with_index do |part, index|
              if part == "**"
                append_double_star(out, last: index == parts.length - 1)
              else
                append_segment(out, translate_segment(part), after_double_star: index.positive? && parts[index - 1] == "**")
              end
            end
            out
          end

          private

          # Append the translation for a ** segment.
          #
          # @param out [String] accumulator
          # @param last [Boolean] whether ** ends the pattern
          def append_double_star(out, last:)
            out << (if out.empty?
                      ".*"
                    else
                      (last ? "/.*" : "(?:[^/]*/)*")
                    end)
          end

          # Append a translated normal segment with its separator.
          #
          # @param out [String] accumulator
          # @param segment [String] translated segment
          # @param after_double_star [Boolean] whether the previous
          #   segment was a non-final **
          def append_segment(out, segment, after_double_star:)
            out << "/" unless out.empty? || after_double_star
            out << segment
          end

          # Translate one non-** segment.
          #
          # @param segment [String] raw segment
          # @return [String] regex source for the segment
          def translate_segment(segment)
            Regexp.escape(segment).gsub('\*', '[^/]*').gsub('\?', '[^/]')
          end
        end
      end

      # Load all ignore files present in a directory.
      #
      # @param directory [String] absolute path to scan
      # @return [IgnoreMatcher] matcher with the merged patterns in
      #   file order (.gitignore first, then .ignore)
      def self.load_directory(directory)
        lines = IGNORE_FILENAMES.filter_map do |name|
          path = File.join(directory, name)
          File.file?(path) ? File.readlines(path, chomp: true) : nil
        end.flatten
        new(lines)
      end

      # Whether a directory holds at least one ignore file.
      #
      # @param directory [String] absolute path to scan
      # @return [Boolean]
      def self.present_in?(directory)
        IGNORE_FILENAMES.any? { |name| File.file?(File.join(directory, name)) }
      end

      # @param lines [Array<String>] raw ignore-file lines
      def initialize(lines)
        @patterns = lines.filter_map { |line| compile(line) }
      end

      # The compiled patterns, in file order.
      #
      # @return [Array<Pattern>]
      def patterns
        @patterns
      end

      # Whether a path is ignored. Last matching pattern wins.
      #
      # @param relative [String] path relative to the ignore file's
      #   directory
      # @param directory [Boolean] whether the path is a directory
      # @return [Boolean] true when the path is ignored
      def ignored?(relative, directory: false)
        ignored = false
        @patterns.each do |pattern|
          ignored = !pattern.negated if pattern.matches?(relative, directory: directory)
        end
        ignored
      end

      private

      # Compile one raw line, skipping blanks and comments.
      #
      # @param line [String] raw line
      # @return [Pattern, nil]
      def compile(line)
        stripped = line.sub(/[ \t]+\z/, "")
        return nil if stripped.empty? || stripped.start_with?("#")

        Pattern.new(stripped)
      end
    end
  end
end
