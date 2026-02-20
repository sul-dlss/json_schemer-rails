# frozen_string_literal: true

require "json_schemer/rails"
require "json_schemer/rails/open_api_validator"
require "json_schemer/rails/validation_error"
require "active_model"
require "action_dispatch"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
