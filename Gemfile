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

# Optional runtime: enables Japanese morphological analysis. Declared
# here so the test suite covers the ja path; users install it separately
# (`gem install suika`). NOT in kotoshu.gemspec — suika's native ext
# (dartsclone) would otherwise break slim/minimal installs.
gem "suika", "~> 0.3"

group :development, :test do
  # Soft test-only deps for the framework integrations (plan 89):
  # NOT in kotoshu.gemspec. Specs guard on load and skip when the
  # gem is absent.
  gem "activemodel"
  gem "jekyll", "~> 4.0"
  gem "asciidoctor", "~> 2.0"
  gem "benchmark", "~> 0.4"
  gem "benchmark-ips", "~> 2.12"
  # rake compile for the Rust extension ext/kotoshu_native (rb_sys; the
  # rb_sys runtime dependency itself comes from kotoshu.gemspec).
  gem "rake-compiler", "~> 1.2"
  gem "rspec", "~> 3.12"
  gem "rspec-mocks", "~> 3.12"
  gem "rspec-parameterized", "~> 1.0"
  gem "rubocop", "~> 1.21"
  gem "rubocop-performance", "~> 1.20"
  gem "rubocop-rake", "~> 0.6"
  gem "rubocop-rspec", "~> 3.0"
  gem "simplecov", "~> 0.22"
  gem "yard", "~> 0.9"
end
