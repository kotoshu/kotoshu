#!/usr/bin/env ruby
# frozen_string_literal: true

# Vocabulary extraction script for FastText models.
#
# Extracts word-to-index mappings from FastText .vec files
# and saves them as .vocab.json files for ONNX model loading.
#
# Usage:
#   ruby scripts/extract_vocabularies.rb [options]
#
# Options:
#   --languages=LANGS    Comma-separated list of language codes (default: all 157)
#   --input-dir=DIR      Input directory for .vec files (default: ./fasttext-vec)
#   --output-dir=DIR     Output directory for .vocab.json files (default: ./vocabularies)
#   --vocab-size=N       Maximum vocabulary size (default: 100000)
#   --download           Download .vec files from FastText CDN if missing
#   --verbose            Show detailed progress

require 'fileutils'
require 'json'
require 'net/http'
require 'uri'
require 'zlib'
require 'optparse'

# Full list of 157 FastText language codes
ALL_LANGUAGES = %w[
  af als am an ar arz as ast av az azj ba bar bcl be bg bh bm bn bo br bs
  bxr ca cbk ce ceb ckb cmn co cs cv cy da de diq dsb dty dv el en eo es
  et eu fa fi fr frr fy ga gd gl gn gom gu gv he hi hif hr hsb ht hu hy
  ia id ie ilo io is it ja jbo jv ka kk km kn ko krc ku ky la lad lb lmo
  lt lv mai mg mhr min mk ml mn mr mrj ms mt mwl my myv mzn nah nap nds
  ne new nl nn no oc or os pa pam pfl pms pnb ps pt qu rm ro ru rue sa
  sah scn sco sd sh si sk sl so sq sr su sv sw ta te tg th tk tl tr tt
  ty ug uk ur uz vec vi vls vo wa war wuu xh yi yo zh zh-classical
].freeze

# FastText CDN base URL
FASTTEXT_CDN = 'https://dl.fbaipublicfiles.com/fasttext/vectors-crawl'

# Default options
options = {
  languages: [],
  input_dir: File.expand_path('../fasttext-vec', __dir__),
  output_dir: File.expand_path('../vocabularies', __dir__),
  vocab_size: 100_000,
  download: false,
  verbose: false
}

# Parse command line options
OptionParser.new do |opts|
  opts.banner = "Usage: ruby #{$PROGRAM_NAME} [options]"

  opts.on('--languages=LANGS', Array, 'Comma-separated list of language codes (default: all 157)') do |langs|
    options[:languages] = langs
  end

  opts.on('--input-dir=DIR', 'Input directory for .vec files') do |dir|
    options[:input_dir] = File.expand_path(dir)
  end

  opts.on('--output-dir=DIR', 'Output directory for .vocab.json files') do |dir|
    options[:output_dir] = File.expand_path(dir)
  end

  opts.on('--vocab-size=N', Integer, 'Maximum vocabulary size') do |size|
    options[:vocab_size] = size
  end

  opts.on('--download', 'Download .vec files from FastText CDN if missing') do
    options[:download] = true
  end

  opts.on('--verbose', 'Show detailed progress') do
    options[:verbose] = true
  end

  opts.on('-h', '--help', 'Show this help message') do
    puts opts
    exit
  end
end.parse!

# Default to all languages if none specified
options[:languages] = ALL_LANGUAGES if options[:languages].empty?

