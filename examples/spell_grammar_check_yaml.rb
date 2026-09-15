#!/usr/bin/env ruby
# frozen_string_literal: true

# Comprehensive Spell and Grammar Checker with YAML Output
#
# This script demonstrates how to use Kotoshu to perform comprehensive
# spell checking and grammar checking on a document, outputting results
# in a machine-readable YAML format similar to Microsoft Word's
# spell checker output.
#
# Usage:
#   ruby spell_grammar_check_yaml.rb <input_file.md> [output.yaml]
#
# Example:
#   ruby spell_grammar_check_yaml.rb test-01-test.md results.yaml
#
# The YAML output includes:
# - Document metadata (file, title, line/char counts)
# - Summary statistics (total errors by type/severity)
# - Detailed error list with:
#   - Location (line, column, character range)
#   - Error type (spelling/grammar) and severity
#   - Incorrect text and suggested corrections
#   - Context (before/after text for UI display)
#   - Rule information (for grammar rules)
#
# Known Limitations:
# - Grammar rules: Only a/an article and double negative rules are implemented
# - False positives: Foreign words (Chinese pinyin, etc.) may be flagged
# - Suggestions: Hunspell may not find all correct suggestions

require 'bundler/setup'
require 'kotoshu'
require 'yaml'

# Document Spell/Grammar Checker
class DocumentChecker
  attr_reader :file_path, :content, :language

  def initialize(file_path, language: Kotoshu::Languages::English.new)
    @file_path = file_path
    @content = File.read(file_path)
    @language = language
    @lines = @content.lines
    @errors = []
  end

  # Run full check (spelling + grammar)
  def check_all
    check_spelling
    check_grammar
    build_results
  end

  private

  # Check spelling errors in the document
  def check_spelling
    spell_checker = @language.create_spell_checker

    current_char = 0
    @lines.each_with_index do |line, line_num|
      line.chomp!
      next if line.empty?

      # Tokenize the line
      tokens = @language.tokenize(line)

      tokens.each do |token|
        word = token[:token]
        # Skip non-word tokens (punctuation, symbols, etc.)
        next unless word =~ /^[a-zA-Z]+$/ # Only check alphabetic words
        next if word =~ /^[A-Z]+$/  # Skip all-caps abbreviations
        next if word =~ /^[0-9]+$/  # Skip numbers

        # Check if word is correct
        unless spell_checker.correct?(word)
          suggestions = spell_checker.suggest(word, max_suggestions: 5)

          # Extract just the word from suggestion hashes
          suggestion_words = suggestions.map { |s| s[:word] }

          add_error(
            type: :spelling,
            severity: :error,
            line: line_num + 1,
            column: token[:position] + 1,
            char_start: current_char + token[:position],
            char_end: current_char + token[:position] + token[:length],
            incorrect: word,
            suggestions: suggestion_words,
            context: extract_context(line, token[:position], token[:length]),
            message: "Spelling error: '#{word}'"
          )
        end
      end

      current_char += line.length + 1 # +1 for newline
    end
  end

  # Check grammar errors in the document
  def check_grammar
    # Get grammar rules for the language
    grammar_rules = @language.respond_to?(:create_grammar_rules) ? @language.create_grammar_rules : nil

    current_char = 0

    @lines.each_with_index do |line, line_num|
      line.chomp!
      next if line.empty?

      # Tokenize the line
      tokens = @language.tokenize(line)

      # POS tag the tokens before grammar checking
      pos_tagger = @language.create_pos_tagger
      tagged_tokens = pos_tagger.tag(tokens)

      # Check grammar (the per-language rules engine)
      if grammar_rules
        issues = grammar_rules.check(tokens)

        issues.each do |issue|
          token = tagged_tokens[issue[:position]]
          next unless token

          add_error(
            type: :grammar,
            severity: :warning,
            line: line_num + 1,
            column: token[:position] + 1,
            char_start: current_char + token[:position],
            char_end: current_char + token[:position] + token[:length],
            incorrect: token[:token],
            suggestions: issue[:suggestions] || [issue[:suggestion]].compact,
            context: extract_context(line, token[:position], token[:length]),
            message: issue[:message],
            rule_id: issue[:rule_id],
            rule_category: issue[:rule_id].to_s.split("_").first
          )
        end
      end

      current_char += line.length + 1
    end
  end

  # Add an error to the list
  def add_error(type:, severity:, line:, column:, char_start:, char_end:,
                 incorrect:, suggestions:, context:, message:, rule_id: nil, rule_category: nil)
    @errors << {
      id: @errors.size + 1,
      type: type,
      severity: severity,
      location: {
        line: line,
        column: column,
        char_start: char_start,
        char_end: char_end,
        line_text: @lines[line - 1].chomp
      },
      error: {
        incorrect: incorrect,
        suggestions: suggestions,
        message: message,
        confidence: suggestions.empty? ? 0.0 : 1.0
      },
      context: context,
      rule: {
        id: rule_id,
        category: rule_category
      }.compact
    }
  end

  # Extract context around an error
  def extract_context(line, position, length)
    # Get 20 characters before and after
    context_window = 20
    start_pos = [0, position - context_window].max
    end_pos = [line.length, position + length + context_window].min

    {
      before: line[start_pos...position],
      text: line[position...position + length],
      after: line[position + length...end_pos],
      full: line,
      window_size: context_window
    }
  end

  # Build the complete results YAML structure
  def build_results
    title = extract_title

    {
      'document' => {
        'file' => @file_path,
        'title' => title,
        'total_lines' => @lines.size,
        'total_chars' => @content.length,
        'language' => 'en',
        'encoding' => 'UTF-8'
      },
      'summary' => build_summary,
      'errors' => @errors
    }
  end

  # Extract document title from first line
  def extract_title
    first_line = @lines.first&.chomp
    first_line&.sub(/^#+\s*/, '')&.strip || 'Untitled Document'
  end

  # Build summary statistics
  def build_summary
    spelling_count = @errors.count { |e| e[:type] == :spelling }
    grammar_count = @errors.count { |e| e[:type] == :grammar }
    error_count = @errors.count { |e| e[:severity] == :error }
    warning_count = @errors.count { |e| e[:severity] == :warning }

    errors_by_line = @errors.group_by { |e| e[:location][:line] }
      .transform_values(&:count)
      .sort_by { |line, count| [-count, line] }
      .to_h

    # Known false positives (foreign words, proper nouns)
    false_positives = %w[Zhou xiao ren Ren li junzi junzi junzi junzi]

    {
      'total_errors' => @errors.size,
      'spelling_errors' => spelling_count,
      'grammar_errors' => grammar_count,
      'errors_by_severity' => {
        'error' => error_count,
        'warning' => warning_count
      },
      'errors_by_line' => errors_by_line,
      'known_false_positives' => false_positives,
      'limitations' => {
        'grammar_rules' => 'Only a/an article rule and double negative rule are currently implemented',
        'false_positives' => 'Foreign words (Chinese pinyin, etc.) may be flagged as spelling errors',
        'suggestions' => 'Hunspell suggestion algorithm may not find all corrections'
      },
      'checked_at' => Time.now.iso8601
    }
  end
end

# Main execution
if __FILE__ == $PROGRAM_NAME
  if ARGV.empty?
    puts "Usage: ruby #{$PROGRAM_NAME} <file_to_check.md> [output.yaml]"
    puts ""
    puts "Example:"
    puts "  ruby #{$PROGRAM_NAME} test-01-test.md results.yaml"
    exit 1
  end

  input_file = ARGV[0]
  output_file = ARGV[1] || input_file.sub(/\.(md|txt)$/, '_results.yaml')

  unless File.exist?(input_file)
    puts "Error: File not found: #{input_file}"
    exit 1
  end

  puts "=" * 60
  puts "Kotoshu Document Checker"
  puts "=" * 60
  puts "Input:  #{input_file}"
  puts "Output: #{output_file}"
  puts ""

  # Run the checker
  checker = DocumentChecker.new(input_file)
  results = checker.check_all

  # Write YAML output
  File.write(output_file, results.to_yaml)

  # Print summary
  puts "Check complete!"
  puts ""
  puts "Summary:"
  puts "  Total errors:     #{results['summary']['total_errors']}"
  puts "  Spelling errors: #{results['summary']['spelling_errors']}"
  puts "  Grammar errors:  #{results['summary']['grammar_errors']}"
  puts ""
  puts "Results saved to: #{output_file}"
end
