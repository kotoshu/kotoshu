# frozen_string_literal: true

require "spec_helper"
require "rake"
require "fileutils"
require "tmpdir"
require "kotoshu/tasks/check_task"

# Rake task specs (plan 89, item 3): a real CheckTask on a real
# Rake application against a real tmpdir tree.
RSpec.describe Kotoshu::Tasks::CheckTask do
  EN_AFF = File.expand_path("../../integrational/fixtures/en_US.aff", __dir__)
  EN_DIC = File.expand_path("../../integrational/fixtures/en_US.dic", __dir__)

  before(:all) do
    skip "en_US fixtures missing" unless File.exist?(EN_AFF) && File.exist?(EN_DIC)
  end

  around do |example|
    Dir.mktmpdir do |dir|
      @root = dir
      @cache = File.join(dir, "cache")
      @old_env = %w[KOTOSHU_CACHE_PATH XDG_CONFIG_HOME XDG_DATA_HOME].to_h { |k| [k, ENV.fetch(k, nil)] }
      populate_en_cache
      ENV["KOTOSHU_CACHE_PATH"] = @cache
      ENV["XDG_CONFIG_HOME"] = File.join(dir, "config")
      ENV["XDG_DATA_HOME"] = File.join(dir, "local")
      Kotoshu::Configuration.reset
      Kotoshu.reset_spellchecker
      @app = Rake::Application.new
      Rake.application = @app
      example.run
      Rake.application = nil
      Kotoshu::Configuration.reset
      Kotoshu.reset_spellchecker
      @old_env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    end
  end

  def populate_en_cache
    dir = File.join(@cache, "languages", "en", "spelling")
    FileUtils.mkdir_p(dir)
    FileUtils.cp(EN_AFF, File.join(dir, "index.aff"))
    FileUtils.cp(EN_DIC, File.join(dir, "index.dic"))
    File.write(File.join(dir, "metadata.json"), {
      "language" => "en",
      "type" => "spelling",
      "version" => "2026-01-01T00:00:00Z",
      "cached_at" => Time.now.utc.iso8601,
      "source" => "fixture"
    }.to_json)
  end

  def write(relative, content = "hello world\n")
    path = File.join(@root, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
    path
  end

  # Invoke kotoshu:check and return the process status (0 when no
  # SystemExit was raised, the exit code when the task aborted).
  def invoke_status
    Rake::Task["kotoshu:check"].invoke
    0
  rescue SystemExit => e
    e.status
  end

  it "defines kotoshu:check when kotoshu/tasks is required" do
    require "kotoshu/tasks"

    task_names = Rake::Task.tasks.map(&:to_s)
    expect(task_names).to include("kotoshu:check")
  end

  it "uses the plan-88 file selection over the root" do
    write("docs/clean.md")
    write("docs/skipped.rb")

    task = described_class.new { |t| t.root = @root }
    expect(task.target_files).to eq([File.join(@root, "docs", "clean.md")])
  end

  it "prints errors and aborts when a file has misspellings" do
    write("dirty.md", "wrold\n")

    described_class.new { |t| t.root = @root }

    output = capture_output do
      @status = invoke_status
    end
    expect(@status).to eq(1)
    expect(output).to include("wrold")
    expect(output).to include("1 file(s) checked, 1 error(s)")
  end

  it "succeeds quietly for clean trees" do
    write("clean.md")

    described_class.new { |t| t.root = @root }

    output = capture_output do
      @status = invoke_status
    end
    expect(@status).to eq(0)
    expect(output).to include("1 file(s) checked, 0 error(s)")
  end

  it "honors an explicit file list and fail_on_error = false" do
    write("dirty.md", "wrold\n")

    described_class.new do |t|
      t.files = [File.join(@root, "dirty.md")]
      t.language = "en"
      t.fail_on_error = false
    end

    output = capture_output do
      @status = invoke_status
    end
    expect(@status).to eq(0)
    expect(output).to include("wrold")
  end

  private

  # Capture $stdout while the task runs (Rake's puts).
  def capture_output
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
