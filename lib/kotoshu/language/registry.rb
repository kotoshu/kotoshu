# frozen_string_literal: true

module Kotoshu
  module Language
    # Central registry for language registration and retrieval.
    #
    # Uses Registry pattern for dynamic language discovery and management.
    # Languages register themselves on load, making the system extensible.
    #
    # @example Register a language
    #   Kotoshu::Language::Registry.register("en-US", English::American)
    #
    # @example Retrieve a language
    #   lang = Kotoshu::Language::Registry.get("en-US")
    #
    # @example List supported languages
    #   codes = Kotoshu::Language::Registry.supported_codes
    class Registry
      @languages = {}
      @detectors = []

      class << self
        # Register a language class with its code.
        #
        # @param code [String] Language code (e.g., "en-US", "de-DE")
        # @param language_class [Class] Class implementing Kotoshu::Language::Base
        # @return [void]
        #
        # @example
        #   Registry.register("en-US", English::American)
        def register(code, language_class)
          @languages[code] = language_class
        end

        # Register a detector for auto-detection.
        #
        # Detectors are tried in order of registration.
        #
        # @param detector [#detect] Object with detect method
        # @return [void]
        def register_detector(detector)
          @detectors << detector
        end

        # Get language class by code.
        #
        # Supports fallback to base language if variant not found.
        # Also supports finding variants when asking for base language.
        # For example:
        # - "en-GB" falls back to "en" if "en-GB" not registered
        # - "en" returns "en-US" if only "en-US" is registered
        #
        # @param code [String] Language code
        # @return [Class, nil] Language class or nil if not found
        def get(code)
          return nil unless code

          ensure_languages_loaded

          # Try exact match first
          return @languages[code] if @languages.key?(code)

          base = code.split('-').first

          # If code has a hyphen (e.g., "en-GB"), try base language
          if code.include?('-')
            return @languages[base]
          end

          # If code is base language (e.g., "en"), find any variant
          @languages.each do |registered_code, klass|
            return klass if registered_code.split('-').first == base
          end

          nil
        end

        # Check if a language is registered.
        #
        # @param code [String] Language code
        # @return [Boolean] True if registered
        def registered?(code)
          !get(code).nil?
        end

        # Get all supported language codes.
        #
        # @return [Array<String>] Sorted list of language codes
        def supported_codes
          ensure_languages_loaded
          @languages.keys.sort
        end

        # Get all registered language classes.
        #
        # @return [Hash] Hash mapping codes to classes
        def all
          ensure_languages_loaded
          @languages.dup
        end

        # Trigger load of every per-language implementation in
        # Kotoshu::Languages. Each language file calls Registry.register
        # at file-load time, so loading all constants fully populates the
        # registry. Safe to call multiple times.
        #
        # @return [void]
        def ensure_languages_loaded
          return if @languages_loaded

          # Reference Kotoshu::Languages to trigger autoload of the
          # namespace file, which sets up per-language autoloads.
          Kotoshu::Languages.constants.each { |c| Kotoshu::Languages.const_get(c) }
          @languages_loaded = true
        end

        # Detect language from text.
        #
        # Tries registered detectors in order.
        #
        # @param text [String] Text to analyze
        # @return [String, nil] Detected language code or nil
        def detect(text)
          return nil if text.nil? || text.empty?

          @detectors.each do |detector|
            result = detector.detect(text)
            return result if result
          end

          nil
        end

        # Clear all registrations (mainly for testing).
        #
        # Marks the registry as loaded so ensure_languages_loaded does
        # not re-populate from autoloaded language files. Tests rely on
        # clear producing an actually-empty registry. Pair with
        # {restore_autoload!} in an +after(:all)+ hook so the registry
        # is repopulated for specs that depend on it.
        #
        # @return [void]
        def clear
          @languages.clear
          @detectors.clear
          @languages_loaded = true
        end

        # Re-enable lazy autoload of per-language implementations after
        # a {clear}, then replay the registration of every loaded
        # per-language class. File-level +register+ calls only fire
        # once (Ruby autoload runs each file exactly once), so the
        # replay walks the already-loaded constants and re-issues
        # {register} from each class's +registered_codes+ list.
        #
        # Intended for test-suite cleanup so one spec's {clear} does
        # not leak an empty registry into unrelated specs.
        #
        # @return [void]
        def restore_autoload!
          @languages_loaded = false
          return if @replaying

          @replaying = true
          begin
            Kotoshu::Languages.constants.each do |c|
              klass = Kotoshu::Languages.const_get(c)
              next unless klass.is_a?(Class) && (klass < Kotoshu::Language::Base)

              klass.registered_codes.each { |code| register(code, klass) }
            end
          ensure
            @replaying = false
          end
        end

        # Get language info by code.
        #
        # @param code [String] Language code
        # @return [Hash, nil] Language info or nil
        def info(code)
          klass = get(code)
          return nil unless klass

          instance = klass.instance if klass.respond_to?(:instance)
          instance ||= klass.new

          {
            code: code,
            name: instance.name,
            variant: instance.variant,
            region: instance.region,
            encoding: instance.encoding,
            rtl?: instance.rtl?,
            script_type: instance.script_type
          }
        end
      end
    end
  end
end
