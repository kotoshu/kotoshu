# frozen_string_literal: true

require "spec_helper"
require "open3"
require "tmpdir"

# `kotoshu check` and the personal dictionary (plan 105), end to end:
# a word added to personal.dic passes the check, and --no-personal
# opts back in to flagging it. Drives the real exe in a temp XDG home
# so the developer's real personal dictionary is never touched.
RSpec.describe "kotoshu check with the personal dictionary", :network do
  let(:ruby) { Gem.ruby }
  let(:exe) { File.expand_path("exe/kotoshu", Dir.pwd) }

  around do |ex|
    original = ENV.select { |key, _| key.start_with?("XDG_") || key == "KOTOSHU_PERSONAL_DIC" }
    Dir.mktmpdir do |dir|
      ENV["XDG_CACHE_HOME"] = "#{dir}/cache"
      ENV["XDG_CONFIG_HOME"] = "#{dir}/config"
      ENV["XDG_DATA_HOME"] = "#{dir}/local"
      # Per-example dictionary: earlier examples in this file add words,
      # and the empty-dictionary example must not see them.
      ENV["KOTOSHU_PERSONAL_DIC"] = File.join(dir, "personal.dic")
      Kotoshu::Configuration.reset
      Kotoshu.reset_spellchecker
      Kotoshu.setup(:en, want: %i[spelling])
      @temp_file = File.join(dir, "input.txt")
      File.write(@temp_file, "wrold\n")
      ex.run
    end
  ensure
    keys = original.keys
    (ENV.keys - keys).each do |key|
      ENV.delete(key) if key.start_with?("XDG_") || key == "KOTOSHU_PERSONAL_DIC"
    end
    original.each { |key, value| ENV[key] = value }
    Kotoshu::Configuration.reset
    Kotoshu.reset_spellchecker
  end

  def run_cli(*args)
    env = {
      "XDG_CACHE_HOME" => ENV.fetch("XDG_CACHE_HOME"),
      "XDG_CONFIG_HOME" => ENV.fetch("XDG_CONFIG_HOME"),
      "XDG_DATA_HOME" => ENV.fetch("XDG_DATA_HOME"),
      # The suite pins KOTOSHU_PERSONAL_DIC (hermeticity, see
      # spec_helper); repoint the child at this spec's temp dictionary.
      "KOTOSHU_PERSONAL_DIC" => Kotoshu::PersonalDictionary.file_path
    }
    stdout, status = Open3.capture2e(env, ruby, "-S", "bundle", "exec", exe, "check", *args)
    [stdout, status]
  end

  it "passes a word that is in the personal dictionary" do
    Kotoshu::PersonalDictionary.add_word("wrold")

    output, status = run_cli("--language", "en", @temp_file)

    expect(output).to include("no errors")
    expect(status.exitstatus).to eq(0)
  end

  it "flags the word again with --no-personal" do
    Kotoshu::PersonalDictionary.add_word("wrold")

    output, status = run_cli("--language", "en", "--no-personal", @temp_file)

    expect(output).to include("wrold")
    expect(status.exitstatus).to eq(1)
  end

  it "flags the word when the personal dictionary is empty" do
    output, status = run_cli("--language", "en", @temp_file)

    expect(output).to include("wrold")
    expect(status.exitstatus).to eq(1)
  end
end
