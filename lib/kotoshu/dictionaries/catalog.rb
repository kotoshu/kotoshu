# frozen_string_literal: true

require_relative "../dictionary/hunspell"
require_relative "../dictionary/plain_text"

module Kotoshu
  module Dictionaries
    # Catalog of all available dictionaries from kotoshu/dictionaries repository
    #
    # This class provides a structured registry of all available dictionaries
    # with their metadata, URLs, and license information.
    #
    # @example Listing all dictionaries
    #   catalog = Kotoshu::Dictionaries::Catalog.new
    #   catalog.all.each do |dict|
    #     puts "#{dict.code}: #{dict.name} (#{dict.size} words)"
    #   end
    #
    # @example Finding dictionaries by language
    #   catalog = Kotoshu::Dictionaries::Catalog.new
    #   german_dicts = catalog.by_language("de")
    #
    # @example Getting a specific dictionary
    #   catalog = Kotoshu::Dictionaries::Catalog.new
    #   dict = catalog.find("en-GB")
    #   dict.load # => Kotoshu::Dictionary::Base subclass
    #
    class Catalog
      # Dictionary entry in the catalog
      class DictionaryEntry
        attr_reader :code, :name, :language, :region, :format,
                    :source, :license, :word_count, :dic_url, :aff_url,
                    :metadata

        def initialize(code:, name:, language:, region: nil, format:,
                       source:, license:, word_count:, dic_url:, aff_url: nil,
                       metadata: {})
          @code = code
          @name = name
          @language = language
          @region = region
          @format = format
          @source = source
          @license = license
          @word_count = word_count
          @dic_url = dic_url
          @aff_url = aff_url
          @metadata = metadata
          freeze
        end

        # Load this dictionary from URL
        # @return [Kotoshu::Dictionary::Base] The loaded dictionary
        def load
          case @format
          when :hunspell
            raise ArgumentError, "Missing aff_url for Hunspell dictionary" unless @aff_url
            Kotoshu::Dictionary::Hunspell.new(
              dic_path: @dic_url,
              aff_path: @aff_url,
              language_code: @code,
              metadata: @metadata
            )
          when :plain_text
            Kotoshu::Dictionary::PlainText.new(
              @dic_url,
              language_code: @code,
              metadata: @metadata
            )
          else
            raise ArgumentError, "Unknown format: #{@format}"
          end
        end

        # @return [String] Human-readable description
        def description
          region_part = @region ? " (#{@region})" : ""
          "#{@name}#{region_part} - #{@word_count} words"
        end

        # @return [Boolean] true if this is a Hunspell dictionary
        def hunspell?
          @format == :hunspell
        end

        # @return [Boolean] true if this is a plain text dictionary
        def plain_text?
          @format == :plain_text
        end
      end

      # Base URL for kotoshu/dictionaries repository
      BASE_URL = "https://raw.githubusercontent.com/kotoshu/dictionaries/main".freeze

      # All available dictionaries
      ALL_DICTIONARIES = [
        # Unix System Dictionaries (Plain Text)
        { code: "en-US-web2", name: "Webster's Second International", language: "en", region: "US",
          format: :plain_text, source: "FreeBSD", license: "Public Domain",
          word_count: 235_976,
          dic_url: "#{BASE_URL}/unix-words/web2.txt",
          metadata: { source_file: "web2.txt", year: 1934 } },

        { code: "en-US-web2a", name: "Webster's with Affix Flags", language: "en", region: "US",
          format: :plain_text, source: "FreeBSD", license: "Public Domain",
          word_count: 50_000,
          dic_url: "#{BASE_URL}/unix-words/web2a.txt",
          metadata: { source_file: "web2a.txt", has_affix_flags: true } },

        { code: "en-connectives", name: "English Connectives", language: "en",
          format: :plain_text, source: "FreeBSD", license: "Public Domain",
          word_count: 500,
          dic_url: "#{BASE_URL}/unix-words/connectives.txt",
          metadata: { source_file: "connectives.txt" } },

        { code: "en-propernames", name: "Proper Names", language: "en",
          format: :plain_text, source: "FreeBSD", license: "Public Domain",
          word_count: 2000,
          dic_url: "#{BASE_URL}/unix-words/propernames.txt",
          metadata: { source_file: "propernames.txt" } },

        # English (Hunspell from wooorm/dictionaries)
        { code: "en", name: "US English", language: "en", region: "US",
          format: :hunspell, source: "SCOWL", license: "LGPL/MPL/GPL",
          word_count: 500_000,
          dic_url: "#{BASE_URL}/en/index.dic",
          aff_url: "#{BASE_URL}/en/index.aff",
          metadata: { scowl_size: "large", source: "wooorm/dictionaries" } },

        { code: "en-GB", name: "British English (ise)", language: "en", region: "GB",
          format: :hunspell, source: "SCOWL", license: "LGPL/MPL/GPL",
          word_count: 450_000,
          dic_url: "#{BASE_URL}/en-GB/index.dic",
          aff_url: "#{BASE_URL}/en-GB/index.aff",
          metadata: { spelling_variant: "ise", source: "wooorm/dictionaries" } },

        { code: "en-CA", name: "Canadian English", language: "en", region: "CA",
          format: :hunspell, source: "SCOWL", license: "LGPL/MPL/GPL",
          word_count: 300_000,
          dic_url: "#{BASE_URL}/en-CA/index.dic",
          aff_url: "#{BASE_URL}/en-CA/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "en-AU", name: "Australian English", language: "en", region: "AU",
          format: :hunspell, source: "SCOWL", license: "LGPL/MPL/GPL",
          word_count: 250_000,
          dic_url: "#{BASE_URL}/en-AU/index.dic",
          aff_url: "#{BASE_URL}/en-AU/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "en-ZA", name: "South African English", language: "en", region: "ZA",
          format: :hunspell, source: "SCOWL", license: "LGPL/MPL/GPL",
          word_count: 200_000,
          dic_url: "#{BASE_URL}/en-ZA/index.dic",
          aff_url: "#{BASE_URL}/en-ZA/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        # German
        { code: "de", name: "German", language: "de",
          format: :hunspell, source: "igerman98", license: "GPL",
          word_count: 300_000,
          dic_url: "#{BASE_URL}/de/index.dic",
          aff_url: "#{BASE_URL}/de/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "de-AT", name: "German (Austria)", language: "de", region: "AT",
          format: :hunspell, source: "igerman98", license: "GPL",
          word_count: 200_000,
          dic_url: "#{BASE_URL}/de-AT/index.dic",
          aff_url: "#{BASE_URL}/de-AT/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "de-CH", name: "German (Switzerland)", language: "de", region: "CH",
          format: :hunspell, source: "igerman98", license: "GPL",
          word_count: 200_000,
          dic_url: "#{BASE_URL}/de-CH/index.dic",
          aff_url: "#{BASE_URL}/de-CH/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "de-DE", name: "German (Germany)", language: "de", region: "DE",
          format: :hunspell, source: "igerman98", license: "GPL",
          word_count: 300_000,
          dic_url: "#{BASE_URL}/de-DE/index.dic",
          aff_url: "#{BASE_URL}/de-DE/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        # Spanish
        { code: "es", name: "Spanish", language: "es",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 500_000,
          dic_url: "#{BASE_URL}/es/index.dic",
          aff_url: "#{BASE_URL}/es/index.aff",
          metadata: { source: "wooorm/dictionaries", regional_variants: 21 } },

        { code: "es-AR", name: "Spanish (Argentina)", language: "es", region: "AR",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 400_000,
          dic_url: "#{BASE_URL}/es-AR/index.dic",
          aff_url: "#{BASE_URL}/es-AR/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "es-MX", name: "Spanish (Mexico)", language: "es", region: "MX",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 400_000,
          dic_url: "#{BASE_URL}/es-MX/index.dic",
          aff_url: "#{BASE_URL}/es-MX/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        # French
        { code: "fr", name: "French", language: "fr",
          format: :hunspell, source: "Grammalecte", license: "MPL 2.0",
          word_count: 200_000,
          dic_url: "#{BASE_URL}/fr/index.dic",
          aff_url: "#{BASE_URL}/fr/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "fr-FR", name: "French (France)", language: "fr", region: "FR",
          format: :hunspell, source: "Grammalecte", license: "MPL 2.0",
          word_count: 200_000,
          dic_url: "#{BASE_URL}/fr-FR/index.dic",
          aff_url: "#{BASE_URL}/fr-FR/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        # Italian
        { code: "it", name: "Italian", language: "it",
          format: :hunspell, source: "LibreOffice", license: "GPL 3",
          word_count: 500_000,
          dic_url: "#{BASE_URL}/it/index.dic",
          aff_url: "#{BASE_URL}/it/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        # Portuguese
        { code: "pt", name: "Portuguese", language: "pt",
          format: :hunspell, source: "LibreOffice", license: "LGPLv3/MPL",
          word_count: 400_000,
          dic_url: "#{BASE_URL}/pt/index.dic",
          aff_url: "#{BASE_URL}/pt/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        # Russian
        { code: "ru", name: "Russian", language: "ru",
          format: :hunspell, source: "Alexander Lebedev", license: "BSD-style",
          word_count: 800_000,
          dic_url: "#{BASE_URL}/ru/index.dic",
          aff_url: "#{BASE_URL}/ru/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        # Dutch
        { code: "nl", name: "Dutch", language: "nl",
          format: :hunspell, source: "OpenTaal", license: "Revised BSD + CC BY 3.0",
          word_count: 400_000,
          dic_url: "#{BASE_URL}/nl/index.dic",
          aff_url: "#{BASE_URL}/nl/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        # Polish
        { code: "pl", name: "Polish", language: "pl",
          format: :hunspell, source: "Polish Native Lang Project", license: "GPL/LGPL/MPL/CC",
          word_count: 600_000,
          dic_url: "#{BASE_URL}/pl/index.dic",
          aff_url: "#{BASE_URL}/pl/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        # Additional European languages
        { code: "cs", name: "Czech", language: "cs",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 400_000,
          dic_url: "#{BASE_URL}/cs/index.dic",
          aff_url: "#{BASE_URL}/cs/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "sk", name: "Slovak", language: "sk",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 300_000,
          dic_url: "#{BASE_URL}/sk/index.dic",
          aff_url: "#{BASE_URL}/sk/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "hr", name: "Croatian", language: "hr",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 300_000,
          dic_url: "#{BASE_URL}/hr/index.dic",
          aff_url: "#{BASE_URL}/hr/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "sr", name: "Serbian (Cyrillic)", language: "sr",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 400_000,
          dic_url: "#{BASE_URL}/sr/index.dic",
          aff_url: "#{BASE_URL}/sr/index.aff",
          metadata: { source: "wooorm/dictionaries", script: "Cyrillic" } },

        { code: "sr-Latn", name: "Serbian (Latin)", language: "sr", region: "Latn",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 400_000,
          dic_url: "#{BASE_URL}/sr-Latn/index.dic",
          aff_url: "#{BASE_URL}/sr-Latn/index.aff",
          metadata: { source: "wooorm/dictionaries", script: "Latin" } },

        { code: "sl", name: "Slovenian", language: "sl",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 200_000,
          dic_url: "#{BASE_URL}/sl/index.dic",
          aff_url: "#{BASE_URL}/sl/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        # Baltic languages
        { code: "lt", name: "Lithuanian", language: "lt",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 200_000,
          dic_url: "#{BASE_URL}/lt/index.dic",
          aff_url: "#{BASE_URL}/lt/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "lv", name: "Latvian", language: "lv",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 250_000,
          dic_url: "#{BASE_URL}/lv/index.dic",
          aff_url: "#{BASE_URL}/lv/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "et", name: "Estonian", language: "et",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 200_000,
          dic_url: "#{BASE_URL}/et/index.dic",
          aff_url: "#{BASE_URL}/et/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        # Nordic languages
        { code: "da", name: "Danish", language: "da",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 300_000,
          dic_url: "#{BASE_URL}/da/index.dic",
          aff_url: "#{BASE_URL}/da/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "sv", name: "Swedish", language: "sv",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 350_000,
          dic_url: "#{BASE_URL}/sv/index.dic",
          aff_url: "#{BASE_URL}/sv/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "sv-FI", name: "Swedish (Finland)", language: "sv", region: "FI",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 300_000,
          dic_url: "#{BASE_URL}/sv-FI/index.dic",
          aff_url: "#{BASE_URL}/sv-FI/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "nb", name: "Norwegian (Bokmål)", language: "nb",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 300_000,
          dic_url: "#{BASE_URL}/nb/index.dic",
          aff_url: "#{BASE_URL}/nb/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "nn", name: "Norwegian (Nynorsk)", language: "nn",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 250_000,
          dic_url: "#{BASE_URL}/nn/index.dic",
          aff_url: "#{BASE_URL}/nn/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "fi", name: "Finnish", language: "fi",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 400_000,
          dic_url: "#{BASE_URL}/fi/index.dic",
          aff_url: "#{BASE_URL}/fi/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "is", name: "Icelandic", language: "is",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 200_000,
          dic_url: "#{BASE_URL}/is/index.dic",
          aff_url: "#{BASE_URL}/is/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "fo", name: "Faroese", language: "fo",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 100_000,
          dic_url: "#{BASE_URL}/fo/index.dic",
          aff_url: "#{BASE_URL}/fo/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        # Celtic languages
        { code: "ga", name: "Irish", language: "ga",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 50_000,
          dic_url: "#{BASE_URL}/ga/index.dic",
          aff_url: "#{BASE_URL}/ga/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "gd", name: "Scottish Gaelic", language: "gd",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 50_000,
          dic_url: "#{BASE_URL}/gd/index.dic",
          aff_url: "#{BASE_URL}/gd/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "cy", name: "Welsh", language: "cy",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 100_000,
          dic_url: "#{BASE_URL}/cy/index.dic",
          aff_url: "#{BASE_URL}/cy/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "br", name: "Breton", language: "br",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 50_000,
          dic_url: "#{BASE_URL}/br/index.dic",
          aff_url: "#{BASE_URL}/br/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "gv", name: "Manx", language: "gv",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 30_000,
          dic_url: "#{BASE_URL}/gv/index.dic",
          aff_url: "#{BASE_URL}/gv/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        # Other European languages
        { code: "el", name: "Greek", language: "el",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 400_000,
          dic_url: "#{BASE_URL}/el/index.dic",
          aff_url: "#{BASE_URL}/el/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "el-polyton", name: "Greek (Polytonic)", language: "el", region: "polyton",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 100_000,
          dic_url: "#{BASE_URL}/el-polyton/index.dic",
          aff_url: "#{BASE_URL}/el-polyton/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "tr", name: "Turkish", language: "tr",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 400_000,
          dic_url: "#{BASE_URL}/tr/index.dic",
          aff_url: "#{BASE_URL}/tr/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "hu", name: "Hungarian", language: "hu",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 400_000,
          dic_url: "#{BASE_URL}/hu/index.dic",
          aff_url: "#{BASE_URL}/hu/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "ro", name: "Romanian", language: "ro",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 300_000,
          dic_url: "#{BASE_URL}/ro/index.dic",
          aff_url: "#{BASE_URL}/ro/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "bg", name: "Bulgarian", language: "bg",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 300_000,
          dic_url: "#{BASE_URL}/bg/index.dic",
          aff_url: "#{BASE_URL}/bg/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "be", name: "Belarusian", language: "be",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 200_000,
          dic_url: "#{BASE_URL}/be/index.dic",
          aff_url: "#{BASE_URL}/be/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "uk", name: "Ukrainian", language: "uk",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 400_000,
          dic_url: "#{BASE_URL}/uk/index.dic",
          aff_url: "#{BASE_URL}/uk/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        # Regional languages
        { code: "ca", name: "Catalan", language: "ca",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 400_000,
          dic_url: "#{BASE_URL}/ca/index.dic",
          aff_url: "#{BASE_URL}/ca/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "ca-valencia", name: "Catalan (Valencia)", language: "ca", region: "valencia",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 400_000,
          dic_url: "#{BASE_URL}/ca-valencia/index.dic",
          aff_url: "#{BASE_URL}/ca-valencia/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "gl", name: "Galician", language: "gl",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 300_000,
          dic_url: "#{BASE_URL}/gl/index.dic",
          aff_url: "#{BASE_URL}/gl/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "eu", name: "Basque", language: "eu",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 200_000,
          dic_url: "#{BASE_URL}/eu/index.dic",
          aff_url: "#{BASE_URL}/eu/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "lb", name: "Luxembourgish", language: "lb",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 100_000,
          dic_url: "#{BASE_URL}/lb/index.dic",
          aff_url: "#{BASE_URL}/lb/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "li", name: "Limburgish", language: "li",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 50_000,
          dic_url: "#{BASE_URL}/li/index.dic",
          aff_url: "#{BASE_URL}/li/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "fy", name: "Western Frisian", language: "fy",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 100_000,
          dic_url: "#{BASE_URL}/fy/index.dic",
          aff_url: "#{BASE_URL}/fy/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "ltg", name: "Latgalian", language: "ltg",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 50_000,
          dic_url: "#{BASE_URL}/ltg/index.dic",
          aff_url: "#{BASE_URL}/ltg/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "ku", name: "Kurdish", language: "ku",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 50_000,
          dic_url: "#{BASE_URL}/ku/index.dic",
          aff_url: "#{BASE_URL}/ku/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        # Middle Eastern languages
        { code: "hy", name: "Armenian", language: "hy",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 200_000,
          dic_url: "#{BASE_URL}/hy/index.dic",
          aff_url: "#{BASE_URL}/hy/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "hyw", name: "Western Armenian", language: "hy", region: "western",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 100_000,
          dic_url: "#{BASE_URL}/hyw/index.dic",
          aff_url: "#{BASE_URL}/hyw/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "ka", name: "Georgian", language: "ka",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 200_000,
          dic_url: "#{BASE_URL}/ka/index.dic",
          aff_url: "#{BASE_URL}/ka/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "he", name: "Hebrew", language: "he",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 300_000,
          dic_url: "#{BASE_URL}/he/index.dic",
          aff_url: "#{BASE_URL}/he/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "fa", name: "Persian", language: "fa",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 200_000,
          dic_url: "#{BASE_URL}/fa/index.dic",
          aff_url: "#{BASE_URL}/fa/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        # Asian languages
        { code: "ko", name: "Korean", language: "ko",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 500_000,
          dic_url: "#{BASE_URL}/ko/index.dic",
          aff_url: "#{BASE_URL}/ko/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "vi", name: "Vietnamese", language: "vi",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 100_000,
          dic_url: "#{BASE_URL}/vi/index.dic",
          aff_url: "#{BASE_URL}/vi/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        # Constructed languages
        { code: "eo", name: "Esperanto", language: "eo",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 100_000,
          dic_url: "#{BASE_URL}/eo/index.dic",
          aff_url: "#{BASE_URL}/eo/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "ia", name: "Interlingua", language: "ia",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 50_000,
          dic_url: "#{BASE_URL}/ia/index.dic",
          aff_url: "#{BASE_URL}/ia/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        # Additional Spanish regional variants
        { code: "es-BO", name: "Spanish (Bolivia)", language: "es", region: "BO",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 350_000,
          dic_url: "#{BASE_URL}/es-BO/index.dic",
          aff_url: "#{BASE_URL}/es-BO/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "es-CO", name: "Spanish (Colombia)", language: "es", region: "CO",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 350_000,
          dic_url: "#{BASE_URL}/es-CO/index.dic",
          aff_url: "#{BASE_URL}/es-CO/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "es-CR", name: "Spanish (Costa Rica)", language: "es", region: "CR",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 350_000,
          dic_url: "#{BASE_URL}/es-CR/index.dic",
          aff_url: "#{BASE_URL}/es-CR/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "es-CU", name: "Spanish (Cuba)", language: "es", region: "CU",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 350_000,
          dic_url: "#{BASE_URL}/es-CU/index.dic",
          aff_url: "#{BASE_URL}/es-CU/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "es-DO", name: "Spanish (Dominican Republic)", language: "es", region: "DO",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 350_000,
          dic_url: "#{BASE_URL}/es-DO/index.dic",
          aff_url: "#{BASE_URL}/es-DO/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "es-EC", name: "Spanish (Ecuador)", language: "es", region: "EC",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 350_000,
          dic_url: "#{BASE_URL}/es-EC/index.dic",
          aff_url: "#{BASE_URL}/es-EC/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "es-GT", name: "Spanish (Guatemala)", language: "es", region: "GT",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 350_000,
          dic_url: "#{BASE_URL}/es-GT/index.dic",
          aff_url: "#{BASE_URL}/es-GT/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "es-HN", name: "Spanish (Honduras)", language: "es", region: "HN",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 350_000,
          dic_url: "#{BASE_URL}/es-HN/index.dic",
          aff_url: "#{BASE_URL}/es-HN/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "es-NI", name: "Spanish (Nicaragua)", language: "es", region: "NI",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 350_000,
          dic_url: "#{BASE_URL}/es-NI/index.dic",
          aff_url: "#{BASE_URL}/es-NI/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "es-PA", name: "Spanish (Panama)", language: "es", region: "PA",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 350_000,
          dic_url: "#{BASE_URL}/es-PA/index.dic",
          aff_url: "#{BASE_URL}/es-PA/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "es-PE", name: "Spanish (Peru)", language: "es", region: "PE",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 350_000,
          dic_url: "#{BASE_URL}/es-PE/index.dic",
          aff_url: "#{BASE_URL}/es-PE/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "es-PH", name: "Spanish (Philippines)", language: "es", region: "PH",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 350_000,
          dic_url: "#{BASE_URL}/es-PH/index.dic",
          aff_url: "#{BASE_URL}/es-PH/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "es-PR", name: "Spanish (Puerto Rico)", language: "es", region: "PR",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 350_000,
          dic_url: "#{BASE_URL}/es-PR/index.dic",
          aff_url: "#{BASE_URL}/es-PR/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "es-PY", name: "Spanish (Paraguay)", language: "es", region: "PY",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 350_000,
          dic_url: "#{BASE_URL}/es-PY/index.dic",
          aff_url: "#{BASE_URL}/es-PY/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "es-SV", name: "Spanish (El Salvador)", language: "es", region: "SV",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 350_000,
          dic_url: "#{BASE_URL}/es-SV/index.dic",
          aff_url: "#{BASE_URL}/es-SV/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "es-US", name: "Spanish (United States)", language: "es", region: "US",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 350_000,
          dic_url: "#{BASE_URL}/es-US/index.dic",
          aff_url: "#{BASE_URL}/es-US/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "es-UY", name: "Spanish (Uruguay)", language: "es", region: "UY",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 350_000,
          dic_url: "#{BASE_URL}/es-UY/index.dic",
          aff_url: "#{BASE_URL}/es-UY/index.aff",
          metadata: { source: "wooorm/dictionaries" } },

        { code: "es-VE", name: "Spanish (Venezuela)", language: "es", region: "VE",
          format: :hunspell, source: "LibreOffice", license: "GPL",
          word_count: 350_000,
          dic_url: "#{BASE_URL}/es-VE/index.dic",
          aff_url: "#{BASE_URL}/es-VE/index.aff",
          metadata: { source: "wooorm/dictionaries" } },
      ].freeze

      # Create catalog entries from data
      @entries = ALL_DICTIONARIES.map do |data|
        DictionaryEntry.new(**data)
      end.freeze

      # @return [Array<DictionaryEntry>] All dictionary entries
      def self.all
        @entries
      end

      # Find dictionary by code
      # @param code [String, Symbol] Dictionary code (e.g., "en-GB", :en_GB)
      # @return [DictionaryEntry, nil] The dictionary entry or nil if not found
      def self.find(code)
        code_str = code.to_s.gsub("_", "-")
        all.find { |e| e.code.casecmp(code_str).zero? }
      end

      # Find dictionaries by language code
      # @param lang [String, Symbol] Language code (e.g., "en", :de)
      # @return [Array<DictionaryEntry>] Dictionaries for the language
      def self.by_language(lang)
        lang_str = lang.to_s.downcase
        all.select { |e| e.language == lang_str }
      end

      # Find dictionaries by format
      # @param format [Symbol] Format type (:hunspell or :plain_text)
      # @return [Array<DictionaryEntry>] Dictionaries with the format
      def self.by_format(format)
        all.select { |e| e.format == format }
      end

      # Find dictionaries by license
      # @param license [String, Symbol] License type (e.g., "GPL", "Public Domain")
      # @return [Array<DictionaryEntry>] Dictionaries with the license
      def self.by_license(license)
        license_str = license.to_s
        all.select { |e| e.license.include?(license_str) }
      end

      # Get all Hunspell dictionaries
      # @return [Array<DictionaryEntry>] All Hunspell dictionaries
      def self.hunspell
        by_format(:hunspell)
      end

      # Get all plain text dictionaries
      # @return [Array<DictionaryEntry>] All plain text dictionaries
      def self.plain_text
        by_format(:plain_text)
      end

      # Get statistics about the catalog
      # @return [Hash] Statistics hash
      def self.statistics
        {
          total: all.size,
          hunspell: hunspell.size,
          plain_text: plain_text.size,
          languages: all.map(&:language).uniq.size,
          total_words: all.sum(&:word_count),
          formats: all.group_by(&:format).transform_values(&:size),
          licenses: all.group_by { |e| e.license.split.first }.transform_values(&:size)
        }
      end

      # Get all unique language codes
      # @return [Array<String>] Unique language codes
      def self.languages
        all.map(&:language).uniq.sort
      end

      # Get all unique licenses
      # @return [Array<String>] Unique license types
      def self.licenses
        all.map(&:license).uniq
      end
    end
  end
end
