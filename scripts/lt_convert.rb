# frozen_string_literal: true

# Convert a LanguageTool grammar.xml into Kotoshu YAML pattern rules
# and validate against the file's built-in examples (TODO.grammar/7).
#
# Usage:
#   bundle exec ruby scripts/lt_convert.rb grammar.xml en [out.yml]
#
# Without out.yml, prints conversion stats and example-suite results.

require "kotoshu/grammar"

path = ARGV[0] or abort "usage: lt_convert.rb GRAMMAR_XML LANG [OUT_YML]"
lang = ARGV[1] || "en"
out = ARGV[2]

xml = File.read(path)
loader = Kotoshu::Grammar::Loaders::LanguageToolXml.new(xml, language: lang)

total = loader.stats[:converted] + loader.stats[:skipped]
puts "converted: #{loader.stats[:converted]}/#{total} " \
     "(#{(100.0 * loader.stats[:converted] / total).round(1)}%)"
loader.stats[:skip_reasons].sort_by { |_, c| -c }.each do |reason, count|
  puts "  skip #{reason}: #{count}"
end

bad_total = 0
bad_fired = 0
good_total = 0
good_fired = 0
loader.rules.each do |hash|
  rule = Kotoshu::Grammar::PatternRule.from_yaml(hash)
  hash["examples"].to_a.each do |ex|
    if ex["bad"]
      bad_total += 1
      bad_fired += 1 if rule.check(ex["bad"]).any?
    elsif ex["good"]
      good_total += 1
      good_fired += 1 if rule.check(ex["good"]).any?
    end
  end
end
puts "examples should fire:    #{bad_fired}/#{bad_total} " \
     "= #{(100.0 * bad_fired / bad_total).round(1)}%"
puts "examples should be quiet: #{good_fired}/#{good_total} " \
     "= #{(100.0 * good_fired / good_total).round(1)}% false positive"

if out
  require "yaml"
  File.write(out, loader.rules.to_yaml)
  puts "wrote #{loader.rules.size} rules to #{out}"
end
