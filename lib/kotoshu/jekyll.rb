# frozen_string_literal: true

module Kotoshu
  # Jekyll integration (plan 89, item 4). Soft dependency: jekyll is
  # NOT in kotoshu.gemspec; the generator soft-requires it exactly
  # like Models::OnnxModel soft-requires onnxruntime.
  module Jekyll
    # True when jekyll was requireable at load time.
    JEKYLL_LOADED = begin
      require "jekyll"
      true
    rescue LoadError
      false
    end

    # Raised when the generator is used without jekyll.
    class JekyllUnavailable < Kotoshu::Error
      def initialize
        super("Kotoshu's Jekyll generator needs the jekyll gem. " \
              "Add gem 'jekyll' to your Gemfile.")
      end
    end

    if JEKYLL_LOADED
      # Jekyll generator checking posts and drafts; a new spelling
      # error fails the build. Baselines are respected when
      # .kotoshu-baseline.json sits in the site source (the same file
      # `kotoshu baseline init` writes), so existing errors do not
      # block the build until they are fixed.
      #
      # @example _config.yml
      #   plugins:
      #     - kotoshu
      #
      # Users register this class in a plugins file:
      #   require "kotoshu/jekyll"
      class Generator < ::Jekyll::Generator
        safe true
        priority :low

        def generate(site)
          documents = site.posts.docs
          if documents.empty?
            ::Jekyll.logger.info "kotoshu:", "no posts or drafts to check"
            return
          end

          baseline = load_baseline(site)
          failures = []
          documents.each do |document|
            result = Kotoshu.check(document.content)
            application = baseline&.apply(result, file: document.relative_path.to_s)
            result = application.result if application
            failures.concat(failure_lines(document, result))
          end

          return if failures.empty?

          raise "kotoshu: spelling errors in #{failures.size} location(s):\n" +
            failures.join("\n")
        end

        private

        # Load the baseline from the site source when present.
        #
        # @param site [Jekyll::Site] the site being built
        # @return [Baseline::Store, nil]
        def load_baseline(site)
          path = File.join(site.source, Baseline::Store::DEFAULT_FILENAME)
          File.exist?(path) ? Baseline::Store.load(path) : nil
        end

        # One failure line per misspelling.
        #
        # @param document [Jekyll::Document] the checked document
        # @param result [Models::Result::DocumentResult] check result
        # @return [Array<String>]
        def failure_lines(document, result)
          result.each_error.map do |error|
            suggestions = error.has_suggestions? ? " -> #{error.top_suggestions(3).join(', ')}" : ""
            "  #{document.relative_path}: #{error.word}#{suggestions}"
          end
        end
      end
    else
      # Placeholder raising a friendly error when jekyll is missing;
      # keeps the constant resolvable for tooling.
      class Generator
        def generate(*)
          raise JekyllUnavailable
        end
      end
    end
  end
end
