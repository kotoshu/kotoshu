# frozen_string_literal: true

module Kotoshu
  # Ruby-side home of the native engine (plan 66, P4b).
  #
  # The Rust extension +kotoshu/kotoshu_native+ (built from
  # ext/kotoshu_native) defines this module's engine surface when it loads:
  #
  #   Kotoshu::Native::VERSION                    # kotoshu-rs crate version
  #   Kotoshu::Native.available?                  # => true
  #   Kotoshu::Native::Error                      # engine failures (RuntimeError)
  #   dictionary = Kotoshu::Native::Dictionary.load(aff_path, dic_path)
  #   dictionary.correct?("hello")                # => true / false
  #   dictionary.suggest("hlelo", 5)              # => [{ "word" => "hello", ... }]
  #
  # This file adds two things the extension cannot:
  #
  # * the safe loader — +require "kotoshu"+ never fails when the extension
  #   is absent. A missing Rust toolchain, an uncompiled checkout, or a
  #   slim install simply leaves {Native.available?} false, and the
  #   pure-Ruby backend remains the complete engine. Mirrors the parsanol
  #   loader pattern (lib/parsanol/native.rb): rescue LoadError, stay quiet.
  # * the adapter — native suggestion rows are Hashes carrying exactly the
  #   four public keys of {Suggestions::Suggestion}; {Native.suggestion}
  #   materializes the model object from a row. No serialization is
  #   hand-rolled here: the row is constructor input, the model's
  #   (de)serialization stays lutaml-model's.
  module Native
    # Raised by backend selection when the native engine is explicitly
    # requested ({Configuration#backend} = "native") but cannot serve the
    # request: extension not built, or a dictionary type the native engine
    # does not load. Failing loudly is deliberate — "native" exists for
    # debugging and benchmarking, where a silent fallback to Ruby would
    #   produce misleading measurements.
    class Unavailable < Kotoshu::Error; end

    # The extension's require path (rb_sys installs it as
    # kotoshu/kotoshu_native.<dlext> under lib/).
    EXTENSION = "kotoshu/kotoshu_native"

    class << self
      # Whether the native extension is loaded.
      #
      # Overwritten by the extension itself when it loads (its own
      # +available?+ answers true), so this definition only stands when the
      # require below failed.
      #
      # @return [Boolean]
      def available?
        false
      end

      # Materialize a {Suggestions::Suggestion} from a native suggestion
      # row.
      #
      # The Rust engine returns one Hash per suggestion with exactly the
      # four public keys of the gem's Suggestion shape ("word" String,
      # "distance" Integer, "confidence" Float in [0, 1], "source" String)
      # — the same four keys the conformance vectors freeze
      # ({ConformanceExporter::SUGGESTION_KEYS}). This constructor hop is
      # the whole adapter; rows and model attributes are one-to-one.
      #
      # @param row [Hash] native suggestion row
      # @return [Suggestions::Suggestion]
      def suggestion(row)
        Suggestions::Suggestion.new(
          word: row.fetch("word"),
          distance: row.fetch("distance"),
          confidence: row.fetch("confidence"),
          source: row.fetch("source")
        )
      end
    end
  end

  begin
    require Native::EXTENSION
  rescue LoadError
    # Extension not built (no Rust toolchain, or `rake compile` not run).
    # Nothing else in the gem requires it: the pure-Ruby backend is the
    # complete engine and every public API works without the extension.
  end
end
