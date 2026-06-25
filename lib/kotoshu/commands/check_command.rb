# frozen_string_literal: true

require_relative '../documents/document'
require_relative '../analyzers/semantic_analyzer'
require_relative '../models/fasttext_model'
require_relative '../cache/model_cache'
require_relative '../cli/interactive_reviewer'
require_relative '../cli/batch_reporter'
require_relative '../language/identifier'

module Kotoshu
  class CheckCommand < Thor
    namespace :check

    class_option :language, aliases: '-l', type: :string, default: 'auto',
             desc: 'Language code (auto, de, en, es, fr, pt, ru)'
    class_option :interactive, aliases: '-i', type: :boolean, default: false,
             desc: 'Interactive mode for error review'
    class_option :output, aliases: '-o', type: :string,
             desc: 'Output file path (for batch mode)'
    class_option :format, type: :string, enum: %w[text json yaml csv sarif], default: 'text',
             desc: 'Output format (text, json, yaml, csv, sarif)'
    class_option :model, type: :string, enum: %w[fasttext hunspell], default: 'hunspell',
             desc: 'Analysis model (fasttext, hunspell)'
    class_option :download, type: :boolean, default: true,
             desc: 'Automatically download models if missing'
    class_option :verbose, aliases: '-v', type: :boolean, default: false,
             desc: 'Verbose output'

    desc 'check FILE', 'Check spelling/grammar in a file'
    def check(file)
      # Validate file exists
      unless File.exist?(file)
        puts "Error: File not found: #{file}"
        exit 1
      end

      # Detect language if auto
      language = detect_language(file, options[:language])

      # Load document
      document = load_document(file, language)

      # Load analyzer based on model type
      analyzer = load_analyzer(language, options[:model])

      puts "Analyzing #{file} (language: #{language})..." if options[:verbose]

      # Run interactive or batch mode
      if options[:interactive]
        run_interactive_mode(document, analyzer)
      else
        run_batch_mode(document, analyzer)
      end
    end

    desc 'string TEXT', 'Check spelling/grammar in a text string'
    option :format, type: :string, enum: %w[text markdown], default: 'text',
             desc: 'Text format (text, markdown)'
    def string(text)
      language_code = options[:language]

      # Create document from string
      format_sym = options[:format].to_sym
      document = Documents::Document.from_string(text, language_code: language_code)

      # Load analyzer
      analyzer = load_analyzer(language_code, options[:model])

      puts "Analyzing..." if options[:verbose]

      # Always use batch mode for string input
      reporter = run_batch_mode(document, analyzer)

      # Print report
      reporter.print(format: options[:format].to_sym)

      # Exit with appropriate code
      exit reporter.exit_code
    end

    desc 'stdin', 'Check spelling/grammar from stdin'
    option :format, type: :string, enum: %w[text markdown], default: 'text',
             desc: 'Text format (text, markdown)'
    def stdin
      text = $stdin.read

      if text.nil? || text.empty?
        puts "Error: No input provided"
        exit 1
      end

      # Delegate to string command
      invoke :string, [text], options
    end

    private

    # Detect language from file or use specified language.
    #
    # @param filepath [String] Path to file
    # @param language_code [String] Specified language code or 'auto'
    # @return [String] Detected or specified language code
    def detect_language(filepath, language_code)
      return language_code unless language_code == 'auto'

      puts "Detecting language..." if options[:verbose]

      begin
        lid = Language::LanguageIdentifier.new
        result = lid.detect_from_file(filepath, top_k: 1).first

        if result && result.confidence > 0.8
          detected = result.language
          puts "  Detected: #{detected} (#{(result.confidence * 100).round(0)}% confidence)" if options[:verbose]
          detected
        else
          puts "  Language detection uncertain, using 'en'" if options[:verbose]
          'en'
        end
      rescue StandardError => e
        puts "  Language detection failed: #{e.message}" if options[:verbose]
        puts "  Using 'en' as default" if options[:verbose]
        'en'
      end
    end

    # Load document from file.
    #
    # @param filepath [String] Path to file
    # @param language_code [String] Language code
    # @return [Documents::Document] Loaded document
    def load_document(filepath, language_code = 'en')
      Documents::Document.from_file(filepath, language_code: language_code)
    rescue StandardError => e
      puts "Error loading document: #{e.message}"
      exit 1
    end

    # Load analyzer based on model type.
    #
    # @param language_code [String] Language code
    # @param model_type [String] Model type
    # @return [Object] Analyzer instance
    def load_analyzer(language_code, model_type)
      case model_type
      when 'fasttext'
        load_fasttext_analyzer(language_code)
      when 'hunspell'
        load_hunspell_analyzer(language_code)
      else
        raise ArgumentError, "Unknown model type: #{model_type}"
      end
    end

    # Load FastText analyzer using ONNX model.
    #
    # ONNX is the ONLY supported format. No fallbacks.
    #
    # @param language_code [String] Language code
    # @return [Analyzers::SemanticAnalyzer] FastText analyzer with ONNX model
    def load_fasttext_analyzer(language_code)
      cache = Cache::ModelCache.new
      onnx_file = cache.get_onnx_model(language_code, force_download: options[:download])

      unless onnx_file && File.exist?(onnx_file)
        puts "Error: ONNX model not found for #{language_code}"
        puts ""
        puts "Download the model first:"
        puts "  kotoshu model download #{language_code} --type onnx"
        puts ""
        puts "Or convert from FastText .vec file:"
        puts "  kotoshu model convert cc.#{language_code}.300.vec fasttext.#{language_code}.onnx -l #{language_code}"
        exit 1
      end

      puts "Loading ONNX model for #{language_code}..." if options[:verbose]
      model = Models::OnnxModel.from_file(onnx_file)
      model.preload_embedding_matrix if options[:verbose]
      Analyzers::SemanticAnalyzer.new(model)
    rescue StandardError => e
      puts "Error loading FastText analyzer: #{e.message}"
      puts ""
      puts "Ensure ONNX Runtime is installed:"
      puts "  gem install onnxruntime"
      exit 1
    end

    # Load Hunspell analyzer.
    #
    # @param language_code [String] Language code
    # @return [Object] Hunspell analyzer
    def load_hunspell_analyzer(language_code)
      require_relative '../dictionary/hunspell'

      # Load Hunspell dictionary
      if options[:download]
        puts "Loading Hunspell dictionary for #{language_code}..." if options[:verbose]
        dict = Dictionary::Hunspell.from_github(language_code)
      else
        # Try local paths
        dict = Dictionary::Hunspell.for_language(language_code)
      end

      # Create Hunspell-based analyzer
      # Note: This would use HunspellDictionary for checking + EditDistanceStrategy for suggestions
      # For now, we'll use a placeholder
      require_relative '../spell_checker'
      SpellChecker.new(dictionary: dict, language: language_code)
    rescue StandardError => e
      puts "Error loading Hunspell analyzer: #{e.message}"
      exit 1
    end

    # Run interactive mode.
    #
    # @param document [Documents::Document] Document to check
    # @param analyzer [Object] Analyzer instance
    def run_interactive_mode(document, analyzer)
      # Create interactive reviewer
      reviewer = Cli::InteractiveReviewer.new(document, analyzer)

      unless reviewer.has_errors?
        puts "No errors found!"
        return
      end

      # Run interactive loop
      reviewer.run

      # Apply corrections if user accepted any
      if reviewer.navigation.modified.any?
        apply_corrections(document, reviewer.navigation)
      end
    end

    # Run batch mode.
    #
    # @param document [Documents::Document] Document to check
    # @param analyzer [Object] Analyzer instance
    # @return [Cli::BatchReporter] Batch reporter
    def run_batch_mode(document, analyzer)
      # For batch mode with Hunspell, we need different approach
      if analyzer.is_a?(SpellChecker)
        # Use traditional spell checker
        result = analyzer.check_string(document.content)
        # Convert result to navigation...
        # This is a placeholder - full implementation would convert
      end

      # For SemanticAnalyzer, create reviewer and get batch reporter
      if analyzer.is_a?(Analyzers::SemanticAnalyzer)
        reviewer = Cli::InteractiveReviewer.new(document, analyzer)
        reporter = reviewer.run_batch

        # Write to file if specified
        if options[:output]
          case options[:format]
          when 'json'
            reporter.to_json(filepath: options[:output])
          when 'yaml'
            reporter.to_yaml(filepath: options[:output])
          when 'csv'
            reporter.to_csv(filepath: options[:output])
          when 'sarif'
            reporter.to_sarif(filepath: options[:output])
          else
            File.write(options[:output], reporter.to_text)
          end

          puts "Report written to: #{options[:output]}" if options[:verbose]
        end

        return reporter
      end

      # Fallback
      nil
    end

    # Apply corrections to document.
    #
    # @param document [Documents::Document] Original document
    # @param navigation [Cli::NavigationManager] Navigation state with corrections
    def apply_corrections(document, navigation)
      corrections = navigation.export_corrections

      if corrections.empty?
        return
      end

      # Apply corrections
      corrected_doc = document.apply(corrections.map { |c|
        # Convert correction hash to SemanticError
        # This is a placeholder - full implementation would reconstruct errors
      }.compact)

      # Write corrected document
      backup_path = document.name + ".bak"
      output_path = document.name

      # Create backup
      File.write(backup_path, document.content)

      # Write corrected version
      File.write(output_path, corrected_doc.content)

      puts "Created backup: #{backup_path}" if options[:verbose]
      puts "Wrote corrections to: #{output_path}"
    end
  end
end
