# frozen_string_literal: true

# One-off generator for spec/fixtures/models_eval_grids.json.
# Not part of the gem or the suite; kept next to the fixture it makes.
#
# Reads the models repo eval noise.py and extracts the tr/uk/el key
# grids into the JSON fixture used by the drift-check spec.
#
# Usage: ruby scripts/extract_eval_grids.rb PATH_TO_NOISE_PY

require "json"

source = ARGV[0]
abort "usage: ruby #{__FILE__} PATH_TO_models-fasttext-onnx/eval/noise.py" unless source
abort "noise.py not found: #{source}" unless File.exist?(source)

src = File.read(source)
grids = {}
%w[_TR_Q _UK_JCUKEN _EL_PHONETIC].each do |name|
  body = src[/^#{name} = \{(.*?)^\}/m, 1]
  abort "grid #{name} not found in #{source}" unless body
  grid = {}
  body.scan(/"((?:[^"\\]|\\.)*)"\s*:\s*\((\d+),\s*(\d+)\)/) do |key, row, col|
    key = key.gsub('\\"', '"').gsub("\\\\", "\\")
    grid[key] = [Integer(row), Integer(col)]
  end
  abort "grid #{name} empty" if grid.empty?

  grids[name] = grid
end

out = File.expand_path("../spec/fixtures/models_eval_grids.json", __dir__)
File.write(out, JSON.pretty_generate({ "source" => source, "grids" => grids }) + "\n")
puts "wrote #{out}: #{grids.map { |k, v| "#{k}=#{v.size}" }.join(' ')}"
