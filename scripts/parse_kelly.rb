#!/usr/bin/env ruby
# frozen_string_literal: true

require 'roo'
require 'roo-xls' # Required for XLS (Excel 97-2003) support
require 'json'
require 'fileutils'

##
# Kelly Frequency List Parser for Kotoshu
#
# This script parses Kelly Project Excel frequency lists and converts them
# to Kotoshu-compatible JSON format.
#
# Usage:
#   ruby scripts/parse_kelly.rb
#
# Input:
#   Kelly Excel files (en_m3.xls, ru_m3.xls, etc.)
#
# Output:
#   data/en.json, data/ru.json (Kotoshu-compatible frequency files)
#
# Attribution:
#   Kelly Project - University of Leeds & University of Gothenburg
#   Kilgarriff, A., et al. (2014). Corpus-based vocabulary lists for language
#   learners for nine languages. Language Resources and Evaluation, 48(2), 121-163.
#   DOI: https://doi.org/10.1015/lre-2014-0012
#

module KellyParser
  # Language mapping from Kelly codes to ISO 639-1
  LANGUAGE_CODES = {
    'en' => { name: 'English', file: 'en_m3.xls' },
    'ru' => { name: 'Russian', file: 'ru_m3.xls' },
    'it' => { name: 'Italian', file: 'it_m3.xls' },
    'ar' => { name: 'Arabic', file: 'ar_m3.xls' },
    'zh' => { name: 'Chinese', file: 'zh_m3.xls' }
  }.freeze

  # CEFR level ordering for bonus scores
  CEFR_LEVELS = %w[A1 A2 B1 B2 C1 C2].freeze

  class ExcelParser
    attr_reader :filepath, :language_code

    # Column format constants
    ENGLISH_FORMAT = { word: 1, pos: 2, cefr: 3, points: 4, id: 0 }.freeze
    RUSSIAN_FORMAT = { word: 0, cefr: 1, pos: 2, freq_abs: 3, freq_ipm: 4 }.freeze

    def initialize(filepath, language_code)
      @filepath = filepath
      @language_code = language_code
      @data = []
      @format = nil
    end

    # Parse Kelly Excel file and extract word data
    # Two known formats:
    # English format: [ID, Word, POS, CEFR, Points]
    # Russian format: [Word, CEFR, POS, Frq abs, Frq ipm]
    def parse
      puts "Parsing #{@filepath}..."

      workbook = Roo::Spreadsheet.open(@filepath)

      # Use first sheet
      sheet_name = workbook.sheets.first
      sheet = workbook.sheet(sheet_name)
      puts "  Sheet: #{sheet_name}"
      puts "  Dimensions: #{sheet.last_row} rows x #{sheet.last_column} columns"

      # Detect column format from header row
      @format = detect_format(sheet.row(1))
      puts "  Format: #{@format == ENGLISH_FORMAT ? 'English' : 'Russian'}"

      # Skip header row (row 1)
      current_row = 2

      while (row = sheet.row(current_row))
        break if row.all?(&:nil?) # Stop at empty row

        # Don't stop if ID is nil but word exists (some rows have missing IDs)
        word_col = @format[:word]
        next if row[word_col].nil? || row[word_col].to_s.strip.empty? # Skip if word column is empty

        word_data = extract_word_data(row)
        @data << word_data if word_data

        current_row += 1
      end

      puts "  Parsed #{@data.size} words"
      workbook.close
      @data
    end

    private

    # Detect column format from header row
    def detect_format(header_row)
      # English format: ["ID", "Word", "POS", "CEFR", "Points"]
      # Russian format: ["Lemma", "CEFR", "POS", "Frq abs", "Frq ipm"]
      header_str = header_row.map { |h| h.to_s.downcase }.join(' ')

      if header_str.include?('id') && header_str.include?('points')
        ENGLISH_FORMAT
      elsif header_str.include?('lemma') && header_str.include?('frq')
        RUSSIAN_FORMAT
      else
        # Default to English format for backwards compatibility
        ENGLISH_FORMAT
      end
    end

    # Extract word data from Kelly Excel format row
    # Handles both English and Russian formats
    def extract_word_data(row)
      return nil if row.size < 5

      word_col = @format[:word]
      return nil if row[word_col].nil? || row[word_col].to_s.strip.empty?

      word = row[word_col].to_s.strip
      return nil if word.empty?

      # Extract CEFR based on format
      cefr_col = @format[:cefr]
      cefr_raw = row[cefr_col].to_s.strip
      cefr = extract_cefr(cefr_raw)

      # Extract frequency data
      if @format == RUSSIAN_FORMAT
        # Russian format: use Frq ipm (instances per million)
        ipm = row[@format[:freq_ipm]].to_s.to_f
        # Use row index as rank (no explicit ID column)
        rank = @data.size + 1
      else
        # English format: use Points as frequency proxy
        ipm = row[@format[:points]].to_s.to_f
        # Use ID column as rank
        rank = row[@format[:id]].to_s.to_i
      end

      {
        word: word,
        ipm: ipm,
        cefr: cefr,
        rank: rank,
        pos: row[@format[:pos]].to_s.strip
      }
    end

    # Extract CEFR level from raw string, handling fancy quotes
    def extract_cefr(cefr_raw)
      return nil if cefr_raw.nil? || cefr_raw.empty?

      # Remove all types of quotes including fancy quotes using Unicode ranges
      cefr_clean = cefr_raw.gsub(/["\u201C\u201D']/, '').strip.upcase
      cefr_clean if CEFR_LEVELS.include?(cefr_clean)
    end
  end

  # Generate Kotoshu-compatible JSON format
  class JsonGenerator
    attr_reader :data, :language_code, :language_name

    def initialize(data, language_code, language_name)
      @data = data
      @language_code = language_code
      @language_name = language_name
    end

    # Generate Kotoshu-compatible JSON structure
    def generate
      # Sort by rank (ID number) to maintain frequency order
      # Filter out entries without rank
      ranked_data = @data.select { |d| d[:rank] && d[:rank] > 0 }
      sorted_data = ranked_data.sort_by { |d| d[:rank] }

      {
        metadata: metadata,
        tiers: generate_tiers(sorted_data),
        full_list: sorted_data
      }
    end

    private

    def metadata
      {
        language: @language_code,
        language_name: @language_name,
        source: "Kelly Project - University of Leeds & University of Gothenburg",
        source_url: "https://spraakbanken.gu.se/eng/kelly",
        citation: "Kilgarriff, A., Charalabopoulou, F., Gavrilidou, M., Johannessen, L. B., " \
                   "Khalil, S., Kokkinakis, S., Lew, R., Sharoff, S., Vadlapudi, R., " \
                   "Volodina, E. (2014). Corpus-based vocabulary lists for language learners " \
                   "for nine languages. Language Resources and Evaluation, 48(2), 121-163.",
        doi: "https://doi.org/10.1015/lre-2014-0012",
        total_words: @data.size,
        cefr_levels: @data.map { |d| d[:cefr] }.compact.uniq.sort,
        license: "Research use - see Kelly project terms",
        processed_date: Time.now.utc.iso8601,
        kotoshu_version: "1.0.0",
        note: "Generated from Kelly Project frequency lists. See ATTRIBUTION.md for details."
      }
    end

    def generate_tiers(sorted_data)
      tiers = {}

      # Top N tiers
      tiers[:top_50] = create_tier(sorted_data.first(50), "Top 50 most frequent words", 200)
      tiers[:top_200] = create_tier(sorted_data.first(200), "Top 200 most frequent words", 100)
      tiers[:top_1000] = create_tier(sorted_data.first(1000), "Top 1000 most frequent words", 50)

      # CEFR-level tiers
      CEFR_LEVELS.each do |level|
        level_data = sorted_data.select { |d| d[:cefr] == level }
        level_sym = level.downcase.to_sym
        bonus_score = case level
                      when 'A1' then 150
                      when 'A2' then 120
                      when 'B1' then 90
                      when 'B2' then 60
                      when 'C1' then 30
                      when 'C2' then 20
                      else 0
                      end
        tiers[level_sym] = create_tier(level_data.map { |d| d[:word] },
                                       "CEFR #{level} level words",
                                       bonus_score)
      end

      tiers
    end

    def create_tier(words, description, bonus_score)
      {
        words: words.map { |d| d.is_a?(Hash) ? d[:word] : d },
        description: description,
        bonus_score: bonus_score
      }
    end
  end

  # CLI interface
  class CLI
    KELLY_PATH = '/Users/mulgogi/src/external/ssharoff.github.io/kelly'
    OUTPUT_DIR = 'data'

    def run
      puts "=" * 70
      puts "Kelly Frequency List Parser for Kotoshu"
      puts "=" * 70
      puts

      FileUtils.mkdir_p(OUTPUT_DIR)

      # Parse English
      process_language('en')

      # Parse Russian
      process_language('ru')

      puts
      puts "=" * 70
      puts "Parsing complete!"
      puts "=" * 70
      puts
      puts "Generated files:"
      Dir.glob(File.join(OUTPUT_DIR, '*.json')).each do |file|
        puts "  #{file}"
      end
    end

    private

    def process_language(code)
      info = LANGUAGE_CODES[code]
      return unless info

      filepath = File.join(KELLY_PATH, info[:file])
      return unless File.exist?(filepath)

      puts "Processing #{info[:name]} (#{code})..."
      parser = ExcelParser.new(filepath, code)
      data = parser.parse

      if data.empty?
        puts "  Warning: No data parsed, skipping JSON generation"
        return
      end

      generator = JsonGenerator.new(data, code, info[:name])
      json_data = generator.generate

      output_file = File.join(OUTPUT_DIR, "#{code}.json")
      File.write(output_file, JSON.pretty_generate(json_data))

      puts "  Generated: #{output_file}"
      puts "  Total words: #{json_data[:metadata][:total_words]}"
      puts "  CEFR levels: #{json_data[:metadata][:cefr_levels].join(', ')}"
      puts
    end
  end
end

# Run if executed directly
if __FILE__ == $PROGRAM_NAME
  KellyParser::CLI.new.run
end
