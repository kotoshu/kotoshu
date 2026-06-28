# frozen_string_literal: true

require_relative "../../../lib/kotoshu/results/result"

RSpec.describe Kotoshu::Results::Result do
  describe "::Success" do
    let(:result) { described_class::Success.new("value") }

    it "is successful" do
      expect(result).to be_success
      expect(result).not_to be_failure
    end

    it "returns the wrapped value" do
      expect(result.value).to eq("value")
    end

    it "supports map" do
      mapped = result.map(&:upcase)
      expect(mapped.value).to eq("VALUE")
    end

    it "supports and_then" do
      chained = result.and_then { |v| described_class::Success.new("#{v}!") }
      expect(chained.value).to eq("value!")
    end

    it "does not call or_else" do
      called = false
      result.or_else do
        called = true
        "fallback"
      end
      expect(called).to be false
    end

    it "can be unwrapped" do
      expect(result.unwrap).to eq("value")
    end

    it "returns nil for error" do
      expect(result.error).to be_nil
    end
  end

  describe "::Failure" do
    let(:error) { StandardError.new("something went wrong") }
    let(:result) { described_class::Failure.new(error) }

    it "is a failure" do
      expect(result).to be_failure
      expect(result).not_to be_success
    end

    it "returns the wrapped error" do
      expect(result.error).to eq(error)
    end

    it "does not call map" do
      mapped = result.map(&:upcase)
      expect(mapped).to be_failure
    end

    it "does not call and_then" do
      chained = result.and_then { |_v| described_class::Success.new("ignored") }
      expect(chained).to be_failure
    end

    it "supports or_else" do
      recovered = result.or_else { |_e| described_class::Success.new("recovered") }
      expect(recovered).to be_success
      expect(recovered.value).to eq("recovered")
    end

    it "raises error on unwrap" do
      expect { result.unwrap }.to raise_error(error.class)
    end

    it "returns nil for value" do
      expect(result.value).to be_nil
    end
  end

  describe "pattern matching" do
    it "supports case-like pattern matching" do
      success = described_class::Success.new("value")

      result = case success
               when described_class::Success
                 success.value
               when described_class::Failure
                 "error"
               end

      expect(result).to eq("value")
    end
  end

  describe "composable operations" do
    it "chains multiple operations" do
      result = described_class::Success.new(5)
        .and_then { |v| described_class::Success.new(v * 2) }
        .and_then { |v| described_class::Success.new(v + 1) }

      expect(result.value).to eq(11)
    end

    it "short-circuits on first failure" do
      result = described_class::Success.new(5)
        .and_then { |_v| described_class::Failure.new(StandardError.new("fail")) }
        .and_then { |_v| described_class::Success.new("never reached") }

      expect(result).to be_failure
    end

    it "recovers from failure" do
      result = described_class::Failure.new(StandardError.new("fail"))
        .or_else { described_class::Success.new("recovered") }
        .map(&:upcase)

      expect(result.value).to eq("RECOVERED")
    end
  end
end
