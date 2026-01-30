# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/examples/"
  # minimum_coverage 80 # TODO: Re-enable when coverage increases
end

require "webmock/rspec"
require "vcr"

require "kotoshu"

# Configure VCR for recording and replaying HTTP requests
VCR.configure do |c|
  c.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  c.hook_into :webmock
  c.configure_rspec_metadata!
  c.default_cassette_options = {
    record: :once,  # Record once, then replay
    match_requests_on: [:method, :host, :path]
  }
  # Allow recording new cassettes when VCR_RECORD=true
  c.allow_http_connections_when_no_cassette = ENV.fetch("VCR_RECORD", nil) ? true : false
end

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

  # Skip network tests by default (they depend on external resources)
  # Run with: NETWORK_TESTS=1 bundle exec rspec
  config.filter_run_excluding :network unless ENV.fetch("NETWORK_TESTS", nil)

  # For VCR tests, allow them to run by default (they use recorded cassettes)
  # Only skip if explicitly excluding :vcr
end
