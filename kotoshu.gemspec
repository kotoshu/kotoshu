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
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile]) ||
        # Rust extension build state (parsanol policy: never ship binaries
        # or build artifacts, only the ext sources).
        f.start_with?(*%w[ext/kotoshu_native/target ext/kotoshu_native/.rb-sys])
    end
  end
  # Belt and braces: even if a built library somehow lands in git, never
  # package it (mirrors parsanol-ruby).
  spec.files.reject! { |f| f =~ /\.(dll|so|dylib|lib|bundle)\Z/ }
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Rust extension (plan 66 / P4b): optional native accelerator over the
  # kotoshu-rs core. Installing without a pre-existing Rust toolchain is
  # handled by rb_sys exactly like parsanol-ruby: when RubyGems invokes the
  # extconf and cargo is missing, rb_sys bootstraps a rustup toolchain
  # into the extension build directory; if the build still does not
  # produce the extension, the pure-Ruby engine is the complete fallback
  # (Kotoshu::Native.available? stays false).
  spec.extensions = ["ext/kotoshu_native/extconf.rb"]

  # Runtime dependencies
  spec.add_dependency "thor", "~> 1.0"
  spec.add_dependency "rubyzip", "~> 2.3"
  spec.add_dependency "lutaml-model", "~> 0.8"

  # Required to build the Rust extension (parsanol policy).
  spec.add_dependency "rb_sys", "~> 0.9"

  # Optional: suika is soft-required for Japanese morphological analysis.
  # Not declared here so `gem install kotoshu` succeeds on slim/minimal
  # environments where suika's native extension (dartsclone) cannot build.
  # Users who need Japanese support install it separately
  # (`gem install suika`). The library auto-detects at load time and raises
  # Kotoshu::Language::SuikaUnavailable when Japanese tokenization is
  # requested without it. All other languages are unaffected.

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
