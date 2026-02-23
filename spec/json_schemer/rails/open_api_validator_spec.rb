# frozen_string_literal: true

RSpec.describe JSONSchemer::Rails::OpenApiValidator do
  subject(:validator) do
    described_class.new(request, open_api_filename:)
  end

  let(:open_api_filename) { File.expand_path("../../fixtures/openapi.yml", __dir__) }
  let(:request) { double("Request", params: params_hash) }
  let(:params_hash) { {} }

  describe "#validate_body" do
    context "when the request method is GET" do
      before do
        allow(request).to receive(:method).and_return("GET")
      end

      it "returns nil without validation" do
        expect(validator.validate_body).to be_nil
      end

      it "does not check content type" do
        allow(request).to receive(:content_type)
        validator.validate_body
        expect(request).not_to have_received(:content_type)
      end
    end

    context "when the request method is DELETE" do
      before do
        allow(request).to receive(:method).and_return("DELETE")
      end

      it "returns nil without validation" do
        expect(validator.validate_body).to be_nil
      end
    end

    context "when the request method is POST and the body is validated" do
      let(:body) { StringIO.new(body_json) }

      before do
        allow(request).to receive_messages(method: "POST", path: "/users",
                                           path_parameters: { controller: "users", action: "create" })
      end

      context "when content type is incorrect" do
        before do
          allow(request).to receive(:content_type).and_return("text/html")
        end

        it "raises a RequestValidationError" do
          expect { validator.validate_body }
            .to raise_error(
              JSONSchemer::Rails::RequestValidationError,
              '"Content-Type" request header must be set to "application/json".'
            )
        end
      end

      context "when content type is correct" do
        before do
          allow(request).to receive_messages(content_type: "application/json", body: body)
        end

        context "with valid JSON body" do
          let(:body_json) { '{"name":"John Doe","email":"john@example.com","age":30}' }

          it "validates successfully" do
            result = validator.validate_body
            expect(result.to_a).to be_empty
          end
        end

        context "with missing required field" do
          let(:body_json) { '{"name":"John Doe"}' }

          it "returns validation errors" do
            result = validator.validate_body
            errors = result.to_a
            expect(errors).not_to be_empty
            expect(errors.first["type"]).to eq("required")
          end
        end

        context "with invalid field type" do
          let(:body_json) { '{"name":"John Doe","email":"john@example.com","age":"not a number"}' }

          it "returns validation errors" do
            result = validator.validate_body
            errors = result.to_a
            expect(errors).not_to be_empty
            expect(errors.first).to have_key("error")
          end
        end

        context "with invalid email format" do
          let(:body_json) { '{"name":"John Doe","email":"invalid-email","age":30}' }

          it "returns validation errors" do
            result = validator.validate_body
            errors = result.to_a
            expect(errors).not_to be_empty
          end
        end
      end
    end

    context "when content type is not validated" do
      before do
        allow(request).to receive_messages(method: "POST", path: "/workflows",
                                           path_parameters: { controller: "users", action: "create" })
      end

      it "validates successfully" do
        result = validator.validate_body
        expect(result.to_a).to be_empty
      end
    end

    context "when using a PUT request" do
      let(:body_json) { '{"name":"Jane Doe","email":"jane@example.com"}' }
      let(:body) { StringIO.new(body_json) }

      before do
        allow(request).to receive_messages(method: "PUT", path: "/users/123",
                                           path_parameters: { controller: "users", action: "update", id: "123" }, content_type: "application/json", body: body)
      end

      it "validates the request body" do
        result = validator.validate_body
        expect(result.to_a).to be_empty
      end
    end
  end

  describe "#validated_params" do
    context "with query parameters" do
      before do
        allow(request).to receive_messages(method: "POST", path: "/users",
                                           path_parameters: { controller: "users", action: "create" })
      end

      context "when parameters are boolean type" do
        let(:params_hash) { { "notify" => "true", "source" => "web" } }

        before do
          allow(request).to receive(:query_parameters).and_return(params_hash)
          allow(params_hash).to receive(:[]=)
        end

        it "casts boolean string to boolean" do
          validator.validated_params
          expect(params_hash).to have_received(:[]=).with("notify", true)
          expect(params_hash).to have_received(:[]=).with("source", "web")
        end
      end

      context "when parameters are string type" do
        let(:params_hash) { { "source" => "mobile" } }

        before do
          allow(request).to receive(:query_parameters).and_return(params_hash)
          allow(params_hash).to receive(:[]=)
        end

        it "keeps string parameters as strings" do
          validator.validated_params
          expect(params_hash).to have_received(:[]=).with("source", "mobile")
        end
      end

      context "when boolean value is false" do
        let(:params_hash) { { "notify" => "false" } }

        before do
          allow(request).to receive(:query_parameters).and_return(params_hash)
          allow(params_hash).to receive(:[]=)
        end

        it "casts 'false' string to false boolean" do
          validator.validated_params
          expect(params_hash).to have_received(:[]=).with("notify", false)
        end
      end

      context "when boolean value is '0'" do
        let(:params_hash) { { "notify" => "0" } }

        before do
          allow(request).to receive(:query_parameters).and_return(params_hash)
          allow(params_hash).to receive(:[]=)
        end

        it "casts '0' string to false boolean" do
          validator.validated_params
          expect(params_hash).to have_received(:[]=).with("notify", false)
        end
      end

      context "when boolean value is '1'" do
        let(:params_hash) { { "notify" => "1" } }

        before do
          allow(request).to receive(:query_parameters).and_return(params_hash)
          allow(params_hash).to receive(:[]=)
        end

        it "casts '1' string to true boolean" do
          validator.validated_params
          expect(params_hash).to have_received(:[]=).with("notify", true)
        end
      end

      context "when query parameter is not in the spec" do
        let(:params_hash) { { "unknown_param" => "value" } }

        before do
          allow(request).to receive(:query_parameters).and_return(params_hash)
          allow(params_hash).to receive(:[]=)
        end

        it "does not process unknown parameters" do
          validator.validated_params
          expect(params_hash).not_to have_received(:[]=)
        end
      end

      context "when query parameter is nil" do
        let(:params_hash) { { "notify" => nil } }

        before do
          allow(request).to receive(:query_parameters).and_return(params_hash)
          allow(params_hash).to receive(:[]=)
        end

        it "does not process nil parameters" do
          validator.validated_params
          expect(params_hash).not_to have_received(:[]=)
        end
      end
    end

    context "with path parameters" do
      before do
        allow(request).to receive_messages(method: "GET", query_parameters: {})
      end

      context "when path parameter has $ref and matches schema" do
        let(:path_params) { { controller: "users", action: "show", id: "123" } }
        let(:params_hash) { { "id" => "123" } }

        before do
          allow(request).to receive_messages(path: "/users/123", path_parameters: path_params)
          allow(params_hash).to receive(:[]=)
        end

        it "validates and sets the path parameter" do
          validator.validated_params
          expect(params_hash).to have_received(:[]=).with("id", "123")
        end
      end

      context "when path parameter does not match pattern" do
        let(:path_params) { { controller: "users", action: "show", id: "abc" } }
        let(:params_hash) { { "id" => "abc" } }

        before do
          allow(request).to receive_messages(path: "/users/abc", path_parameters: path_params)
        end

        it "raises a RequestValidationError" do
          expect { validator.validated_params }
            .to raise_error(JSONSchemer::Rails::RequestValidationError)
        end
      end

      context "when path parameter has simple type and matches schema" do
        let(:path_params) { { controller: "workflows", action: "show", id: "123" } }
        let(:params_hash) { { "id" => "123" } }

        before do
          allow(request).to receive_messages(path: "/workflows/123", path_parameters: path_params)
          allow(params_hash).to receive(:[]=)
        end

        it "validates and sets the path parameter" do
          validator.validated_params
          expect(params_hash).to have_received(:[]=).with("id", "123")
        end
      end
    end

    context "with no parameters in the spec" do
      before do
        allow(request).to receive_messages(method: "POST", path: "/users",
                                           path_parameters: { controller: "users", action: "create" }, query_parameters: {})
      end

      it "completes without error when parameters array is missing" do
        expect { validator.validated_params }.not_to raise_error
      end
    end

    context "with no spec" do
      before do
        allow(request).to receive_messages(method: "HEAD", path: "/users",
                                           path_parameters: { controller: "users", action: "create" }, query_parameters: {})
      end

      it "completes with an error when method isn't found" do
        expect { validator.validated_params }.to raise_error JSONSchemer::Rails::RequestValidationError
      end
    end

    context "with mixed query and path parameters" do
      let(:query_params) { { "limit" => "10" } }
      let(:params_hash) { { "limit" => "10" } }

      before do
        allow(request).to receive_messages(method: "GET", path: "/users",
                                           path_parameters: { controller: "users", action: "index" }, query_parameters: query_params)
        allow(params_hash).to receive(:[]=)
      end

      it "validates query parameters" do
        validator.validated_params
        expect(params_hash).to have_received(:[]=).with("limit", "10")
      end
    end
  end

  describe "integration between validate_body and validated_params" do
    let(:body) { StringIO.new('{"name":"Test User","email":"test@example.com"}') }
    let(:params_hash) { { "notify" => "true" } }

    before do
      allow(request).to receive_messages(method: "POST", path: "/users",
                                         path_parameters: { controller: "users", action: "create" }, content_type: "application/json", body: body, query_parameters: params_hash)
      allow(params_hash).to receive(:[]=)
    end

    it "can validate both body and parameters for the same request" do
      expect(validator.validate_body.to_a).to be_empty
      validator.validated_params
      expect(params_hash).to have_received(:[]=).with("notify", true)
    end
  end

  describe "edge cases" do
    context "when OpenAPI file does not exist" do
      subject(:invalid_validator) do
        described_class.new(request).tap do |v|
          v.instance_variable_set(:@openapi_filename, "nonexistent.yml")
        end
      end

      it "raises an error when trying to load the schema" do
        allow(request).to receive_messages(method: "POST", path: "/users",
                                           path_parameters: { controller: "users", action: "create" }, content_type: "application/json")
        expect { invalid_validator.validate_body }.to raise_error(Errno::ENOENT)
      end
    end

    context "with empty request body" do
      let(:body) { StringIO.new("") }

      before do
        allow(request).to receive_messages(method: "POST", path: "/users",
                                           path_parameters: { controller: "users", action: "create" }, content_type: "application/json", body: body)
      end

      it "raises a JSON parse error" do
        expect { validator.validate_body }.to raise_error(JSON::ParserError)
      end
    end

    context "with malformed JSON in request body" do
      let(:body) { StringIO.new("{invalid json}") }

      before do
        allow(request).to receive_messages(method: "POST", path: "/users",
                                           path_parameters: { controller: "users", action: "create" }, content_type: "application/json", body: body)
      end

      it "raises a JSON parse error" do
        expect { validator.validate_body }.to raise_error(JSON::ParserError)
      end
    end
  end

  context "with valid JSON body and a ref_resolver" do
    subject(:validator) do
      described_class.new(request, open_api_filename:, ref_resolver:)
    end

    before do
      allow(request).to receive_messages(method: "POST", path: "/frogs",
                                         path_parameters: { controller: "users", action: "create" },
                                         content_type: "application/json", body:)
    end

    let(:body) { StringIO.new(body_json) }

    let(:ref_resolver) do
      instance_double(Proc, call: {
                        "components" => {
                          "schemas" => {
                            "frog" => {
                              "type" => "object",
                              "properties" => { "name" => { "type" => "string" }, "age" => { "type" => "integer" } }
                            }
                          }
                        }
                      })
    end

    let(:body_json) { '{"name":"Kermit","age":63}' }

    it "validates successfully" do
      result = validator.validate_body
      expect(result.to_a).to be_empty
    end
  end
end
