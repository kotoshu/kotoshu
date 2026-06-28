# frozen_string_literal: true

require_relative 'display_formatter'
require_relative 'navigation_manager'
require 'json'
require 'csv'

module Kotoshu
  module Cli
    # Batch reporter for non-interactive error reporting.
    #
    # Outputs error reports in various formats (JSON, YAML, CSV, text).
    # Used for automated checking and CI/CD integration.
    #
    # @example Generate JSON report
    #   reporter = BatchReporter.new(document, navigation)
    #   reporter.to_json('errors.json')
    #
    # @example Generate CSV report
    #   reporter.to_csv('errors.csv')
    #
    # @example Generate text summary
    #   puts reporter.to_text
    class BatchReporter
      attr_reader :document, :navigation, :formatter

      # Display name lookup for document formats.
      FORMAT_NAMES = {
        text: 'Plain Text',
        markdown: 'Markdown',
        asciidoc: 'AsciiDoc',
        code: 'Code'
      }.freeze

      # Create a new batch reporter.
      #
      # @param document [#name,#format,#language_code] Document being reported
      # @param navigation [NavigationManager] Navigation state
      # @param formatter [DisplayFormatter, nil] Display formatter
      def initialize(document, navigation, formatter: nil)
        @document = document
        @navigation = navigation
        @formatter = formatter || DisplayFormatter.new
      end

      # Generate JSON report.
      #
      # @param filepath [String] Output file path (optional, returns string if nil)
      # @param pretty [Boolean] Pretty-print JSON (default: true)
      # @return [String, nil] JSON string or nil if written to file
      def to_json(filepath: nil, pretty: true)
        data = generate_report_data
        json = pretty ? JSON.pretty_generate(data) : JSON.generate(data)

        if filepath
          File.write(filepath, json)
          nil
        else
          json
        end
      end

      # Generate YAML report.
      #
      # @param filepath [String] Output file path (optional, returns string if nil)
      # @return [String, nil] YAML string or nil if written to file
      def to_yaml(filepath: nil)
        require 'yaml'

        data = generate_report_data
        yaml = data.to_yaml

        if filepath
          File.write(filepath, yaml)
          nil
        else
          yaml
        end
      end

      # Generate CSV report.
      #
      # @param filepath [String] Output file path (optional, returns string if nil)
      # @return [String, nil] CSV string or nil if written to file
      def to_csv(filepath: nil)
        csv_string = CSV.generate do |csv|
          # Header
          csv << ['ID', 'Line', 'Original', 'Suggestion', 'Confidence', 'Error Type']

          # Data rows
          @navigation.errors.each do |error|
            suggestion = error.recommended_suggestion
            csv << [
              error.id,
              error.location.line,
              error.original,
              suggestion&.word || '',
              "#{(error.confidence * 100).round(1)}%",
              error.error_type.to_s.capitalize
            ]
          end
        end

        if filepath
          File.write(filepath, csv_string)
          nil
        else
          csv_string
        end
      end

      # Generate text summary.
      #
      # @return [String] Formatted text summary
      def to_text
        lines = []
        lines << ""
        lines << @formatter.colorize("╔═══════════════════════════════════════════════════════════════╗", :bold)
        lines << @formatter.colorize("║                    Batch Error Report                        ║", :bold)
        lines << @formatter.colorize("╚═══════════════════════════════════════════════════════════════╝", :bold)
        lines << ""
        lines << "Document: #{@document.name}"
        lines << "Format: #{FORMAT_NAMES[@document.format] || @document.format}"
        lines << "Language: #{@document.language_code}"
        lines << ""
        lines << @formatter.colorize("Summary", :bold)
        lines << "─" * 70

        stats = @navigation.statistics
        lines << "Total errors: #{stats[:total]}"
        lines << "  • High confidence (>0.8): #{stats[:by_confidence][:high]}"
        lines << "  • Medium confidence (0.5-0.8): #{stats[:by_confidence][:medium]}"
        lines << "  • Low confidence (≤0.5): #{stats[:by_confidence][:low]}"
        lines << ""

        # Breakdown by type
        if stats[:by_type]&.any?
          lines << @formatter.colorize("By Type", :bold)
          stats[:by_type].each do |type, count|
            label = Models::SemanticError::ERROR_TYPES[type] || type.to_s.capitalize
            lines << "  • #{label}: #{count}"
          end
          lines << ""
        end

        # Top errors
        if @navigation.errors.any?
          lines << @formatter.colorize("Top Errors", :bold)
          lines << "─" * 70

          @navigation.errors.first(10).each_with_index do |error, idx|
            lines << "#{idx + 1}. [#{error.location}] #{error.original}"
            lines << "   Type: #{error.error_type}"
            lines << "   Confidence: #{(error.confidence * 100).round(1)}%"

            if error.suggestions&.any?
              top_suggestion = error.suggestions.first
              lines << "   Suggestion: #{top_suggestion.word} (#{(top_suggestion.confidence * 100).round(0)}%)"
            end

            lines << ""
          end

          if @navigation.errors.size > 10
            lines << "... and #{@navigation.errors.size - 10} more"
            lines << ""
          end
        end

        lines.join("\n")
      end

      # Generate SARIF report (Static Analysis Results Interchange Format).
      #
      # SARIF is a standard format for static analysis tools.
      # Useful for CI/CD integration and IDE integration.
      #
      # @param filepath [String] Output file path (optional, returns string if nil)
      # @return [String, nil] SARIF JSON string or nil if written to file
      def to_sarif(filepath: nil)
        sarif = {
          version: "2.1.0",
          "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
          runs: [
            {
              tool: {
                driver: {
                  name: "Kotoshu",
                  version: Kotoshu::VERSION,
                  informationUri: "https://github.com/kotoshu/kotoshu",
                  rules: []
                }
              },
              results: @navigation.errors.map do |error|
                {
                  ruleId: error.error_type.to_s,
                  level: error.high_confidence? ? "error" : "warning",
                  message: {
                    text: "Potential #{error.error_type} error: '#{error.original}'"
                  },
                  locations: [
                    {
                      physicalLocation: {
                        artifactLocation: {
                          uri: @document.name
                        },
                        region: {
                          startLine: error.location.line || 1,
                          startColumn: error.location.column || 0
                        }
                      }
                    }
                  ],
                  suggestions: error.suggestions&.map do |sugg|
                    {
                      text: sugg.word
                    }
                  end
                }
              end
            }
          ]
        }

        json = JSON.pretty_generate(sarif)

        if filepath
          File.write(filepath, json)
          nil
        else
          json
        end
      end

      # Get exit code based on error severity.
      #
      # Useful for CI/CD pipelines.
      #
      # @param max_errors [Integer] Maximum errors allowed (default: 0)
      # @return [Integer] Exit code (0 = success, 1 = errors found)
      def exit_code(max_errors: 0)
        return 0 if @navigation.errors.size <= max_errors

        1
      end

      # Get report summary as hash.
      #
      # @return [Hash] Report summary
      def summary
        @navigation.statistics.merge(
          document: {
            name: @document.name,
            format: @document.format,
            language: @document.language_code
          },
          has_errors: @navigation.errors.any?
        )
      end

      # Print report to stdout.
      #
      # @param format [Symbol] Output format (:text, :json, :yaml)
      def print(format: :text)
        case format
        when :text
          puts to_text
        when :json
          puts to_json
        when :yaml
          puts to_yaml
        else
          raise ArgumentError, "Unknown format: #{format}"
        end
      end

      private

      # Generate report data hash.
      #
      # @return [Hash] Report data
      def generate_report_data
        {
          metadata: {
            tool: "Kotoshu",
            version: Kotoshu::VERSION,
            generated_at: Time.now.utc.iso8601
          },
          document: {
            name: @document.name,
            format: @document.format.to_s,
            language: @document.language_code,
            word_count: @document.word_count,
            line_count: @document.line_count
          },
          statistics: @navigation.statistics,
          errors: @navigation.errors.map do |error|
            {
              id: error.id,
              location: {
                line: error.location.line,
                column: error.location.column,
                node_path: error.location.node_path
              },
              original: error.original,
              suggestions: error.suggestions&.map do |sugg|
                {
                  word: sugg.word,
                  confidence: sugg.confidence,
                  source: sugg.source
                }
              end,
              error_type: error.error_type.to_s,
              confidence: error.confidence,
              recommended_suggestion: error.recommended_suggestion&.word
            }
          end,
          corrections: @navigation.export_corrections
        }
      end
    end
  end
end
