# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[spec rubocop]

# Conformance failure reporters (kept as lambdas so nothing leaks into
# Object from the Rakefile).
report_failures = lambda do |failures, label = nil|
  failures.first(10).each do |failure|
    prefix = label ? "[#{label}] " : ""
    puts "#{prefix}##{failure.index} #{failure.kind} #{failure.input.inspect} " \
         "on #{failure.dictionary}: expected #{failure.expected.inspect}, got #{failure.actual.inspect}"
  end
  puts "... and #{failures.size - 10} more" if failures.size > 10
end

report_divergences = lambda do |divergences|
  divergences.first(10).each do |divergence|
    puts "[divergence] ##{divergence.index} #{divergence.kind} #{divergence.input.inspect} " \
         "on #{divergence.dictionary}: ruby #{divergence.expected.inspect}, " \
         "native #{divergence.actual.inspect}"
  end
  puts "... and #{divergences.size - 10} more" if divergences.size > 10
end

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

    desc <<~DESC
      Replay conformance/vectors.jsonl through the pure-Ruby engine \
      (plan 66 dual-backend suite). Every vector must reproduce its frozen \
      expectation; exits nonzero on any mismatch.
    DESC
    task :ruby do
      require "kotoshu"
      result = Kotoshu::ConformanceRunner.new.run(backend: :ruby)
      puts "ruby backend: #{result.row_count} vectors, #{result.failures.size} failures"
      report_failures.call(result.failures)
      abort "kotoshu:conformance:ruby: #{result.failures.size} of #{result.row_count} vectors diverged" unless result.ok?
    end

    desc <<~DESC
      Replay conformance/vectors.jsonl through the native (Rust) engine \
      (plan 66 dual-backend suite). Requires the extension to be built \
      (rake compile); exits nonzero on any mismatch.
    DESC
    task :native do
      require "kotoshu"
      unless Kotoshu::Native.available?
        abort "kotoshu:conformance:native requires the native extension -- run `rake compile` first"
      end

      result = Kotoshu::ConformanceRunner.new.run(backend: :native)
      puts "native backend: #{result.row_count} vectors, #{result.failures.size} failures"
      report_failures.call(result.failures)
      abort "kotoshu:conformance:native: #{result.failures.size} of #{result.row_count} vectors diverged" unless result.ok?
    end

    desc <<~DESC
      Run the conformance vectors through BOTH backends and diff every row \
      (plan 66 acceptance: zero diffs). Also fails when either backend \
      diverges from the frozen expectations. Requires the extension \
      (rake compile).
    DESC
    task :compare do
      require "kotoshu"
      unless Kotoshu::Native.available?
        abort "kotoshu:conformance:compare requires the native extension -- run `rake compile` first"
      end

      result = Kotoshu::ConformanceRunner.new.compare
      puts "compare: #{result.ruby.row_count} vectors -- ruby failures: " \
           "#{result.ruby.failures.size}, native failures: #{result.native.failures.size}, " \
           "backend divergences: #{result.divergences.size}"
      report_failures.call(result.ruby.failures, "ruby")
      report_failures.call(result.native.failures, "native")
      report_divergences.call(result.divergences)
      unless result.ok?
        abort "kotoshu:conformance:compare: backends diverged " \
              "(ruby #{result.ruby.failures.size}, native #{result.native.failures.size}, " \
              "cross #{result.divergences.size} of #{result.ruby.row_count})"
      end
    end
  end
end
