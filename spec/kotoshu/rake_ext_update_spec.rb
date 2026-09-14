# frozen_string_literal: true

require "spec_helper"
require "rake"
require "open3"

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

# Plan 138: the weekly drift guard. Runs the REAL task in a real
# subprocess against the REAL Cargo.lock — no fixtures, no stubs; the
# pinned rev is read with the same convention the task itself uses.
RSpec.describe "rake ext:pin_check" do
  def run_pin_check(env = {})
    Open3.capture2e(env, "bundle", "exec", "rake", "ext:pin_check")
  end

  def pinned_rev
    lock = File.read(File.expand_path("../../Cargo.lock", __dir__))
    lock.match(/^name = "kotoshu"$.*?^source = "git\+[^"]*#([0-9a-f]+)"/m)&.captures&.first
  end

  it "passes when the pin matches KOTOSHU_RS_HEAD" do
    rev = pinned_rev
    skip "Cargo.lock carries no kotoshu git pin" if rev.nil?

    out, status = run_pin_check("KOTOSHU_RS_HEAD" => rev)
    expect(status).to be_success
    expect(out).to include("pinned at main")
  end

  it "fails with the ext:update recipe when the pin is behind" do
    rev = pinned_rev
    skip "Cargo.lock carries no kotoshu git pin" if rev.nil?

    out, status = run_pin_check("KOTOSHU_RS_HEAD" => "e" * 40)
    expect(status).not_to be_success
    expect(out).to include("rake ext:update")
    expect(out).to include(rev[0, 10])
  end

  it "fails honestly when KOTOSHU_RS_HEAD is absent" do
    out, status = run_pin_check
    expect(status).not_to be_success
    expect(out).to include("KOTOSHU_RS_HEAD")
  end
end
