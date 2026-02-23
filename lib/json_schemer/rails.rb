# frozen_string_literal: true

require "json_schemer"
require "zeitwerk"

Zeitwerk::Loader.for_gem_extension(JSONSchemer).setup

module JSONSchemer
  module Rails
    class Error < StandardError; end
    # Your code goes here...
  end
end
