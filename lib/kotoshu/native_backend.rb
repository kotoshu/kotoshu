# frozen_string_literal: true

module Kotoshu
  # Native engine adapter (plan 66, P4b): +correct?+ and +suggest+ for one
  # loaded Hunspell dictionary, computed by the kotoshu-rs core through
  # {Native}.
  #
  # == Boundary (deliberate, documented)
  #
  # The native engine accelerates exactly the two hot-path calls of the
  # traditional checking path — correct?(word) and suggest(word) — over a
  # file-backed Hunspell dictionary, where kotoshu-rs implements the full
  # dictionary + affix + suggest composite and is held to byte-identical
  # results by the conformance vectors (rake kotoshu:conformance:compare).
  # Everything else stays Ruby: non-Hunspell dictionary backends, the
  # suggestion strategy pipeline beyond the conformance surface, the
  # semantic path ({Analyzers::SemanticAnalyzer}, ONNX models), grammar
  # rules, caches, and document tokenizing. The extension is a pure
  # accelerator, never a dependency.
  #
  # == Selection
  #
  # See {Configuration#backend} / +KOTOSHU_BACKEND+:
  #
  # ruby   :: never uses the native engine (default).
  # auto   :: uses it when the extension is loaded AND the dictionary is a
  #           file-backed Hunspell; silently pure-Ruby otherwise.
  # native :: uses it or raises {Native::Unavailable} — loud failure for
  #           debugging and benchmarking.
  class NativeBackend
    # @return [Kotoshu::Native::Dictionary] the loaded native dictionary
    attr_reader :native_dictionary

    # Resolve which backend serves a Spellchecker built over +dictionary+.
    #
    # @param dictionary [Dictionary::Base, Object] the dictionary the
    #   Spellchecker was built with
    # @param backend [String, Symbol] "ruby", "auto", or "native"
    # @param max_suggestions [Integer] default suggestion limit
    # @return [NativeBackend, nil] nil when the pure-Ruby engine serves the
    #   request
    # @raise [Native::Unavailable] backend "native" and the engine cannot
    #   serve the request
    # @raise [ConfigurationError] unknown backend value
    def self.resolve(dictionary:, backend:, max_suggestions: 10)
      case backend.to_s
      when "ruby"
        nil
      when "auto"
        paths = hunspell_paths(dictionary)
        return nil unless paths && Kotoshu::Native.available?

        new(aff_path: paths.fetch(0), dic_path: paths.fetch(1), max_suggestions: max_suggestions)
      when "native"
        unless Kotoshu::Native.available?
          raise Native::Unavailable,
                "native backend requested (KOTOSHU_BACKEND=native) but the extension is not " \
                "available — build it with `rake compile` or install the gem where it compiled"
        end

        paths = hunspell_paths(dictionary)
        unless paths
          raise Native::Unavailable,
                "native backend requested (KOTOSHU_BACKEND=native) but it only loads " \
                "Hunspell dictionaries — got #{dictionary.class}"
        end

        new(aff_path: paths.fetch(0), dic_path: paths.fetch(1), max_suggestions: max_suggestions)
      else
        raise ConfigurationError,
              "unknown backend #{backend.inspect} (expected \"ruby\", \"auto\", or \"native\")"
      end
    end

    # The (aff, dic) paths of a file-backed Hunspell dictionary — the only
    # dictionary form the native engine loads. Everything else answers nil.
    #
    # @param dictionary [Object]
    # @return [Array<String>, nil]
    def self.hunspell_paths(dictionary)
      return nil unless dictionary.is_a?(Dictionary::Hunspell)

      aff = dictionary.aff_path
      dic = dictionary.dic_path
      return nil if aff.nil? || dic.nil?

      [aff, dic]
    end

    # @param aff_path [String] path to the .aff file
    # @param dic_path [String] path to the .dic file
    # @param max_suggestions [Integer] default suggestion limit
    # @raise [Native::Error] the dictionary failed to load (message from
    #   the Rust engine)
    def initialize(aff_path:, dic_path:, max_suggestions: 10)
      @max_suggestions = max_suggestions
      @native_dictionary = Kotoshu::Native::Dictionary.load(aff_path, dic_path)
    end

    # Check a word against the native dictionary.
    #
    # @param word [String]
    # @return [Boolean]
    def correct?(word)
      @native_dictionary.correct?(word)
    end

    # Suggest corrections for a word through the native engine, returning
    # the same {Suggestions::SuggestionSet} the Ruby path returns.
    #
    # The Rust engine returns rows already ranked, deduplicated, and
    # limited — its ranking is conformance-frozen to the Ruby engine's
    # behavior (rake kotoshu:conformance:compare), and its tie order can
    # depend on ranking signals that do not live on the Suggestion objects.
    # The set therefore adopts the native order verbatim (ranked: true)
    # instead of re-sorting.
    #
    # @param word [String]
    # @param max_suggestions [Integer, nil] limit override
    # @return [Suggestions::SuggestionSet]
    def suggest(word, max_suggestions: nil)
      limit = max_suggestions || @max_suggestions
      rows = @native_dictionary.suggest(word, limit)
      Suggestions::SuggestionSet.new(
        rows.map { |row| Kotoshu::Native.suggestion(row) },
        max_size: limit,
        ranked: true
      )
    end
  end
end
