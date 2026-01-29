# frozen_string_literal: true

require_relative "lib/kotoshu/version"

Gem::Specification.new do |spec|
  spec.name = "kotoshu"
  spec.version = Kotoshu::VERSION
  spec.authors = ["Ronald Tse"]
  spec.email = ["ronald.tse@ribose.com"]

  spec.summary = "A Ruby spellchecker library with multiple dictionary backends"
  spec.description = "Kotoshu is a spellchecker library for Ruby supporting multiple " \
                    "dictionary formats (Hunspell, CSpell, UnixWords, PlainText) and " \
                    "suggestion algorithms (Edit Distance, Phonetic, Trie Walk)."
  spec.homepage = "https://github.com/kotoshu/kotoshu"
  spec.required_ruby_version = ">= 3.1.0"
  spec.license = "BSD-2-Clause"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/kotoshu/kotoshu/tree/main"
  spec.metadata["changelog_uri"] = "https://github.com/kotoshu/kotoshu/blob/main/CHANGELOG.md"

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

  # Development dependencies are specified in Gemfile

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
