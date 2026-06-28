# frozen_string_literal: true

require "open3"

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

      expect(tagger1).to be_a(Suika::Tagger)
      expect(tagger2).to equal(tagger1)
    end
  end

  describe "KOTOSHU_NO_SUIKA=1 opt-out" do
    let(:script) do
      <<~'RUBY'
        ENV["KOTOSHU_NO_SUIKA"] = "1"
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
      # Gem.ruby -S bundle handles Windows where bundle is bundle.bat
      output, status = Open3.capture2e(Gem.ruby, "-S", "bundle", "exec", "ruby", "-e", script)
      skip "Bundle exec unavailable in this environment" unless status.success? || output =~ /LOADED=/

      expect(output).to include('LOADED=false')
      expect(output).to include('RAISED=yes')
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
