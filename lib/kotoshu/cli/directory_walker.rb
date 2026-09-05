# frozen_string_literal: true

module Kotoshu
  module Cli
    # Walks directory trees and selects the text files to check
    # (plan 88).
    #
    # Selection rules:
    # - known text extensions by default: md markdown asciidoc adoc
    #   txt rst mdx
    # - --include globs replace the extension default; --exclude
    #   globs always win
    # - globs without a slash match the file basename; globs with a
    #   slash match the path relative to the checked root, with *
    #   and ? never crossing / and ** crossing directories
    # - hidden files and directories (dot-prefixed) are skipped, as
    #   are .git, node_modules, vendor and target directories
    # - .gitignore and .ignore files are honored (see IgnoreMatcher
    #   for the supported subset); nested ignore files only apply to
    #   their own subtree
    class DirectoryWalker
      TEXT_EXTENSIONS = %w[.md .markdown .asciidoc .adoc .txt .rst .mdx].freeze
      DEFAULT_SKIP_DIRS = %w[.git node_modules vendor target].freeze

      # @param include_globs [Array<String>] --include globs
      # @param exclude_globs [Array<String>] --exclude globs
      def initialize(include_globs: [], exclude_globs: [])
        @include_globs = Array(include_globs)
        @exclude_globs = Array(exclude_globs)
      end

      # Collect the checkable files under one root, sorted
      # deterministically.
      #
      # @param root [String] directory to walk
      # @return [Array<String>] file paths rooted at +root+
      def files(root)
        walk(root, [], [])
      end

      private

      # Recursively collect files, carrying the ignore matchers of
      # every ancestor directory paired with their depth below the
      # root, so each matcher sees paths relative to its own
      # directory (gitignore scoping).
      #
      # @param directory [String] current absolute directory
      # @param relative [Array<String>] path segments below the root
      # @param matchers [Array<[IgnoreMatcher, Integer]>] ancestor
      #   matchers with their depths
      # @return [Array<String>] collected file paths
      def walk(directory, relative, matchers)
        if IgnoreMatcher.present_in?(directory)
          matchers = matchers + [[IgnoreMatcher.load_directory(directory), relative.length]]
        end

        files = []
        Dir.children(directory).sort.each do |entry|
          path = File.join(directory, entry)
          entry_relative = relative + [entry]
          next if hidden?(entry)
          next if ignored_by_any?(matchers, entry_relative, File.directory?(path))

          if File.directory?(path)
            next if DEFAULT_SKIP_DIRS.include?(entry)

            files.concat(walk(path, entry_relative, matchers))
          elsif selected?(entry, File.join(*entry_relative))
            files << path
          end
        end
        files
      end

      # Whether a path is ignored by any scoped matcher.
      #
      # @param matchers [Array<[IgnoreMatcher, Integer]>] matchers in
      #   scope with their depths
      # @param entry_relative [Array<String>] path segments below root
      # @param directory [Boolean] whether the entry is a directory
      # @return [Boolean]
      def ignored_by_any?(matchers, entry_relative, directory)
        matchers.any? do |matcher, depth|
          scoped = File.join(*entry_relative[depth..])
          matcher.ignored?(scoped, directory: directory)
        end
      end

      # Whether an entry name is hidden.
      #
      # @param entry [String] directory entry name
      # @return [Boolean]
      def hidden?(entry)
        entry.start_with?(".")
      end

      # Whether a file is selected for checking.
      #
      # @param basename [String] file name
      # @param relative [String] path relative to the root
      # @return [Boolean]
      def selected?(basename, relative)
        return false if globbed?(@exclude_globs, basename, relative)
        return globbed?(@include_globs, basename, relative) unless @include_globs.empty?

        TEXT_EXTENSIONS.include?(File.extname(basename))
      end

      # Whether any glob matches the file.
      #
      # @param globs [Array<String>] glob patterns
      # @param basename [String] file name
      # @param relative [String] path relative to the root
      # @return [Boolean]
      def globbed?(globs, basename, relative)
        globs.any? do |glob|
          if glob.include?("/")
            File.fnmatch(glob, relative, File::FNM_PATHNAME)
          else
            File.fnmatch(glob, basename)
          end
        end
      end
    end
  end
end
