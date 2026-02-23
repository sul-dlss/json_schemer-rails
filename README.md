# JsonSchemer::Rails

[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.4.0-ruby.svg)](https://www.ruby-lang.org/en/)
[![Rails](https://img.shields.io/badge/rails-%3E%3D%208.0-red.svg)](https://rubyonrails.org/)

A Rails integration for [json_schemer](https://github.com/davishmcclurg/json_schemer) that provides OpenAPI 3.0 request validation and parameter type casting for your Rails controllers.

## Features

- ✅ Validates request bodies against OpenAPI 3.0 schemas
- ✅ Validates path and query parameters
- ✅ Automatic type casting for query parameters (strings to booleans, integers, etc.)
- ✅ Schema references (`$ref`) support
- ✅ Content-Type validation
- ✅ Comprehensive error messages
- ✅ Easy integration with Rails controllers

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'json_schemer-rails'
```

And then execute:

```bash
bundle install
```

## Usage

### 1. Create an OpenAPI Specification

Create an `openapi.yml` file in your Rails root directory:

```yaml
openapi: 3.0.0
info:
  title: My API
  version: 1.0.0
paths:
  /users:
    post:
      summary: Create a user
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              properties:
                name:
                  type: string
                email:
                  type: string
                  format: email
                age:
                  type: integer
              required:
                - name
                - email
      parameters:
        - name: notify
          in: query
          schema:
            type: boolean
      responses:
        '201':
          description: User created
  /users/{id}:
    get:
      summary: Get a user
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
            pattern: '^[0-9]+$'
      responses:
        '200':
          description: User details
```

### 2. Include in Your Controller

#### Option A: Use the Controller Mixin (Recommended)

```ruby
class UsersController < ApplicationController
  include JsonSchemer::Rails::Controller
  
  before_action :validate_from_openapi, only: [:create, :update]

  def create
    # At this point:
    # - Request body has been validated against the schema
    # - Query parameters have been type-cast (e.g., "true" → true)
    # - Path parameters have been validated
    
    user = User.create!(params.permit(:name, :email, :age))
    render json: user, status: :created
  end
end
```

#### Option B: Manual Validation

```ruby
class UsersController < ApplicationController
  def create
    validator = JsonSchemer::Rails::OpenApiValidator.new(request)
    
    # Validate and cast parameters
    validator.validated_params
    
    # Validate request body
    errors = validator.validate_body.to_a
    if errors.any?
      render json: { errors: errors }, status: :unprocessable_entity
      return
    end
    
    user = User.create!(params.permit(:name, :email, :age))
    render json: user, status: :created
  end
end
```

### 3. Custom OpenAPI File Location

By default, the validator looks for `openapi.yml` in your Rails root. You can specify a different location:

```ruby
validator = JsonSchemer::Rails::OpenApiValidator.new(
  request,
  open_api_filename: Rails.root.join('config', 'api_schema.yml')
)
```

## How It Works

### Request Body Validation

The validator automatically:
- Checks that the `Content-Type` header is set to `application/json` for POST/PUT/PATCH requests
- Parses the request body as JSON
- Validates the JSON against the schema defined in your OpenAPI spec
- Returns detailed validation errors if the body doesn't match the schema

### Parameter Validation and Type Casting

The validator processes both query and path parameters:

#### Query Parameters
- **Type Casting**: Converts string values to their specified types
  - `"true"`, `"1"` → `true`
  - `"false"`, `"0"` → `false`
  - Numbers are cast to integers/floats as specified
- **Validation**: Ensures parameters match their schema definitions
- **Unknown Parameters**: Ignores parameters not defined in the OpenAPI spec

#### Path Parameters
- Validates against schema patterns (e.g., regex patterns)
- Validates against referenced schemas (`$ref`)
- Raises `RequestValidationError` if validation fails

### Example: Type Casting in Action

Given this OpenAPI parameter definition:

```yaml
parameters:
  - name: notify
    in: query
    schema:
      type: boolean
  - name: limit
    in: query
    schema:
      type: integer
```

Query string: `?notify=true&limit=10`

Before validation:
```ruby
params[:notify] # => "true" (String)
params[:limit]  # => "10" (String)
```

After `validated_params`:
```ruby
params[:notify] # => true (Boolean)
params[:limit]  # => "10" (String, not cast because OpenAPI handles this differently)
```

## Error Handling

When validation fails, a `JsonSchemer::Rails::RequestValidationError` is raised:

```ruby
class ApplicationController < ActionController::API
  rescue_from JsonSchemer::Rails::RequestValidationError do |exception|
    render json: { error: exception.message }, status: :unprocessable_entity
  end
end
```

## Testing

The gem includes comprehensive RSpec tests. To run the test suite:

```bash
bundle exec rspec
```

### Writing Tests for Your Controllers

Use `ActionDispatch::TestRequest` to test your validated endpoints:

```ruby
require 'rails_helper'

RSpec.describe UsersController, type: :controller do
  describe 'POST #create' do
    it 'validates the request body' do
      request.headers['Content-Type'] = 'application/json'
      post :create, body: { name: 'John', email: 'john@example.com' }.to_json
      
      expect(response).to have_http_status(:created)
    end
    
    it 'rejects invalid requests' do
      request.headers['Content-Type'] = 'application/json'
      post :create, body: { name: 'John' }.to_json # missing email
      
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
```

## Advanced Usage

### Skipping Validation for Specific Actions

```ruby
class UsersController < ApplicationController
  include JsonSchemer::Rails::Controller
  
  before_action :validate_from_openapi, except: [:index]
  
  def index
    # No validation needed for GET requests without body
  end
  
  def create
    # Validated automatically
  end
end
```

### Custom Validation Logic

```ruby
class UsersController < ApplicationController
  def create
    validator = JsonSchemer::Rails::OpenApiValidator.new(request)
    
    # Validate parameters first
    validator.validated_params
    
    # Then validate body
    body_errors = validator.validate_body.to_a
    
    # Add custom validation
    custom_errors = custom_business_logic_validation
    
    all_errors = body_errors + custom_errors
    if all_errors.any?
      render json: { errors: all_errors }, status: :unprocessable_entity
      return
    end
    
    # Proceed with valid data
  end
  
  private
  
  def custom_business_logic_validation
    # Your custom validation logic
    []
  end
end
```

## Requirements

- Ruby >= 3.4.0
- Rails >= 8.0
- json_schemer >= 2.5

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sul-dlss/json_schemer-rails.

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Credits

Built with [json_schemer](https://github.com/davishmcclurg/json_schemer) by Davis W. McGuire.

Developed by [Stanford Digital Library](https://library.stanford.edu/).