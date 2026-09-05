# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"
require "kotoshu/validators/spelling_validator"

# ActiveModel EachValidator specs (plan 89, item 1). Loads the real
# ActiveModel standalone - no Rails - and skips when it is not
# installed.
RSpec.describe Kotoshu::Validators::SpellingValidator do
  unless Kotoshu::Validators::ACTIVE_MODEL_LOADED
    skip "activemodel not installed"
  end

  require "active_model"

  EN_AFF = File.expand_path("../../integrational/fixtures/en_US.aff", __dir__)
  EN_DIC = File.expand_path("../../integrational/fixtures/en_US.dic", __dir__)

  before(:all) do
    skip "en_US fixtures missing" unless File.exist?(EN_AFF) && File.exist?(EN_DIC)
    @dir = Dir.mktmpdir
    cache_dir = File.join(@dir, "cache", "languages", "en", "spelling")
    FileUtils.mkdir_p(cache_dir)
    FileUtils.cp(EN_AFF, File.join(cache_dir, "index.aff"))
    FileUtils.cp(EN_DIC, File.join(cache_dir, "index.dic"))
    File.write(File.join(cache_dir, "metadata.json"), {
      "language" => "en",
      "type" => "spelling",
      "version" => "2026-01-01T00:00:00Z",
      "cached_at" => Time.now.utc.iso8601,
      "source" => "fixture"
    }.to_json)
    @old_env = %w[KOTOSHU_CACHE_PATH XDG_CONFIG_HOME XDG_DATA_HOME].to_h { |k| [k, ENV.fetch(k, nil)] }
    ENV["KOTOSHU_CACHE_PATH"] = File.join(@dir, "cache")
    ENV["XDG_CONFIG_HOME"] = File.join(@dir, "config")
    ENV["XDG_DATA_HOME"] = File.join(@dir, "local")
    Kotoshu::Configuration.reset
    Kotoshu.reset_spellchecker

    unless defined?(SpellingValidator)
      SpellingValidator = Kotoshu::Validators::SpellingValidator
    end
    SpellcheckedModel = Class.new do
      include ActiveModel::Model
      include ActiveModel::Validations

      attr_accessor :body

      validates :body, spelling: { language: "en" }
    end
  end

  # One isolated cache for the whole group: loading the dictionary
  # once keeps the group fast.

  after(:all) do
    Kotoshu::Configuration.reset
    Kotoshu.reset_spellchecker
    @old_env&.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    FileUtils.remove_entry(@dir) if @dir
  end

  # A real ActiveModel model using the documented short-syntax wiring:
  # the top-level alias is exactly what a Rails initializer would set.
  # Defined once and left in place, like a real initializer would.

  def model(body)
    SpellcheckedModel.new(body: body)
  end

  it "is an ActiveModel::EachValidator" do
    expect(described_class.superclass).to eq(ActiveModel::EachValidator)
  end

  it "accepts clean text" do
    expect(model("hello world")).to be_valid
  end

  it "rejects misspelled text with one error per misspelling" do
    record = model("helo wrold")

    expect(record).not_to be_valid
    messages = record.errors[:body]
    expect(messages.length).to eq(2)
    expect(messages.join("\n")).to include("helo").and include("wrold")
  end

  it "includes the top suggestion in the message" do
    record = model("wrold")

    record.validate
    expect(record.errors[:body].first).to include("'wrold' is misspelled")
    details = record.errors.details[:body].first
    expect(details[:word]).to eq("wrold")
    expect(details[:suggestions]).to be_an(Array)
  end

  it "accepts personal words" do
    klass = Class.new do
      include ActiveModel::Model
      include ActiveModel::Validations

      attr_accessor :body

      validates :body, spelling: { language: "en", personal_words: %w[kotoshu] }
    end

    expect(klass.new(body: "kotoshu is nice")).to be_valid
    expect(klass.new(body: "kotoshu and helo")).not_to be_valid
  end

  it "works via validates_with without the alias" do
    klass = Class.new do
      include ActiveModel::Model
      include ActiveModel::Validations

      attr_accessor :body

      validates_with Kotoshu::Validators::SpellingValidator,
                     attributes: [:body], language: "en"
    end

    expect(klass.new(body: "helo")).not_to be_valid
    expect(klass.new(body: "hello")).to be_valid
  end
end
