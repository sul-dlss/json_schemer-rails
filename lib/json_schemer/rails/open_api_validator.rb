# frozen_string_literal: true

require "cgi"
require "yaml"
require "json_schemer"

module JsonSchemer
  module Rails
    # This validates a request against the OpenAPI specification
    class OpenApiValidator
      def initialize(request, open_api_filename: "openapi.yml")
        @request = request
        @open_api_filename = open_api_filename
      end

      attr_reader :request

      def validate_body
        return if %w[delete get].include?(request.method.downcase) # no body to verify

        unless request.content_type == "application/json"
          raise RequestValidationError,
                '"Content-Type" request header must be set to "application/json".'
        end

        document.ref("#{request_openapi_path}/requestBody/content/application~1json/schema")
                .validate(JSON.parse(request.body.read))
      end

      # cast any parameters that are not part of the OpenAPI specification
      def validated_params
        param_specs = document.ref(request_openapi_path).value["parameters"] || []

        param_specs.each do |spec|
          case spec["in"]
          when "query"
            validate_query_param(spec)
          when "path"
            validate_path_param(spec)
          end
        end
      end

      private

      def document
        @document ||= JSONSchemer.openapi(open_api_struct)
      end

      def open_api_struct
        @open_api_struct ||= load_openapi_file
      end

      def load_openapi_file
        YAML.load_file(open_api_filename)
      end

      attr_reader :open_api_filename

      def open_api_filename=(val)
        @open_api_struct = nil
        @document = nil
        @open_api_filename = val
      end

      def validate_query_param(spec)
        result = request.query_parameters[spec["name"]]
        return unless result

        request.params[spec["name"]] &&= case spec.dig("schema", "type")
                                         when "boolean"
                                           ActiveModel::Type::Boolean.new.cast(result)
                                         else
                                           result
                                         end
      end

      def validate_path_param(spec) # rubocop:disable Metrics/AbcSize
        result = request.path_parameters[spec["name"].to_sym]
        ref = spec.dig("schema", "$ref")
        errors = document.ref(ref).validate(result).to_a
        raise RequestValidationError, errors.join(", ") unless errors.empty?

        request.params[spec["name"]] = result
      end

      def request_openapi_path
        verb = request.method.downcase
        path = json_ref_for_path
        "#/paths/#{path}/#{verb}"
      end

      def json_ref_for_path
        params = request.path_parameters.except(:controller, :action)
        path = CGI.unescape(request.path).tr(" ", "+")
        %i[object_id id].each do |parameter|
          path.gsub!(params[parameter], "%7B#{parameter}%7D") if params[parameter]
        end
        path.gsub("/", "~1")
      end
    end
  end
end
