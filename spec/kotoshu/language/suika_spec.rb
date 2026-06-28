# frozen_string_literal: true

require "shellwords"

RSpec.describe Kotoshu::Language::Suika do
  describe "::LOADED" do
    it "is a boolean" do
      expect([true, false]).to include(described_class::LOADED)
    end

    it "is true when suika is installed in the test environment" do
      expect(described_class::LOADED).to be true
    end
  end

  describe ".tagger" do
    it "returns a memoized Suika::Tagger instance" do
      tagger1 = described_class.tagger
      tagger2 = described_class.tagger

      expect(tagger1).to be_a(::Suika::Tagger)
      expect(tagger2).to equal(tagger1)
    end
  end

  describe "KOTOSHU_NO_SUIKA=1 opt-out" do
    let(:script) do
      <<~'RUBY'
        require "kotoshu"
        begin
          Kotoshu::Language::Suika.tagger
          puts "LOADED=#{Kotoshu::Language::Suika::LOADED.inspect} RAISED=no"
        rescue Kotoshu::SuikaUnavailable => e
          puts "LOADED=#{Kotoshu::Language::Suika::LOADED.inspect} RAISED=yes MSG=#{e.message.inspect}"
        end
      RUBY
    end

    it "forces LOADED to false and raises SuikaUnavailable" do
      output = `KOTOSHU_NO_SUIKA=1 bundle exec ruby -e #{Shellwords.escape(script)} 2>&1`
      expect(output).to match(/LOADED=false/)
      expect(output).to match(/RAISED=yes/)
      expect(output).to include("suika gem not loaded")
      expect(output).to include("gem install suika")
    end
  end
end

RSpec.describe Kotoshu::SuikaUnavailable do
  it "is a Kotoshu::Error" do
      expect(described_class.ancestors).to include(Kotoshu::Error)
  end

  it "explains how to install the gem" do
    error = described_class.new
    expect(error.message).to include("suika gem not loaded")
    expect(error.message).to include("gem install suika")
  end

  it "includes the optional detail when provided" do
    error = described_class.new("tokenize failed")
    expect(error.message).to include("(tokenize failed)")
  end
end
