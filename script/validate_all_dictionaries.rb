#!/usr/bin/env ruby
# frozen_string_literal: true

# Dictionary Validation Script
#
# This script validates all dictionaries in the kotoshu/dictionaries catalog
# by loading them from GitHub and testing basic functionality.
#
# Usage:
#   ruby script/validate_all_dictionaries.rb [--full] [--lang LANG] [--code CODE]
#
# Options:
#   --full       Run full validation including suggestion tests (slow)
#   --lang LANG  Only test dictionaries for this language (e.g., en, de, fr)
#   --code CODE  Only test this specific dictionary code (e.g., en-GB, de-AT)
#   --format FMT Only test dictionaries with this format (hunspell, plain_text)

require_relative "../lib/kotoshu"
require "optparse"
require "benchmark"
require "json"

# ANSI color codes for terminal output
module Colors
  RESET = "\e[0m"
  RED = "\e[31m"
  GREEN = "\e[32m"
  YELLOW = "\e[33m"
  BLUE = "\e[34m"
  MAGENTA = "\e[35m"
  CYAN = "\e[36m"
  BOLD = "\e[1m"
end

# Validation result for a single dictionary
class ValidationResult
  attr_reader :code, :status, :load_time, :size, :test_results, :error

  def initialize(code)
    @code = code
    @status = :pending # :pending, :success, :warning, :error
    @load_time = nil
    @size = nil
    @test_results = {}
    @error = nil
  end

  def success!(load_time, size)
    @status = :success
    @load_time = load_time
    @size = size
  end

  def warning!(load_time, size, message)
    @status = :warning
    @load_time = load_time
    @size = size
    @test_results[:warning] = message
  end

  def error!(error)
    @status = :error
    @error = error
  end

  def add_test_result(name, passed, details = nil)
    @test_results[name] = { passed: passed, details: details }
  end

  def success?
    @status == :success
  end

  def error?
    @status == :error
  end

  def warning?
    @status == :warning
  end

  def to_h
    {
      code: @code,
      status: @status,
      load_time: @load_time,
      size: @size,
      test_results: @test_results,
      error: @error&.message
    }
  end
end

