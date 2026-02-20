# frozen_string_literal: true

module JsonSchemer
  module Rails
    # Raised when the OpenAPI specification is violated
    class RequestValidationError < StandardError; end
  end
end
