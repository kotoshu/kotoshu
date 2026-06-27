# frozen_string_literal: true

require_relative "lib/kotoshu/version"

Gem::Specification.new do |spec|
  spec.name = "kotoshu"
  spec.version = Kotoshu::VERSION
  spec.authors = ["Ribose Inc."]
  spec.email = ["open.source@ribose.com"]

  spec.summary = "Semantic spell checker for Ruby using ONNX word embeddings"
  spec.description = "Kotoshu is a semantic spell checker for Ruby that uses " \
                    "FastText word embeddings (via ONNX) for context-aware spelling " \
                    "and grammar suggestions. Supports multiple languages with " \
                    "automatic detection, interactive review, and CI/CD integration."
  spec.homepage = "https://github.com/kotoshu/kotoshu"
  spec.required_ruby_version = ">= 3.1.0"
  spec.license = "BSD-2-Clause"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/kotoshu/kotoshu/tree/main"
  spec.metadata["changelog_uri"] = "https://github.com/kotoshu/kotoshu/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "thor", "~> 1.0"
  spec.add_dependency "suika", "~> 0.3"
  spec.add_dependency "rubyzip", "~> 2.3"

  # Optional: onnxruntime is soft-required for semantic features.
  # Not declared here so `gem install kotoshu` succeeds on platforms
  # where onnxruntime fails to build. Users who want semantic analysis
  # install it separately (`gem install onnxruntime`). The library
  # auto-detects at load time and raises Models::OnnxUnavailable if
  # a caller requests semantic features without it.

  # Development dependencies are specified in Gemfile

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
