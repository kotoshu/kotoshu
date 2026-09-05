# frozen_string_literal: true

require "spec_helper"
require "json"
require "kotoshu/keyboard"

# Drift check (plan 84, Track A): the Turkish-Q, Ukrainian-JCUKEN and
# Greek-phonetic key grids in the gem must cover the grids the models
# repo eval harness types on (kotoshu/models-fasttext-onnx
# eval/noise.py). The gem layouts drive suggestion ranking; the eval
# grids drive model quality gates — when they drift apart, models are
# evaluated on typos the gem cannot rank correctly.
#
# The eval grids are checked against the live models repo checkout
# when one is present (sibling directory or KOTOSHU_MODELS_REPO), and
# against the committed snapshot fixture otherwise (CI).
RSpec.describe "keyboard layout sync with the models repo eval grids" do
  GRID_NAME = {
    "tr" => ["TurkishQ", "_TR_Q"],
    "uk" => ["Ukrainian", "_UK_JCUKEN"],
    "el" => ["GreekPhonetic", "_EL_PHONETIC"]
  }.freeze

  def gem_layout_for(lang)
    Kotoshu::Keyboard::Layouts.const_get(GRID_NAME[lang][0])
  end

  def python_grid_name(lang)
    GRID_NAME[lang][1]
  end

  # Parse one `NAME = { ... }` grid out of noise.py. Returns nil when
  # the grid is absent (a models repo older than the wave-1 grids).
  def parse_grid(noise_source, name)
    body = noise_source[/^#{name} = \{(.*?)^\}/m, 1]
    return nil unless body

    grid = {}
    body.scan(/"((?:[^"\\]|\\.)*)"\s*:\s*\((\d+),\s*(\d+)\)/) do |key, row, col|
      key = key.gsub('\\"', '"').gsub("\\\\", "\\")
      grid[key] = [Integer(row), Integer(col)]
    end
    grid
  end

  def noise_py_path
    explicit = ENV.fetch("KOTOSHU_MODELS_REPO", nil)
    return File.join(explicit, "eval/noise.py") if explicit

    # The models repo is a workspace sibling; walk ancestors so the
    # check also works from git worktrees deeper in the tree.
    dir = File.dirname(__dir__)
    until dir == "/"
      candidate = File.join(dir, "models-fasttext-onnx/eval/noise.py")
      return candidate if File.exist?(candidate)

      dir = File.dirname(dir)
    end
    nil
  end

  def fixture_grids
    path = File.expand_path("../../../fixtures/models_eval_grids.json", __dir__)
    JSON.parse(File.read(path)).fetch("grids")
  end

  # Grids parsed from the live models repo checkout, or nil when the
  # checkout is absent or predates the wave-1 grids (< v1.1.0).
  def live_grids
    path = noise_py_path
    return nil unless path

    source = File.read(path)
    grids = {}
    GRID_NAME.each_value do |(_, name)|
      grid = parse_grid(source, name)
      return nil if grid.nil? || grid.empty?

      grids[name] = grid
    end
    grids
  end

  def eval_grids
    live_grids || fixture_grids
  end

  it "keeps every eval grid key on the gem layout at the same position" do
    GRID_NAME.each_key do |lang|
      gem_positions = gem_layout_for(lang).new.key_positions
      eval_grid = eval_grids.fetch(python_grid_name(lang))

      expect(gem_positions.keys).to include(*eval_grid.keys),
                                    "#{lang}: gem layout is missing eval grid keys"
      eval_grid.each do |key, position|
        expect(gem_positions[key]).to eq(position),
                                      "#{lang}: key #{key.inspect} drifted from the eval grid"
      end
    end
  end

  it "keeps the committed fixture in sync with the live eval grids" do
    grids = live_grids
    skip "models repo absent or predates the wave-1 grids" if grids.nil?

    expect(fixture_grids).to eq(grids),
                             "spec/fixtures/models_eval_grids.json is stale - " \
                             "regenerate with scripts/extract_eval_grids.rb"
  end

  it "can rank the eval grids common typo neighbors" do
    GRID_NAME.each_key do |lang|
      layout = gem_layout_for(lang).new
      eval_grid = eval_grids.fetch(python_grid_name(lang))

      # Every distance-1 pair in the eval grid must be distance 1 in
      # the gem layout (the pairs typo models draw from).
      pairs = eval_grid.flat_map do |key, pos|
        eval_grid.select { |_, other| other != pos }
          .select { |_, other| (other[0] - pos[0]).abs + (other[1] - pos[1]).abs == 1 }
          .keys.map { |neighbor| [key, neighbor] }
      end
      expect(pairs).not_to be_empty
      pairs.each do |a, b|
        expect(layout.distance(a, b)).to eq(1),
                                         "#{lang}: #{a}/#{b} adjacent in eval, #{layout.distance(a, b)} in gem"
      end
    end
  end
end
