# frozen_string_literal: true

require 'json'
require_relative 'protocol'

# Vocabulary - Word to index mapping
#
# Provides efficient lookup from words to integer indices for embedding retrieval.
# Supports JSON file loading and saving.
#
# @example Creating a vocabulary
#   vocab = Kotoshu::Embeddings::Vocabulary.new(
#     language_code: 'en',
#     word_to_index: { 'hello' => 0, 'world' => 1 }
#   )
#
# @example Loading from file
#   vocab = Kotoshu::Embeddings::Vocabulary.from_file('/path/to/vocab.json', language_code: 'en')
#
class Vocabulary
  include VocabularyProtocol

  # @return [String] ISO 639-1 language code
  attr_reader :language_code

  # @return [Hash{String => Integer}] Word to index mapping
  attr_reader :word_to_index

  # @return [Array<String>] Index to word mapping (sparse array)
  attr_reader :index_to_word

  # Create a new vocabulary
  #
  # @param language_code [String] ISO 639-1 language code
  # @param word_to_index [Hash{String => Integer}] Word to index mapping
  #
  # @raise [ArgumentError] If word_to_index is empty
  #
  def initialize(language_code:, word_to_index:)
    raise ArgumentError, 'word_to_index cannot be empty' if word_to_index.nil? || word_to_index.empty?

    @language_code = language_code
    @word_to_index = word_to_index.dup.freeze

    # Build reverse index (index -> word)
    @index_to_word = Array.new(@word_to_index.size)
    @word_to_index.each do |word, index|
      @index_to_word[index] = word if index < @index_to_word.size
    end
    @index_to_word.freeze
  end

  # Look up word index
  #
  # @param word [String] The word to look up
  # @return [Integer, nil] Index of the word, or nil if not found
  #
  def lookup(word)
    @word_to_index[word]
  end

  # Get word by index
  #
  # @param index [Integer] The index to look up
  # @return [String, nil] Word at the index, or nil if not found
  #
  def get_word(index)
    @index_to_word[index]
  end

  # Check if word exists in vocabulary
  #
  # @param word [String] Word to check
  # @return [Boolean] True if word exists
  #
  def include?(word)
    @word_to_index.key?(word)
  end

  # Get vocabulary size
  #
  # @return [Integer] Number of words in vocabulary
  #
  def size
    @word_to_index.size
  end

  # Check if index is valid
  #
  # @param index [Integer] Index to check
  # @return [Boolean] True if index is valid
  #
  def valid_index?(index)
    index.is_a?(Integer) && index >= 0 && index < @word_to_index.size
  end

  # Get common/most frequent words
  #
  # @param n [Integer] Number of words to return
  # @return [Array<String>] Array of common words
  #
  def common_words(n: 10)
    return [] if @word_to_index.empty?

    @word_to_index.keys.first(n)
  end

  # Convert to Hash
  #
  # @return [Hash{String => Integer}] Copy of word_to_index mapping
  #
  def to_h
    @word_to_index.dup
  end

  # Get all words as enumerator
  #
  # @return [Enumerator<String>] Enumerator of all words
  #
  def words
    @word_to_index.each_key
  end

  # Load vocabulary from JSON file
  #
  # @param path [String] Path to JSON file
  # @param language_code [String] Language code (auto-detected from filename if nil)
  # @return [Vocabulary] New vocabulary instance
  #
  # @raise [ArgumentError] If file doesn't exist
  # @raise [Json::ParserError] If file is not valid JSON
  #
  def self.from_file(path, language_code: nil)
    raise ArgumentError, "File not found: #{path}" unless File.exist?(path)

    language_code ||= detect_language_from_path(path)

    data = JSON.parse(File.read(path))

    case data
    when Hash
      word_to_index = data.transform_keys(&:freeze).freeze
    when Array
      word_to_index = {}
      data.each_with_index do |word, index|
        word_to_index[word.freeze] = index
      end
      word_to_index.freeze
    else
      raise ArgumentError, "Invalid vocabulary format: expected Hash or Array"
    end

    new(language_code: language_code, word_to_index: word_to_index)
  end

  # Create vocabulary from Array of words
  #
  # @param words [Array<String>] Array of words
  # @param language_code [String] Language code
  # @return [Vocabulary] New vocabulary instance
  #
  def self.from_words(words, language_code: 'en')
    word_to_index = {}
    words.each_with_index do |word, index|
      word_to_index[word.freeze] = index
    end
    word_to_index.freeze

    new(language_code: language_code, word_to_index: word_to_index)
  end

  # Save vocabulary to JSON file
  #
  # @param path [String] Path to save file
  # @param format [Symbol] Format: :hash or :array
  #
  def save_to_file(path, format: :hash)
    case format
    when :hash
      data = @word_to_index.dup
    when :array
      max_index = @index_to_word.compact.length
      data = @index_to_word.compact.first(max_index)
    else
      raise ArgumentError, "Unknown format: #{format}"
    end

    File.write(path, JSON.pretty_generate(data))
  end

  # Check if vocabulary is empty
  #
  # @return [Boolean] True if empty
  #
  def empty?
    @word_to_index.empty?
  end

  # Get a sample of words
  #
  # @param n [Integer] Number of words to sample
  # @return [Array<String>] Sample of words
  #
  def sample(n: 10)
    @word_to_index.keys.sample(n)
  end

  # Create a sub-vocabulary containing only specified words
  #
  # @param words [Array<String>] Words to include
  # @return [Vocabulary] New vocabulary with subset of words
  #
  def sub_vocabulary(words)
    filtered = @word_to_index.select { |w, _| words.include?(w) }
    self.class.new(language_code: @language_code, word_to_index: filtered)
  end

  # Find words starting with a prefix
  #
  # @param prefix [String] Prefix to match
  # @return [Array<String>] Matching words
  #
  def words_starting_with(prefix)
    pattern = /^#{Regexp.escape(prefix)}/
    @word_to_index.keys.grep(pattern)
  end

  # String representation
  #
  # @return [String]
  #
  def to_s
    "Vocabulary(language: #{@language_code}, size: #{@word_to_index.size})"
  end
  alias inspect to_s

  private_class_method

  # Detect language code from file path
  #
  # @param path [String] File path
  # @return [String] Detected language code
  #
  def self.detect_language_from_path(path)
    basename = File.basename(path)

    if basename =~ /(\w+)\.vocab\.json\z/
      return $1
    end

    if basename =~ /\.(\w+)\.vocab\.json\z/
      return $1
    end

    'unknown'
  end
end
