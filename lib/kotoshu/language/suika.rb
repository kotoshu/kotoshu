# frozen_string_literal: true

module Kotoshu
  module Language
    # Soft-load suika. The gem is intentionally NOT a hard runtime
    # dependency — its native extension (dartsclone) fails to build on
    # slim/minimal environments and would block install for users who
    # only want non-Japanese spell-checking. Japanese tokenization and
    # POS tagging light up automatically when the gem is present.
    #
    # KOTOSHU_NO_SUIKA=1 forces Japanese analysis off even when the gem
    # is installed (useful for benchmarks / CI determinism).
    module Suika
      LOADED = begin
        if ENV["KOTOSHU_NO_SUIKA"] == "1"
          false
        else
          require "suika"
          true
        end
      rescue LoadError
        false
      end

      @tagger = nil

      class << self
        # Return a process-wide memoized Suika::Tagger, or raise
        # {SuikaUnavailable} when the gem is missing.
        def tagger
          raise Kotoshu::SuikaUnavailable unless LOADED

          @tagger ||= ::Suika::Tagger.new
        end
      end
    end
  end
end
