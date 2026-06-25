# frozen_string_literal: true

require_relative "../../../lib/kotoshu/configuration/resolver"

RSpec.describe Kotoshu::Configuration::Resolver do
  describe "#initialize" do
    it "creates a resolver with default empty values" do
      resolver = described_class.new

      expect(resolver.env).to eq({})
      expect(resolver.programmatic).to eq({})
      expect(resolver.cli).to eq({})
      expect(resolver.defaults).to eq({})
    end

    it "creates a resolver with provided values" do
      resolver = described_class.new(
        env: { "KOTOSHU_LANGUAGE" => "de" },
        programmatic: { language: "en-US" },
        cli: { language: "ja" },
        defaults: { language: "en-US" }
      )

      expect(resolver.env).to eq({ "KOTOSHU_LANGUAGE" => "de" })
      expect(resolver.programmatic).to eq({ language: "en-US" })
      expect(resolver.cli).to eq({ language: "ja" })
      expect(resolver.defaults).to eq({ language: "en-US" })
    end
  end

  describe "#get" do
    context "with all priority levels set" do
      let(:resolver) do
        described_class.new(
          env: { "KOTOSHU_LANGUAGE" => "de" },
          programmatic: { language: "en-US" },
          cli: { language: "ja" },
          defaults: { language: "en-US" }
        )
      end

      it "returns CLI value when set (highest priority)" do
        expect(resolver.get(:language)).to eq("ja")
      end
    end

    context "without CLI value" do
      let(:resolver) do
        described_class.new(
          env: { "KOTOSHU_LANGUAGE" => "de" },
          programmatic: { language: "en-US" },
          cli: {},
          defaults: { language: "en-US" }
        )
      end

      it "returns ENV value when CLI not set" do
        # Set ENV for this test
        old_env = ENV["KOTOSHU_LANGUAGE"]
        ENV["KOTOSHU_LANGUAGE"] = "de"

        begin
          expect(resolver.get(:language)).to eq("de")
        ensure
          ENV["KOTOSHU_LANGUAGE"] = old_env
        end
      end
    end

    context "without CLI and ENV values" do
      let(:resolver) do
        described_class.new(
          env: {},
          programmatic: { language: "en-GB" },
          cli: {},
          defaults: { language: "en-US" }
        )
      end

      it "returns programmatic value when CLI and ENV not set" do
        # Clear ENV for this test
        old_env = ENV["KOTOSHU_LANGUAGE"]
        ENV.delete("KOTOSHU_LANGUAGE") if ENV.key?("KOTOSHU_LANGUAGE")

        begin
          expect(resolver.get(:language)).to eq("en-GB")
        ensure
          ENV["KOTOSHU_LANGUAGE"] = old_env
        end
      end
    end

    context "with only defaults" do
      let(:resolver) do
        described_class.new(
          env: {},
          programmatic: {},
          cli: {},
          defaults: { language: "en-US" }
        )
      end

      it "returns default value when nothing else set" do
        # Clear ENV for this test
        old_env = ENV["KOTOSHU_LANGUAGE"]
        ENV.delete("KOTOSHU_LANGUAGE") if ENV.key?("KOTOSHU_LANGUAGE")

        begin
          expect(resolver.get(:language)).to eq("en-US")
        ensure
          ENV["KOTOSHU_LANGUAGE"] = old_env
        end
      end
    end

    context "with unknown key" do
      let(:resolver) do
        described_class.new(
          env: {},
          programmatic: {},
          cli: {},
          defaults: {}
        )
      end

      it "returns nil when key not found anywhere" do
        expect(resolver.get(:unknown_key)).to be_nil
      end
    end
  end

  describe "#key?" do
    let(:resolver) do
      described_class.new(
        env: {},
        programmatic: { language: "en-US" },
        cli: {},
        defaults: { max_suggestions: 10 }
      )
    end

    it "returns true for keys in programmatic settings" do
      expect(resolver.key?(:language)).to be true
    end

    it "returns true for keys in defaults" do
      expect(resolver.key?(:max_suggestions)).to be true
    end

    it "returns false for unknown keys" do
      expect(resolver.key?(:unknown_key)).to be false
    end

    it "returns true for keys in ENV" do
      old_env = ENV["KOTOSHU_VERBOSE"]
      ENV["KOTOSHU_VERBOSE"] = "true"

      begin
        expect(resolver.key?(:verbose)).to be true
      ensure
        ENV["KOTOSHU_VERBOSE"] = old_env
      end
    end

    it "returns true for keys in CLI" do
      resolver_with_cli = described_class.new(
        env: {},
        programmatic: {},
        cli: { language: "ja" },
        defaults: {}
      )

      expect(resolver_with_cli.key?(:language)).to be true
    end
  end

  describe "#get_all" do
    let(:resolver) do
      old_env = ENV["KOTOSHU_LANGUAGE"]
      ENV["KOTOSHU_LANGUAGE"] = "de"

      described_class.new(
        env: {},
        programmatic: { language: "en-US", max_suggestions: 15 },
        cli: { language: "ja" },
        defaults: { max_suggestions: 10 }
      )
    end

    after do
      ENV["KOTOSHU_LANGUAGE"] = nil
    end

    it "returns all priority levels for a key" do
      all = resolver.get_all(:language)

      expect(all).to eq({
        cli: "ja",
        env: "de",
        programmatic: "en-US",
        default: nil
      })
    end

    it "returns all priority levels for another key" do
      all = resolver.get_all(:max_suggestions)

      expect(all).to eq({
        cli: nil,
        env: nil,
        programmatic: 15,
        default: 10
      })
    end
  end

  describe "#merge" do
    let(:resolver) do
      described_class.new(
        env: { "KOTOSHU_LANGUAGE" => "de" },
        programmatic: { language: "en-US", max_suggestions: 15 },
        cli: {},
        defaults: { max_suggestions: 10 }
      )
    end

    it "creates a new resolver with merged values" do
      merged = resolver.merge(
        programmatic: { max_suggestions: 20 },
        cli: { language: "ja" }
      )

      expect(merged.env).to eq({ "KOTOSHU_LANGUAGE" => "de" })
      expect(merged.programmatic).to eq({ language: "en-US", max_suggestions: 20 })
      expect(merged.cli).to eq({ language: "ja" })
      expect(merged.defaults).to eq({ max_suggestions: 10 })
    end

    it "does not modify the original resolver" do
      merged = resolver.merge(programmatic: { max_suggestions: 20 })

      expect(resolver.programmatic[:max_suggestions]).to eq(15)
      expect(merged.programmatic[:max_suggestions]).to eq(20)
    end
  end

  describe "env_key_for" do
    let(:resolver) { described_class.new }

    it "converts configuration keys to ENV variable names" do
      expect(resolver.send(:env_key_for, :language)).to eq("KOTOSHU_LANGUAGE")
      expect(resolver.send(:env_key_for, :cache_path)).to eq("KOTOSHU_CACHE_PATH")
      expect(resolver.send(:env_key_for, :max_suggestions)).to eq("KOTOSHU_MAX_SUGGESTIONS")
    end
  end
end