# Main validator class
class DictionaryValidator
  attr_reader :options, :results

  def initialize(options = {})
    @options = options
    @results = []
    @catalog = Kotoshu::Dictionaries::Catalog
  end

  # Run validation
  def run
    print_header

    dictionaries = select_dictionaries

    print "Validating #{dictionaries.size} dictionaries...\n\n"

    dictionaries.each_with_index do |entry, index|
      validate_dictionary(entry, index + 1, dictionaries.size)
    end

    print_summary

    write_report if @options[:report]

    exit_with_code
  end

  private

  def select_dictionaries
    dicts = @catalog.all

    dicts = dicts.select { |d| d.language == @options[:lang] } if @options[:lang]
    dicts = [dicts.find { |d| d.code.casecmp(@options[:code]).zero? }].compact if @options[:code]
    dicts = dicts.select { |d| d.format == @options[:format].to_sym } if @options[:format]

    dicts
  end

  def validate_dictionary(entry, index, total)
    result = ValidationResult.new(entry.code)

    print_status(entry, index, total, result)

    begin
      # Load dictionary with timing
      dict = nil
      load_time = Benchmark.realtime do
        dict = entry.load
      end

      # Basic validation
      size = dict.size

      if size.zero?
        result.warning!(load_time, size, "Dictionary has zero words")
      elsif size < 100
        result.warning!(load_time, size, "Dictionary has fewer than 100 words")
      else
        result.success!(load_time, size)
      end

      # Run tests if --full
      if @options[:full] && result.success?
        run_full_tests(dict, entry, result)
      end

    rescue StandardError => e
      result.error!(e)
    end

    @results << result
    print_result(entry, result)
  end

  def run_full_tests(dict, entry, result)
    # Test 1: Lookup basic word (varies by language)
    test_word = basic_test_word(entry.language)
    if dict.lookup?(test_word)
      result.add_test_result(:basic_lookup, true, test_word)
    else
      result.add_test_result(:basic_lookup, false, "Could not find '#{test_word}'")
    end

    # Test 2: Lookup non-existent word
    nonsense_word = nonsense_test_word(entry.language)
    if !dict.lookup?(nonsense_word)
      result.add_test_result(:nonexistent_lookup, true, nonsense_word)
    else
      result.add_test_result(:nonexistent_lookup, false, "Incorrectly found '#{nonsense_word}'")
    end

    # Test 3: Suggestions (if supported)
    begin
      misspelled = misspelled_test_word(entry.language)
      suggestions = dict.suggest(misspelled, max_suggestions: 5)
      if suggestions && suggestions.any?
        result.add_test_result(:suggestions, true, "Found #{suggestions.size} suggestions for '#{misspelled}'")
      else
        result.add_test_result(:suggestions, false, "No suggestions for '#{misspelled}'")
      end
    rescue StandardError => e
      result.add_test_result(:suggestions, false, e.message)
    end

    # Test 4: Case sensitivity (if not case-sensitive)
    unless dict.case_sensitive?
      if dict.lookup?(test_word.upcase) || dict.lookup?(test_word.downcase)
        result.add_test_result(:case_insensitive, true, "Case-insensitive lookup works")
      else
        result.add_test_result(:case_insensitive, false, "Case-insensitive lookup failed")
      end
    end
  end

  def basic_test_word(language)
    # Common words in different languages
    {
      "en" => "the",
      "de" => "der",
      "es" => "el",
      "fr" => "le",
      "it" => "il",
      "pt" => "o",
      "ru" => "и",
      "nl" => "de",
      "pl" => "i",
      "cs" => "a",
      "sv" => "och",
      "da" => "og",
      "no" => "og",
      "fi" => "ja",
      "tr" => "ve",
      "ko" => "그",
      "vi" => "là",
      "ja" => "は",
      "zh" => "的",
      "ar" => "في",
      "he" => "ו",
      "el" => "το",
      "hu" => "a",
      "ro" => "şi",
      "bg" => "и",
      "uk" => "і",
      "ga" => "an",
      "cy" => "y",
      "is" => "og",
      "mt" => "u",
      "lv" => "un",
      "et" => "ja",
      "lt" => "ir",
      "sk" => "a",
      "sl" => "in",
      "hr" => "i",
      "sr" => "и",
      "sq" => "dhe",
      "be" => "і",
      "mk" => "и",
      "hy" => "և",
      "ka" => "და",
      "fa" => "و",
      "ur" => "اور",
      "hi" => "और",
      "bn" => "এবং",
      "th" => "และ",
      "id" => "dan",
      "ms" => "dan",
      "sw" => "na",
      "af" => "en",
      "ca" => "i",
      "gl" => "e",
      "eu" => "eta",
      "lb" => "an",
      "fy" => "en",
      "ku" => "û",
      "eo" => "kaj",
      "ia" => "e"
    }.fetch(language, "a")
  end

  def nonsense_test_word(language)
    # Nonsense words that shouldn't exist
    "zzzzzzzzz"
  end

  def misspelled_test_word(language)
    # Common misspellings in different languages
    {
      "en" => "helo",
      "de" => "hallo",
      "es" => "ola",
      "fr" => "bonjur",
      "it" => "ciao",
      "pt" => "ola",
      "ru" => "привет",
      "nl" => "halo",
      "pl" => "czesc"
    }.fetch(language, "teest")
  end

  def print_header
    print "#{Colors::BOLD}Kotoshu Dictionary Validator#{Colors::RESET}\n"
    print "=" * 60 + "\n\n"

    stats = @catalog.statistics
    print "Catalog Statistics:\n"
    print "  Total dictionaries: #{stats[:total]}\n"
    print "  Hunspell dictionaries: #{stats[:hunspell]}\n"
    print "  Plain text dictionaries: #{stats[:plain_text]}\n"
    print "  Languages: #{stats[:languages]}\n"
    print "  Total words: #{stats[:total_words].round}\n"
    print "\n"
    print "=" * 60 + "\n\n"
  end

  def print_status(entry, index, total, result)
    print "[#{index}/#{total}] #{Colors::CYAN}#{entry.code}#{Colors::RESET} - #{entry.description}\n"
    print "        Format: #{entry.format}, License: #{entry.license}\n"
  end

  def print_result(entry, result)
    if result.success?
      print "        #{Colors::GREEN}✓ PASS#{Colors::RESET}"
      print " - #{result.size.round} words, #{(result.load_time * 1000).round(1)}ms"
      print " - Tests: #{result.test_results.size}" if @options[:full]
      print "\n"
    elsif result.warning?
      print "        #{Colors::YELLOW}⚠ WARN#{Colors::RESET}"
      print " - #{result.size.round} words, #{(result.load_time * 1000).round(1)}ms"
      print " - #{result.test_results[:warning]}"
      print "\n"
    else
      print "        #{Colors::RED}✗ FAIL#{Colors::RESET}"
      print " - #{result.error.class}: #{result.error.message}"
      print "\n"
    end

    # Print test results details
    if @options[:full] && result.test_results.any?
      result.test_results.each do |name, test_result|
        next if name == :warning
        status = test_result[:passed] ? "#{Colors::GREEN}✓#{Colors::RESET}" : "#{Colors::RED}✗#{Colors::RESET}"
        print "          #{status} #{name}: #{test_result[:details]}\n"
      end
    end

    print "\n"
  end

  def print_summary
    print "=" * 60 + "\n"
    print "#{Colors::BOLD}Validation Summary#{Colors::RESET}\n"
    print "=" * 60 + "\n\n"

    total = @results.size
    success = @results.count(&:success?)
    warnings = @results.count(&:warning?)
    errors = @results.count(&:error?)

    print "Total: #{total}\n"
    print "#{Colors::GREEN}✓ Passed: #{success}#{Colors::RESET}\n"
    print "#{Colors::YELLOW}⚠ Warnings: #{warnings}#{Colors::RESET}\n"
    print "#{Colors::RED}✗ Failed: #{errors}#{Colors::RESET}\n"
    print "\n"

    if success > 0
      avg_load_time = @results.select(&:success?).map(&:load_time).sum / success
      avg_size = @results.select(&:success?).map(&:size).sum / success
      print "Average load time: #{(avg_load_time * 1000).round(1)}ms\n"
      print "Average size: #{avg_size.round} words\n"
      print "\n"
    end

    if errors > 0
      print "#{Colors::BOLD}Failed Dictionaries:#{Colors::RESET}\n"
      @results.select(&:error?).each do |result|
        print "  #{Colors::RED}#{result.code}#{Colors::RESET}: #{result.error.message}\n"
      end
      print "\n"
    end

    if warnings > 0
      print "#{Colors::BOLD}Warnings:#{Colors::RESET}\n"
      @results.select(&:warning?).each do |result|
        print "  #{Colors::YELLOW}#{result.code}#{Colors::RESET}: #{result.test_results[:warning]}\n"
      end
      print "\n"
    end
  end

  def write_report
    report_path = "dictionary_validation_report.json"
    File.write(report_path, JSON.pretty_generate({
      timestamp: Time.now.iso8601,
      summary: {
        total: @results.size,
        success: @results.count(&:success?),
        warnings: @results.count(&:warning?),
        errors: @results.count(&:error?)
      },
      results: @results.map(&:to_h)
    }))
    print "Report written to: #{report_path}\n"
  end

  def exit_with_code
    # Exit with error code if any failures
    exit 1 if @results.any?(&:error?)
    exit 0
  end
end

# Parse options
options = {
  full: false,
  lang: nil,
  code: nil,
  format: nil,
  report: false
}

OptionParser.new do |opts|
  opts.banner = "Usage: ruby script/validate_all_dictionaries.rb [options]"

  opts.on("--full", "Run full validation including tests") do
    options[:full] = true
  end

  opts.on("--lang LANG", "Filter by language (e.g., en, de, fr)") do |lang|
    options[:lang] = lang
  end

  opts.on("--code CODE", "Filter by dictionary code (e.g., en-GB)") do |code|
    options[:code] = code
  end

  opts.on("--format FORMAT", "Filter by format (hunspell, plain_text)") do |fmt|
    options[:format] = fmt
  end

  opts.on("--report", "Write JSON report file") do
    options[:report] = true
  end

  opts.on("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end.parse!

# Run validator
validator = DictionaryValidator.new(options)
validator.run
