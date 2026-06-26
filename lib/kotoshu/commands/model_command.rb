# frozen_string_literal: true

require 'thor'
require_relative '../models/fasttext_model'
require_relative '../models/onnx_model'
require_relative '../cache/model_cache'

module Kotoshu
  class ModelCommand < Thor
    namespace :model

    desc 'convert INPUT OUTPUT', 'Convert FastText .vec file to ONNX format'
    option :language, aliases: '-l', type: :string, required: true,
             desc: 'Language code (de, en, es, fr, pt, ru)'
    option :max_vectors, type: :numeric, default: 500_000,
             desc: 'Maximum vectors to convert (default: 500k)'
    option :validate, type: :boolean, default: true,
             desc: 'Validate model after conversion'
    def convert(input, output)
      puts "Converting #{input} to #{output}..."

      # Check if input file exists
      unless File.exist?(input)
        puts "Error: Input file not found: #{input}"
        exit 1
      end

      # Build Python command
      script_path = File.join(File.dirname(__FILE__), '../../scripts/convert_fasttext_to_onnx.py')

      unless File.exist?(script_path)
        puts "Error: Conversion script not found: #{script_path}"
        exit 1
      end

      # Build command
      cmd = [
        'python3',
        script_path,
        '--input', input,
        '--output', output,
        '--language', options[:language],
        '--max-vectors', options[:max_vectors].to_s
      ]

      cmd << '--validate' if options[:validate]

      puts "Running: #{cmd.join(' ')}"

      # Execute conversion
      system(*cmd)

      if $?.success?
        puts "\n✓ Conversion successful!"
        puts "  Model: #{output}"
        puts "  Vocab: #{output.sub('.onnx', '.vocab.json')}"
        puts "  Metadata: #{output.sub('.onnx', '.metadata.json')}"
        puts "  Optimized: #{output.sub('.onnx', '.ort.onnx')}"
      else
        puts "\n✗ Conversion failed!"
        exit 1
      end
    end

    desc 'download LANGUAGE', 'Download FastText model for a language'
    option :type, type: :string, enum: %w[fasttext onnx], default: 'fasttext',
             desc: 'Model type to download'
    option :output, type: :string,
             desc: 'Output path (default: $XDG_CACHE_HOME/kotoshu/languages/{code}/models/)'
    option :force, type: :boolean, default: false,
             desc: 'Force re-download even if cached'
    def download(language)
      puts "Downloading #{options[:type]} model for #{language}..."

      cache = Cache::ModelCache.new

      case options[:type]
      when 'fasttext'
        vec_file = cache.get_fasttext_model(language, force_download: options[:force])
        puts "✓ Downloaded to: #{vec_file}"
      when 'onnx'
        onnx_file = cache.get_onnx_model(language, force_download: options[:force])
        puts "✓ Downloaded to: #{onnx_file}"
      end

      # Show file info
      show_model_info(language)
    end

    desc 'info LANGUAGE', 'Show information about available models'
    option :type, type: :string, enum: %w[fasttext onnx],
             desc: 'Model type to show (default: all)'
    def info(language)
      cache = Cache::ModelCache.new

      puts "Model information for #{language}:"
      puts ""

      if options[:type].nil? || options[:type] == 'fasttext'
        model_info = cache.model_info(language, :fasttext)
        if model_info
          puts "FastText:"
          puts "  File: #{model_info[:file]}"
          puts "  Size: #{model_info[:size].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} vectors"
          puts "  Source: #{model_info[:source]}"
          puts ""
        end
      end

      if options[:type].nil? || options[:type] == 'onnx'
        model_info = cache.model_info(language, :onnx)
        if model_info
          puts "ONNX:"
          puts "  File: #{model_info[:file]}"
          puts "  Source: #{model_info[:source]}"
          puts ""
        end
      end
    end

    desc 'list', 'List all available models'
    def list
      cache = Cache::ModelCache.new
      all_models = cache.all_available_models

      puts "Available models:"
      puts ""

      all_models.each do |model_type, languages|
        puts "#{model_type.to_s.capitalize}:"

        languages.each do |code, info|
          puts "  #{code}:"
          puts "    File: #{info[:file]}"
          puts "    Source: #{info[:source]}"
        end

        puts ""
      end
    end

    desc 'validate MODEL_PATH', 'Validate an ONNX model'
    def validate(model_path)
      puts "Validating #{model_path}..."

      unless File.exist?(model_path)
        puts "Error: Model file not found: #{model_path}"
        exit 1
      end

      # Try to load the model
      begin
        model = Models::OnnxModel.from_file(model_path)

        puts "✓ Model loaded successfully"
        puts "  Language: #{model.language_code}"
        puts "  Dimension: #{model.dimension}"
        puts "  Vocabulary: #{model.vocabulary_size} words"

        # Test lookup
        test_word = model.vocabulary.first
        if test_word
          embedding = model.embedding_for(test_word)
          puts "  Test lookup: '#{test_word}' -> vector of size #{embedding.vector.size}"
        end

        puts "\n✓ Model is valid!"

      rescue StandardError => e
        puts "✗ Validation failed: #{e.message}"
        exit 1
      end
    end

    desc 'upload LANGUAGE MODEL_FILE', 'Upload model to dictionaries repository'
    option :repo, type: :string, default: 'kotoshu/dictionaries',
             desc: 'GitHub repository'
    option :branch, type: :string, default: 'main',
             desc: 'Target branch'
    option :create_pr, type: :boolean, default: false,
             desc: 'Create pull request instead of direct push'
    def upload(language, model_file)
      puts "Uploading #{model_file} to #{options[:repo]}..."

      # Check if file exists
      unless File.exist?(model_file)
        puts "Error: File not found: #{model_file}"
        exit 1
      end

      # Determine model type and destination path
      if model_file.end_with?('.vec')
        model_type = 'fasttext'
        filename = File.basename(model_file)
        dest_path = "#{language}/models/fasttext/#{filename}"
      elsif model_file.end_with?('.onnx')
        model_type = 'onnx'
        filename = File.basename(model_file)
        dest_path = "#{language}/models/onnx/#{filename}"

        # Also upload vocab and metadata files
        vocab_file = model_file.sub('.onnx', '.vocab.json')
        metadata_file = model_file.sub('.onnx', '.metadata.json')
        ort_file = model_file.sub('.onnx', '.ort.onnx')
      else
        puts "Error: Unknown file type. Expected .vec or .onnx"
        exit 1
      end

      # Build gh command
      cmd = [
        'gh', 'repo', 'clone', options[:repo], '/tmp/kotoshu-dictionaries'
      ]

      puts "Cloning repository..."
      system(*cmd)

      unless $?.success?
        puts "Error: Failed to clone repository"
        exit 1
      end

      # Copy files to destination
      target_dir = File.join('/tmp/kotoshu-dictionaries', File.dirname(dest_path))
      FileUtils.mkdir_p(target_dir)

      FileUtils.cp(model_file, File.join('/tmp/kotoshu-dictionaries', dest_path))

      if model_type == 'onnx'
        if File.exist?(vocab_file)
          FileUtils.cp(vocab_file, File.join('/tmp/kotoshu-dictionaries', dest_path.sub('.onnx', '.vocab.json')))
        end
        if File.exist?(metadata_file)
          FileUtils.cp(metadata_file, File.join('/tmp/kotoshu-dictionaries', dest_path.sub('.onnx', '.metadata.json')))
        end
        if File.exist?(ort_file)
          FileUtils.cp(ort_file, File.join('/tmp/kotoshu-dictionaries', dest_path.sub('.onnx', '.ort.onnx')))
        end
      end

      # Commit and push
      Dir.chdir('/tmp/kotoshu-dictionaries') do
        system('git', 'add', '.')

        message = "Add #{model_type} model for #{language}\n\n"
        message += "Model: #{filename}\n"
        message += "Language: #{language}\n"

        system('git', 'commit', '-m', message)

        if options[:create_pr]
          # Create branch and PR
          branch_name = "add-#{model_type}-#{language}"
          system('git', 'checkout', '-b', branch_name)
          system('git', 'push', 'origin', branch_name)
          system('gh', 'pr', 'create', '--title', "Add #{model_type} model for #{language}", '--body', message)
        else
          # Direct push
          system('git', 'push')
        end
      end

      if $?.success?
        puts "✓ Upload successful!"
        puts "  Path: #{dest_path}"
        puts "  Repository: #{options[:repo]}"
      else
        puts "✗ Upload failed!"
        exit 1
      end
    end

    private

    # Show model file information.
    #
    # @param language [String] Language code
    def show_model_info(language)
      cache = Cache::ModelCache.new
      model_path = File.join(cache.instance_variable_get(:@cache_path), language, 'models')

      if Dir.exist?(model_path)
        puts "\nModel files:"
        Dir.glob(File.join(model_path, '**/*')).each do |file|
          next if File.directory?(file)

          size = File.size(file)
          size_mb = (size.to_f / 1024 / 1024).round(2)

          puts "  #{File.basename(file)}: #{size_mb} MB"
        end
      end
    end
  end
end
