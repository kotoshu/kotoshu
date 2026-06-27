# frozen_string_literal: true

require "spec_helper"
require "kotoshu/cli/auto_setup"

module Kotoshu
  module Cli
    RSpec.describe AutoSetup do
      let(:error) { Kotoshu::ResourceNotSetupError.new("en", "spelling") }

      def build_setup(input_io:, output_io:)
        described_class.new(input: input_io, output: output_io)
      end

      describe "#call in non-TTY context" do
        it "returns nil without prompting" do
          input = StringIO.new("y\n")
          allow(input).to receive(:tty?).and_return(false)
          output = StringIO.new

          setup = build_setup(input_io: input, output_io: output)

          expect(setup.call(error)).to be_nil
          expect(output.string).to eq("")
        end
      end

      describe "#call in offline mode" do
        it "returns nil without prompting" do
          input = StringIO.new("y\n")
          allow(input).to receive(:tty?).and_return(true)
          output = StringIO.new

          allow(Kotoshu.configuration).to receive(:offline).and_return(true)

          setup = build_setup(input_io: input, output_io: output)

          expect(setup.call(error)).to be_nil
          expect(output.string).to eq("")
        end
      end

      describe "#call with TTY and user accepts" do
        it "calls Kotoshu.setup and returns the language" do
          input = StringIO.new("y\n")
          allow(input).to receive(:tty?).and_return(true)
          output = StringIO.new

          allow(Kotoshu.configuration).to receive(:offline).and_return(false)
          setup_result = Struct.new(:language, :spelling).new("en", :downloaded)
          expect(Kotoshu).to receive(:setup).with("en", want: %i[spelling]).and_return(setup_result)

          setup = build_setup(input_io: input, output_io: output)
          result = setup.call(error)

          expect(result).to eq("en")
          expect(output.string).to include("Language 'en' is not set up")
          expect(output.string).to include("[Y/n]")
        end

        it "treats empty input (just enter) as yes" do
          input = StringIO.new("\n")
          allow(input).to receive(:tty?).and_return(true)
          output = StringIO.new

          allow(Kotoshu.configuration).to receive(:offline).and_return(false)
          allow(Kotoshu).to receive(:setup).with("en", want: %i[spelling])

          setup = build_setup(input_io: input, output_io: output)
          expect(setup.call(error)).to eq("en")
        end
      end

      describe "#call with TTY and user declines" do
        it "returns nil without calling Kotoshu.setup" do
          input = StringIO.new("n\n")
          allow(input).to receive(:tty?).and_return(true)
          output = StringIO.new

          allow(Kotoshu.configuration).to receive(:offline).and_return(false)
          allow(Kotoshu).to receive(:setup)

          setup = build_setup(input_io: input, output_io: output)

          expect(setup.call(error)).to be_nil
          expect(Kotoshu).not_to have_received(:setup)
        end
      end
    end
  end
end
