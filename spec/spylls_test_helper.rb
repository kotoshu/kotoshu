# frozen_string_literal: true

# Test helper module for Spylls-integration tests
module SpyllsTestHelper
  # Base folder for test fixtures
  BASE_FOLDER = File.expand_path('integrational/fixtures', __dir__).freeze

  # Read a list file (.good, .wrong, etc.)
  #
  # @param name [String] The fixture name (e.g., 'base.good', 'base.wrong')
  # @param ignoredot [Boolean] Whether to ignore lines ending with '.'
  # @return [Array<String>] List of words from the file
  #
  # @example
  #   read_list('base.good')  # => ['hello', 'world', ...]
  def read_list(name, ignoredot: true)
    path = File.join(BASE_FOLDER, name)
    return [] unless File.file?(path)

    File.read(path).split("\n").filter_map do |line|
      line = line.strip
      next if line.empty?
      next if ignoredot && line.end_with?('.')
      line
    end
  end

  # Read a dictionary from fixture files
  #
  # @param name [String] The base name of the dictionary (without extension)
  # @return [Kotoshu::Dictionary::Hunspell] The loaded dictionary
  #
  # @example
  #   dictionary = read_dictionary('base')
  def read_dictionary(name)
    path = File.join(BASE_FOLDER, name)
    dic_path = "#{path}.dic"
    aff_path = "#{path}.aff"
    Kotoshu::Dictionary::Hunspell.new(dic_path: dic_path, aff_path: aff_path, language_code: 'en')
  end

  # Create a fixture path
  #
  # @param name [String] The fixture name
  # @return [String] Full path to the fixture
  def fixture_path(name)
    File.join(BASE_FOLDER, name)
  end

  # Unit test fixtures path
  #
  # @return [String] Path to unit test fixtures
  def unit_fixtures_path
    File.expand_path('unit/hunspell/fixtures', __dir__)
  end

  # Read a unit fixture file
  #
  # @param name [String] The fixture name
  # @return [String] Full path to the unit fixture
  def unit_fixture(name)
    File.join(unit_fixtures_path, name)
  end

  module_function :read_list, :read_dictionary, :fixture_path, :unit_fixtures_path, :unit_fixture
end
