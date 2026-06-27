# frozen_string_literal: true

require_relative 'protocol'

# OnnxRuntimeModel - ONNX Runtime wrapper for FastText embeddings
#
# Provides embedding inference using ONNX Runtime. Supports single lookups,
# batch inference, and vocabulary-aware operations.
#
# @example Single embedding lookup
#   model = OnnxRuntimeModel.from_file('fasttext.en.onnx', language_code: 'en')
#   model.load!
#   embedding = model.get_embedding(1234)
#
# @example Batch lookup
#   embeddings = model.get_embeddings([1, 2, 3, 4, 5])
#
# @example With vocabulary
#   embedding = model.get_embedding_for_word('hello', vocabulary)
#
class OnnxRuntimeModel
  include EmbeddingModelProtocol

  # Default dimension for FastText models
  DEFAULT_DIMENSION = 300

  # Batch size for batch inference
  BATCH_SIZE = 32

  # @return [String] Language code (ISO 639-1)
  attr_reader :language_code

  # @return [Integer] Embedding dimension
  attr_reader :dimension

  # @return [String] Path to ONNX model file
  attr_reader :onnx_path

  # @return [Boolean] Whether the model is loaded
  attr_reader :loaded

  # @return [Integer] Number of inference calls
  attr_reader :inference_count

  # Create a new ONNX Runtime model
  #
  # @param language_code [String] ISO 639-1 language code
  # @param onnx_path [String] Path to .onnx file
  # @param dimension [Integer] Embedding dimension (default: 300)
  #
  def initialize(language_code:, onnx_path:, dimension: DEFAULT_DIMENSION)
    @language_code = language_code
    @onnx_path = onnx_path
    @dimension = dimension
    @session = nil
    @loaded = false
    @input_name = nil
    @output_name = nil
    @inference_count = 0
  end

  # Load the ONNX model into memory
  #
  # @return [self]
  #
  # @raise [Kotoshu::Models::OnnxUnavailable] if onnxruntime gem is missing
  # @raise [ArgumentError] if model file doesn't exist
  #
  def load!
    return self if @loaded

    raise Kotoshu::Models::OnnxModel::OnnxUnavailable unless Kotoshu::Models::OnnxModel::ONNX_LOADED

    raise ArgumentError, "ONNX file not found: #{@onnx_path}" unless File.exist?(@onnx_path)

    @session = OnnxRuntime::InferenceSession.new(@onnx_path)

    # Detect input/output names
    @input_name = detect_input_name
    @output_name = detect_output_name

    @loaded = true
    self
  end

  # Unload the model from memory
  #
  # @return [self]
  #
  def unload!
    @session = nil
    @input_name = nil
    @output_name = nil
    @loaded = false
    self
  end

  # Check if model is ready for inference
  #
  # @return [Boolean]
  #
  def ready?
    @loaded && !@session.nil?
  end

  # Get embedding for a single word index
  #
  # @param index [Integer] Word index in vocabulary
  # @return [Array<Float>] Embedding vector
  #
  # @raise [RuntimeError] if model is not loaded
  # @raise [ArgumentError] if index is invalid
  #
  def get_embedding(index)
    ensure_loaded

    raise ArgumentError, "Invalid word index: #{index}" unless valid_index?(index)

    output = @session.run(
      [@output_name],
      { @input_name => [index] }
    )

    @inference_count += 1

    extract_embedding(output.first)
  end

  # Get embeddings for multiple indices (batched)
  #
  # More efficient than individual calls for batch operations.
  #
  # @param indices [Array<Integer>] Word indices
  # @return [Array<Array<Float>>] Array of embedding vectors
  #
  def get_embeddings(indices)
    ensure_loaded
    return [] if indices.nil? || indices.empty?

    valid_indices = indices.select { |i| valid_index?(i) }
    return [] if valid_indices.empty?

    # Process in batches for memory efficiency
    valid_indices.each_slice(BATCH_SIZE).flat_map do |batch|
      run_batch_inference(batch)
    end
  end

  # Preload all embeddings into memory
  #
  # For small vocabularies, this provides O(1) lookup after loading.
  #
  # @param vocabulary [Vocabulary] Vocabulary with complete word list
  # @return [Hash<Integer, Array<Float>>] Index to embedding mapping
  #
  def preload_embeddings!(vocabulary)
    ensure_loaded

    all_indices = (0...vocabulary.size).to_a
    embeddings = get_embeddings(all_indices)

    # Build index mapping
    all_indices.zip(embeddings).to_h
  end

  # Get embedding for a word using vocabulary
  #
  # @param word [String] The word to lookup
  # @param vocabulary [Vocabulary] Vocabulary for word-to-index mapping
  # @return [Array<Float>, nil] Embedding vector or nil if word not found
  #
  def get_embedding_for_word(word, vocabulary)
    index = vocabulary.lookup(word)
    return nil unless index

    get_embedding(index)
  end

  # Get embeddings for multiple words using vocabulary
  #
  # @param words [Array<String>] Words to lookup
  # @param vocabulary [Vocabulary] Vocabulary for word-to-index mapping
  # @return [Hash<String, Array<Float>>] Word to embedding mapping
  #
  def get_embeddings_for_words(words, vocabulary)
    result = {}
    words.each do |word|
      embedding = get_embedding_for_word(word, vocabulary)
      result[word] = embedding if embedding
    end
    result
  end

  # Check if batching is supported
  #
  # @return [Boolean]
  #
  def supports_batching?
    true
  end

  # Get batch size for batch inference
  #
  # @return [Integer]
  #
  def batch_size
    BATCH_SIZE
  end

  # Get model type identifier
  #
  # @return [String]
  #
  def model_type
    'onnx'
  end

  # Get model information
  #
  # @return [Hash]
  #
  def model_info
    {
      type: 'onnx',
      language: @language_code,
      dimension: @dimension,
      path: @onnx_path,
      loaded: @loaded,
      inference_count: @inference_count
    }
  end

  # Create model from file
  #
  # @param onnx_path [String] Path to .onnx file
  # @param language_code [String] Language code (auto-detected if nil)
  # @param dimension [Integer] Embedding dimension
  # @return [OnnxRuntimeModel]
  #
  def self.from_file(onnx_path, language_code: nil, dimension: nil)
    raise ArgumentError, "ONNX file not found: #{onnx_path}" unless File.exist?(onnx_path)

    language_code ||= detect_language_from_path(onnx_path)
    dimension ||= DEFAULT_DIMENSION

    new(
      language_code: language_code,
      onnx_path: onnx_path,
      dimension: dimension
    )
  end

  # Create model from cache
  #
  # @param language_code [String] ISO 639-1 language code
  # @param cache [Cache::ModelCache] Cache instance
  # @return [OnnxRuntimeModel, nil]
  #
  def self.from_cache(language_code, cache = nil)
    require_relative '../cache/model_cache'

    cache ||= Cache::ModelCache.new

    onnx_path = cache.get_onnx_model(language_code)
    return nil unless onnx_path

    from_file(onnx_path, language_code: language_code)
  end

  # String representation
  #
  # @return [String]
  #
  def to_s
    "OnnxRuntimeModel(language: #{@language_code}, dimension: #{@dimension}, loaded: #{@loaded})"
  end
  alias inspect to_s

  private

  # Ensure model is loaded
  #
  def ensure_loaded
    load! unless @loaded
  end

  # Check if index is valid
  #
  def valid_index?(index)
    index.is_a?(Integer) && index >= 0
  end

  # Run batch inference for a batch of indices
  #
  # @param indices [Array<Integer>] Word indices
  # @return [Array<Array<Float>>] Embedding vectors
  #
  def run_batch_inference(indices)
    # Create input tensor
    input_data = indices.flatten

    output = @session.run(
      [@output_name],
      { @input_name => input_data }
    )

    @inference_count += 1

    # Extract embeddings
    result = output.first
    if result.is_a?(Array)
      result
    else
      # Handle OrtValue or other wrappers
      indices.length.times.map { |i| extract_single_embedding(result, i) }
    end
  end

  # Extract embedding from output
  #
  # @param output [Object] ONNX output
  # @return [Array<Float>]
  #
  def extract_embedding(output)
    case output
    when Array
      output
    when NumpyArray, Numo::SFloat
      output.to_a
    when OnnxRuntime::OrtValue
      output.to_a
    else
      # Try to convert to array
      output.respond_to?(:to_a) ? output.to_a : Array(output)
    end
  end

  # Extract single embedding from batch output
  #
  # @param output [Object] ONNX batch output
  # @param index [Integer] Index in batch
  # @return [Array<Float>]
  #
  def extract_single_embedding(output, index)
    case output
    when Array
      output[index]
    when NumpyArray, Numo::SFloat
      output[index, true].to_a
    else
      # Default: assume array-like
      output[index].to_a
    end
  end

  # Detect input name from model
  #
  # @return [String]
  #
  def detect_input_name
    inputs = @session.inputs
    inputs&.first&.dig(:name) || 'word_index'
  end

  # Detect output name from model
  #
  # @return [String]
  #
  def detect_output_name
    outputs = @session.outputs
    outputs&.first&.dig(:name) || 'embedding'
  end

  # Detect language from file path
  #
  # @param path [String]
  # @return [String]
  #
  def self.detect_language_from_path(path)
    basename = File.basename(path)

    if basename =~ /\.([a-z]{2})\./i
      Regexp.last_match(1).downcase
    else
      'en'
    end
  end
end
