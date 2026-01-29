# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/examples/"
  # minimum_coverage 80 # TODO: Re-enable when coverage increases
end

require "kotoshu"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Run specs in random order to surface order dependencies
  config.order = :random

  # Seed global randomizer in this process using the `--seed` option.
  # This allows you to rerun failed specs with the same seed
  Kernel.srand config.seed

  # Allow focusing on specific tests
  # config.filter_run_when_focusing = true

  # Run all tests when not focusing
  config.run_all_when_everything_filtered = true

  # Enable verifying doubled instance method names
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
    mocks.verify_doubled_constant_names = true
  end
end