# Helper methods
module VocabularyExtractor
  # Download FastText .vec file for a language.
  #
  # @param lang [String] Language code
  # @param output_dir [String] Output directory
  # @return [String, nil] Path to downloaded file or nil if failed
  def self.download_fasttext_vec(lang, output_dir)
    filename = "cc.#{lang}.300.vec.gz"
    url = "#{FASTTEXT_CDN}/#{filename}"

    puts "  Downloading #{filename} from FastText CDN..." if options[:verbose]

    FileUtils.mkdir_p(output_dir)

    output_path = File.join(output_dir, filename)
    temp_path = "#{output_path}.tmp"

    begin
      # Download with progress
      uri = URI(url)
      downloaded_bytes = 0

      File.open(temp_path, 'wb') do |file|
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 30, read_timeout: 600) do |http|
          http.request_get(uri.path) do |response|
            response.read_body do |chunk|
              file.write(chunk)
              downloaded_bytes += chunk.length

              if options[:verbose] && downloaded_bytes % (10 * 1024 * 1024) < chunk.length
                puts "    Downloaded: #{(downloaded_bytes.to_f / 1024 / 1024).round(1)} MB..."
              end
            end
          end
        end
      end

      # Verify download
      unless File.exist?(temp_path) && File.size(temp_path) > 0
        puts "    ERROR: Download failed or file is empty" if options[:verbose]
        File.delete(temp_path) if File.exist?(temp_path)
        return nil
      end

      # Rename to final path
      File.rename(temp_path, output_path)

      puts "  ✓ Downloaded: #{(File.size(output_path).to_f / 1024 / 1024).round(1)} MB" if options[:verbose]

      output_path
    rescue StandardError => e
      puts "    ERROR: #{e.message}" if options[:verbose]
      File.delete(temp_path) if File.exist?(temp_path)
      nil
    end
  end

  # Decompress .vec.gz file to .vec file.
  #
  # @param gz_path [String] Path to .vec.gz file
  # @return [String, nil] Path to decompressed file or nil if failed
  def self.decompress_vec(gz_path)
    vec_path = gz_path.sub('.gz', '')

    return vec_path if File.exist?(vec_path) && File.size(vec_path) > 0

    puts "  Decompressing #{File.basename(gz_path)}..." if options[:verbose]

    begin
      FileUtils.mkdir_p(File.dirname(vec_path))

      File.open(vec_path, 'wb') do |out_file|
        Zlib::GzipReader.open(gz_path) do |gz|
          chunk_size = 65_536 # 64KB chunks
          while (chunk = gz.read(chunk_size))
            out_file.write(chunk)
          end
        end
      end

      puts "  ✓ Decompressed: #{(File.size(vec_path).to_f / 1024 / 1024).round(1)} MB" if options[:verbose]

      vec_path
    rescue StandardError => e
      puts "    ERROR: #{e.message}" if options[:verbose]
      nil
    end
  end

  # Extract vocabulary from FastText .vec file.
  #
  # @param vec_path [String] Path to .vec file
  # @param vocab_size [Integer] Maximum vocabulary size
  # @return [Hash, nil] Word-to-index mapping or nil if failed
  def self.extract_vocabulary(vec_path, vocab_size)
    puts "  Extracting vocabulary from #{File.basename(vec_path)}..." if options[:verbose]

    begin
      word_to_index = {}
      index = 0

      File.open(vec_path, 'r', encoding: 'UTF-8') do |file|
        # Skip first line (header: vocab_size dimension)
        file.gets

        # Read words
        while (line = file.gets) && index < vocab_size
          # Split on first space (word followed by embedding values)
          parts = line.split(' ', 2)
          word = parts.first

          # Skip empty words
          next if word.nil? || word.empty?

          word_to_index[word] = index
          index += 1

          # Progress
          if options[:verbose] && index % 10_000 == 0
            puts "    Processed #{index} words..."
          end
        end
      end

      puts "  ✓ Extracted #{word_to_index.size} words" if options[:verbose]

      word_to_index
    rescue StandardError => e
      puts "    ERROR: #{e.message}" if options[:verbose]
      nil
    end
  end

  # Save vocabulary to JSON file.
  #
  # @param vocabulary [Hash] Word-to-index mapping
  # @param output_path [String] Output file path
  # @return [Boolean] True if successful
  def self.save_vocabulary(vocabulary, output_path)
    puts "  Saving to #{File.basename(output_path)}..." if options[:verbose]

    begin
      FileUtils.mkdir_p(File.dirname(output_path))

      File.write(output_path, JSON.pretty_generate(vocabulary))

      puts "  ✓ Saved: #{(File.size(output_path).to_f / 1024).round(1)} KB" if options[:verbose]

      true
    rescue StandardError => e
      puts "    ERROR: #{e.message}" if options[:verbose]
      false
    end
  end

  # Process a single language.
  #
  # @param lang [String] Language code
  # @return [Boolean] True if successful
  def self.process_language(lang)
    puts "\n[#{lang}] Processing..." if options[:verbose]

    # Check for existing .vec file
    vec_gz_path = File.join(options[:input_dir], "cc.#{lang}.300.vec.gz")
    vec_path = vec_gz_path.sub('.gz', '')

    # Download if missing and requested
    if options[:download] && !File.exist?(vec_path)
      downloaded = download_fasttext_vec(lang, options[:input_dir])
      if downloaded.nil?
        puts "  [#{lang}] Skipped (download failed)" if options[:verbose]
        return false
      end
      vec_gz_path = downloaded
    end

    # Check for .vec file
    if !File.exist?(vec_path) && File.exist?(vec_gz_path)
      vec_path = decompress_vec(vec_gz_path)
    elsif !File.exist?(vec_path)
      puts "  [#{lang}] Skipped (no .vec file found)" if options[:verbose]
      return false
    end

    # Extract vocabulary
    vocabulary = extract_vocabulary(vec_path, options[:vocab_size])
    return false if vocabulary.nil?

    # Save vocabulary
    output_path = File.join(options[:output_dir], "#{lang}", "fasttext.#{lang}.vocab.json")
    save_vocabulary(vocabulary, output_path)
  end

  # Process all languages.
  #
  # @return [Hash] Statistics
  def self.process_all
    stats = {
      total: options[:languages].size,
      success: 0,
      failed: 0,
      skipped: 0
    }

    puts "Starting vocabulary extraction for #{stats[:total]} languages..."
    puts "Input directory: #{options[:input_dir]}"
    puts "Output directory: #{options[:output_dir]}"
    puts "Vocabulary size: #{options[:vocab_size]}"
    puts

    options[:languages].each do |lang|
      result = process_language(lang)

      case result
      when true
        stats[:success] += 1
      when false
        stats[:failed] += 1
      else
        stats[:skipped] += 1
      end
    end

    puts "\n" + '=' * 60
    puts "Extraction complete!"
    puts "=" * 60
    puts "Total languages: #{stats[:total]}"
    puts "Successful:      #{stats[:success]}"
    puts "Failed:          #{stats[:failed]}"
    puts "Skipped:         #{stats[:skipped]}"
    puts "=" * 60

    stats
  end
end

# Run extraction
VocabularyExtractor.process_all
