# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[spec rubocop]

namespace :kotoshu do
  namespace :conformance do
    desc <<~DESC
      Export conformance vectors for kotoshu-rs (plan 67 M3). Walks the Spylls \
      fixtures (spec/integrational/fixtures) plus the spec fixture corpus, runs \
      the real engine over every fixture word, and writes one JSON object per \
      line. `expected` values are FROZEN engine behavior (byte-reproducible \
      cross-implementation), not claims about linguistic correctness. \
      Output path: ENV["CONFORMANCE_VECTORS_PATH"] or conformance/vectors.jsonl \
      (repo root). The generated file IS committed -- conformance/ is \
      deliberately NOT gitignored -- and kotoshu-rs copies it into \
      tests/conformance/ via its documented sync step so its CI needs no gem.
    DESC
    task :export do
      path = ENV.fetch("CONFORMANCE_VECTORS_PATH", nil) || "conformance/vectors.jsonl"
      require "kotoshu"
      result = Kotoshu::ConformanceExporter.export(path: path)
      puts "Wrote #{result.row_count} vectors from #{result.corpus_count} corpora to #{result.path}"
      unless result.skipped_corpora.empty?
        puts "Skipped corpora:"
        result.skipped_corpora.each { |id, reason| puts "  #{id}: #{reason}" }
      end
      result.skipped_words.each { |(id, word), reason| puts "  Skipped word #{id} #{word.inspect}: #{reason}" }
    end
  end
end
