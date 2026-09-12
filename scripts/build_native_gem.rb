#!/usr/bin/env ruby
# frozen_string_literal: true

# Build a precompiled platform gem (plan 133): assemble kotoshu's
# gemspec around the ALREADY-COMPILED extension binary, exactly the
# surgery rb_sys's cross-compiling blocks perform — the rb_sys build
# dependency goes away (nothing builds at install), the Rust sources,
# Cargo files, and extconf drop out of the file list, and the platform
# tag makes RubyGems resolve this gem on matching platforms while the
# pure-Ruby gem keeps serving everything else.
#
# Usage: ruby scripts/build_native_gem.rb [platform]
#   platform defaults to Gem::Platform.local; pass e.g. x86_64-linux
#   when the binary was produced for another host. The compiled
#   extension must already sit at lib/kotoshu/kotoshu_native.<dlext>
#   (rake compile on the matching platform).

require "rubygems/package"
require "rbconfig"

platform = ARGV[0]
dlext = RbConfig::CONFIG["DLEXT"]
binary = File.join("lib", "kotoshu", "kotoshu_native.#{dlext}")

unless File.exist?(binary)
  abort "missing #{binary} — run `rake compile` on the target platform first"
end

spec = Gem::Specification.load("kotoshu.gemspec")
spec.platform = platform ? Gem::Platform.new(platform) : Gem::Platform.local
# The darwin deployment-target suffix (-23, -25, ...) differs per build
# machine; RubyGems matches a versionless darwin tag on any macOS of
# the same CPU, so normalize it off (the convention shipped binary
# gems use). Linux and mingw tags carry no version to begin with.
if spec.platform.os == "darwin" && spec.platform.version
  spec.platform = Gem::Platform.new("#{spec.platform.cpu}-darwin")
end
spec.files += [binary]
spec.extensions = []
spec.dependencies.reject! { |d| d.name == "rb_sys" }
spec.files.reject! { |f| f.start_with?("ext/") }

path = Gem::Package.build(spec)
puts "built #{path}"
path
