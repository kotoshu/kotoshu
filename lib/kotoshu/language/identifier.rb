# frozen_string_literal: true

module Kotoshu
  module Language
    # Language identification using FastText LID model.
    #
    # Identifies the language of text using FastText's pretrained
    # language identification model (lid.176.ftz).
    #
    # @example Detect language
    #   lid = LanguageIdentifier.new
    #   result = lid.detect("Hello world")
    #   result.language  # => "en"
    #   result.confidence  # => 0.95
    #
    # @example Detect from file
    #   results = lid.detect_from_file("document.txt", top_k: 3)
    #   results.map(&:language)  # => ["en", "de", "fr"]
    class LanguageIdentifier
      # FastText LID model URL
      MODEL_URL = 'https://dl.fbaipublicfiles.com/fasttext/supervised-models/lid.176.ftz'

      # Language code mapping (FastText LID → ISO 639-1)
      LANGUAGE_MAPPING = {
        # FastText uses format like "__label__en" for English
        'en' => 'en',
        'de' => 'de',
        'es' => 'es',
        'fr' => 'fr',
        'pt' => 'pt',
        'ru' => 'ru',
        'it' => 'it',
        'nl' => 'nl',
        'pl' => 'pl',
        'sv' => 'sv',
        'da' => 'da',
        'no' => 'no',
        'fi' => 'fi',
        'cs' => 'cs',
        'el' => 'el',
        'hu' => 'hu',
        'ro' => 'ro',
        'bg' => 'bg',
        'sk' => 'sk',
        'sl' => 'sl',
        'hr' => 'hr',
        'sr' => 'sr',
        'et' => 'et',
        'lv' => 'lv',
        'lt' => 'lt',
        'mt' => 'mt',
        'ga' => 'ga',
        'cy' => 'cy',
        'tr' => 'tr',
        'ar' => 'ar',
        'he' => 'he',
        'fa' => 'fa',
        'ur' => 'ur',
        'hi' => 'hi',
        'bn' => 'bn',
        'ta' => 'ta',
        'te' => 'te',
        'ml' => 'ml',
        'kn' => 'kn',
        'th' => 'th',
        'vi' => 'vi',
        'id' => 'id',
        'ms' => 'ms',
        'sw' => 'sw',
        'zh' => 'zh',
        'ja' => 'ja',
        'ko' => 'ko'
      }.freeze

      # Value object for detection result.
      #
      # @attr_reader [String] language ISO 639-1 language code
      # @attr_reader [Float] confidence Confidence score (0.0 to 1.0)
      # @attr_reader [String] label Raw FastText label
      DetectionResult = Struct.new(:language, :confidence, :label, keyword_init: true) do
        def to_s
          "#{language} (#{(confidence * 100).round(1)}%)"
        end
      end

      attr_reader :model_path, :loaded

      # Create a new language identifier.
      #
      # @param model_path [String] Path to lid.176.ftz model
      # @param auto_download [Boolean] Download model if not found
      def initialize(model_path: nil, auto_download: true)
        @model_path = model_path || default_model_path
        @auto_download = auto_download
        @loaded = false
      end

      # Detect language of text.
      #
      # @param text [String] Text to analyze
      # @param top_k [Integer] Number of top results to return
      # @return [Array<DetectionResult>] Detection results sorted by confidence
      def detect(text, top_k: 1)
        ensure_model_loaded

        # Preprocess text
        text = preprocess_text(text)

        # Run detection
        run_detection(text, top_k)
      end

      # Detect language from file.
      #
      # @param filepath [String] Path to file
      # @param top_k [Integer] Number of top results
      # @return [Array<DetectionResult>] Detection results
      def detect_from_file(filepath, top_k: 1)
        text = File.read(filepath, encoding: 'UTF-8')
        detect(text, top_k: top_k)
      end

      # Get the most likely language.
      #
      # @param text [String] Text to analyze
      # @return [DetectionResult, nil] Top detection result
      def detect_primary(text)
        detect(text, top_k: 1).first
      end

      # Check if model is downloaded.
      #
      # @return [Boolean] True if model file exists
      def model_downloaded?
        File.exist?(@model_path)
      end

      # Download the FastText LID model.
      #
      # @return [String] Path to downloaded model
      def download_model
        require 'net/http'
        require 'uri'
        require 'fileutils'

        # Create directory
        FileUtils.mkdir_p(File.dirname(@model_path))

        puts "Downloading language identification model..."
        puts "  From: #{MODEL_URL}"
        puts "  To: #{@model_path}"

        uri = URI.parse(MODEL_URL)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        request = Net::HTTP::Get.new(uri.request_uri)

        http.request(request) do |response|
          case response
          when Net::HTTPSuccess
            File.open(@model_path, 'wb') do |file|
              response.read_body do |chunk|
                file.write(chunk)
              end
            end
            puts "  ✓ Download complete"
          when Net::HTTPRedirection
            # Follow redirect
            follow_redirect(response['location'])
          else
            raise "Failed to download model: #{response.code} #{response.message}"
          end
        end

        @model_path
      end

      # Get supported languages.
      #
      # @return [Array<String>] List of supported ISO 639-1 codes
      def self.supported_languages
        LANGUAGE_MAPPING.keys
      end

      private

      # Get default model path.
      #
      # @return [String] Default path for lid.176.ftz
      def default_model_path
        File.join(Kotoshu::Paths.cache_path, 'models', 'lid.176.ftz')
      end

      # Ensure model is loaded.
      def ensure_model_loaded
        # Download if needed
        if @auto_download && @auto_download && !model_downloaded?
          download_model
        end

        raise "Model not found: #{@model_path}" unless model_downloaded?

        # Load model (lazy)
        return if @loaded

        load_model
      end

      # Load the FastText model.
      def load_model
        # Try to use fasttext CLI
        if fasttext_available?
          @loaded = true
          return
        end

        # Try to use Python fasttext library
        if python_fasttext_available?
          @loaded = true
          return
        end

        raise "FastText not available. Install fasttext CLI or Python library"
      end

      # Check if fasttext CLI is available.
      #
      # @return [Boolean] True if fasttext command exists
      def fasttext_available?
        system('which', 'fasttext', out: File::NULL, err: File::NULL)
      end

      # Check if Python fasttext library is available.
      #
      # @return [Boolean] True if fasttext Python package is installed
      def python_fasttext_available?
        system('python3', '-c', 'import fasttext', out: File::NULL, err: File::NULL)
      end

      # Preprocess text for detection.
      #
      # @param text [String] Raw text
      # @return [String] Preprocessed text
      def preprocess_text(text)
        # Remove leading/trailing whitespace
        text = text.strip

        # Take first N characters (FastText LID works best with 100-1000 chars)
        # Taking first 500 characters as default
        text = text[0..500] if text.length > 500

        # Normalize whitespace
        text.gsub(/\s+/, ' ')
      end

      # Run language detection.
      #
      # @param text [String] Preprocessed text
      # @param top_k [Integer] Number of results
      # @return [Array<DetectionResult>] Detection results
      def run_detection(text, top_k)
        # Create temp file with text
        require 'tempfile'
        Tempfile.create('lid_input_', encoding: 'UTF-8') do |f|
          f.write(text)
          f.flush

          # Run fasttext command
          if fasttext_available?
            return run_fasttext_cli(f.path, top_k)
          end

          # Run Python fasttext
          if python_fasttext_available?
            return run_python_fasttext(f.path, top_k)
          end
        end
      end

      # Run detection using fasttext CLI.
      #
      # @param input_file [String] Path to input file
      # @param top_k [Integer] Number of results
      # @return [Array<DetectionResult>] Detection results
      def run_fasttext_cli(input_file, top_k)
        require 'open3'

        cmd = [
          'fasttext',
          'predict',
          @model_path,
          input_file,
          top_k.to_s
        ]

        output, = Open3.capture3(*cmd)

        parse_fasttext_output(output)
      end

      # Run detection using Python fasttext.
      #
      # @param input_file [String] Path to input file
      # @param top_k [Integer] Number of results
      # @return [Array<DetectionResult>] Detection results
      def run_python_fasttext(input_file, top_k)
        require 'open3'

        script = <<~PYTHON
          import fasttext
          model = fasttext.load_model('#{@model_path}')
          with open('#{input_file}', 'r') as f:
              text = f.read().strip()
          labels, probs = model.predict(text, k=#{top_k})
          for label, prob in zip(labels, probs):
              print(f"{label} {prob}")
        PYTHON

        output, = Open3.capture3('python3', '-c', script)

        parse_fasttext_output(output)
      end

      # Parse FastText output.
      #
      # @param output [String] Raw output from fasttext
      # @return [Array<DetectionResult>] Parsed results
      def parse_fasttext_output(output)
        output.split("\n").map do |line|
          next if line.empty?

          # Parse: __label__en 0.95
          parts = line.strip.split
          next unless parts.size == 2

          label = parts[0].sub('__label__', '')
          confidence = parts[1].to_f

          # Map to ISO 639-1
          language = LANGUAGE_MAPPING[label] || label

          DetectionResult.new(
            language: language,
            confidence: confidence,
            label: label
          )
        end.compact.sort_by { |r| -r.confidence }
      end

      # Follow HTTP redirect.
      #
      # @param url [String] Redirect URL
      def follow_redirect(url)
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true if uri.scheme == 'https'

        request = Net::HTTP::Get.new(uri.request_uri)

        http.request(request) do |response|
          case response
          when Net::HTTPSuccess
            File.open(@model_path, 'wb') do |file|
              response.read_body do |chunk|
                file.write(chunk)
              end
            end
          when Net::HTTPRedirection
            follow_redirect(response['location'])
          end
        end
      end
    end
  end
end
