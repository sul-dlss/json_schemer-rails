# frozen_string_literal: true

require_relative "lib/json_schemer/rails/version"

Gem::Specification.new do |spec|
  spec.name = "json_schemer-rails"
  spec.version = JsonSchemer::Rails::VERSION
  spec.authors = ["Justin Coyne"]
  spec.email = ["jcoyne@justincoyne.com"]

  spec.description = "Rails integration for JsonSchemer. Validates OpenAPI"
  spec.summary = "Rails integration for JsonSchemer. Validates OpenAPI"
  spec.homepage = "https://github.com/sul-dlss/json_schemer-rails"
  spec.required_ruby_version = ">= 3.4.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/sul-dlss/json_schemer-rails"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "json_schemer", "~> 2.5"
  spec.add_dependency "railties", "~> 8.0"
end
