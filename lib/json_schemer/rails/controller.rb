# frozen_string_literal: true

module JsonSchemer
  module Rails
    # Mixin for controllers.
    # usage:
    #   include JsonSchemer::Rails::Controller
    #   before_action :validate_from_openapi
    module Controller
      def validate_from_openapi
        # This is going to cast any parameters to their specified types
        openapi_validator.validated_params

        errors = openapi_validator.validate_body.to_a
        raise(RequestValidationError, errors.pluck("error").join("; ")) if errors.any?
      end

      private

      def openapi_validator
        @openapi_validator ||= OpenApiValidator.new(request)
      end
    end
  end
end
