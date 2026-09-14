# frozen_string_literal: true

require "spec_helper"
require "rake"

# Plan 135: the task exists, is documented, and targets the ext's
# Cargo pin. The update-and-compile itself runs cargo (proven live on
# this machine, 2026-09-14); CI's extension-less legs must not invoke
# it, so the spec asserts the wiring, not the build.
RSpec.describe "rake ext:update" do
  it "is syntactically valid and documented" do
    rakefile = File.expand_path("../../Rakefile", __dir__)
    expect(`ruby -c #{rakefile} 2>&1`).to include("Syntax OK")
    expect(File.read(rakefile)).to match(/desc "Update the ext's kotoshu-rs pin to latest main and recompile"/)
  end

  it "lives beside the conformance namespace in the Rakefile source" do
    rakefile = File.read(File.expand_path("../../Rakefile", __dir__))
    expect(rakefile).to include('task "ext:update"')
    expect(rakefile).to include("CARGO_NET_GIT_FETCH_WITH_CLI")
  end
end
