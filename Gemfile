# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in kotoshu.gemspec
gemspec

gem "rubyzip", "~> 2.3"
gem "irb"
gem "rake", "~> 13.0"
gem "thor", "~> 1.0"

# Optional runtime: enables semantic analysis. Declared here so the
# test suite and local dev exercise both paths; users install it
# separately (see README). NOT in kotoshu.gemspec.
gem "onnxruntime", "~> 0.10"

group :development, :test do
  gem "asciidoctor", "~> 2.0"
  gem "benchmark-ips", "~> 2.12"
  gem "rspec", "~> 3.12"
  gem "rspec-mocks", "~> 3.12"
  gem "rspec-parameterized", "~> 1.0"
  gem "rubocop", "~> 1.21"
  gem "rubocop-rspec", "~> 2.20"
  gem "simplecov", "~> 0.22"
  gem "yard", "~> 0.9"
end
