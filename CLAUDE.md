# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Skema is a Phoenix request params validation library for Elixir that provides type casting, validation, and data transformation capabilities. It's designed to reduce boilerplate code and provide a complete data processing pipeline for web applications.

## Development Commands

### Core Commands
- `mix deps.get` - Install dependencies
- `mix compile` - Compile the project
- `mix test` - Run all tests
- `mix test test/filename_test.exs` - Run a specific test file
- `mix test --cover` - Run tests with coverage using ExCoveralls
- `mix docs` - Generate documentation
- `mix format` - Format code using Elixir formatter
- `mix credo` - Run code analysis (if available)

### Test Coverage Commands
- `mix coveralls` - Run tests with coverage report
- `mix coveralls.detail` - Generate detailed coverage report
- `mix coveralls.html` - Generate HTML coverage report

### Publishing Commands
- `mix hex.publish` - Publish package to Hex.pm (for maintainers)

## Code Architecture

### Core Modules Structure

The library is organized into several key modules:

1. **`Skema`** (`lib/skema.ex`) - Main API module providing:
   - `cast_and_validate/2` - Combined casting and validation
   - `cast/2` - Type casting only
   - `validate/2` - Validation only  
   - `transform/2` - Data transformation

2. **`Skema.Schema`** (`lib/schema.ex`) - Schema definition macros:
   - `defschema` macro for defining structured schemas
   - `field/3` macro for defining individual fields
   - Auto-generates structs, type specs, and helper methods

3. **`Skema.Type`** (`lib/type.ex`) - Type casting engine:
   - Handles casting to built-in Elixir types
   - Supports custom types and Ecto-style types
   - Array casting with nested type support

4. **`Skema.Result`** (`lib/result.ex`) - Internal result handling:
   - Accumulates validation errors and valid data
   - Tracks operation state during processing

5. **`Skema.SchemaHelper`** (`lib/schema_helper.ex`) - Schema processing utilities:
   - Expands schema definitions
   - Handles default value evaluation

### Data Processing Pipeline

The library follows a three-stage pipeline:

1. **Cast** - Convert raw input to proper types
2. **Validate** - Check business rules and constraints  
3. **Transform** - Normalize, format, and compute derived values

### Schema Definition Patterns

Schemas can be defined in two ways:

1. **Map-based schemas** - Simple key-value definitions
2. **Struct-based schemas** - Using `defschema` macro for typed structs

### Key Features

- **Type Safety** - Automatic struct generation with `@type` annotations
- **Validation** - Integration with Valdi validation library
- **Custom Types** - Support for Ecto-style custom types
- **Nested Schemas** - Recursive schema definitions
- **Default Values** - Static values or function-based defaults
- **Field Transformation** - Post-processing with `into` option
- **Custom Casting** - Override default casting behavior

## Testing Strategy

Tests are organized by functionality:
- `skema_test.exs` - Main API tests
- `defschema_test.exs` - Schema definition macro tests
- `validate_test.exs` - Validation logic tests
- `transform_test.exs` - Data transformation tests

All tests use ExUnit and the project includes ExCoveralls for coverage reporting.

## Dependencies

- **valdi** - Validation library
- **decimal** - Decimal number support
- **ex_doc** - Documentation generation (dev only)
- **excoveralls** - Test coverage (test only)
- **styler** - Code formatting (dev/test only)

## Common Development Patterns

### Schema Definition
```elixir
defmodule MySchema do
  use Skema

  defschema do
    field :name, :string, required: true
    field :age, :integer, number: [min: 0]
    field :email, :string, format: ~r/@/
    field :tags, {:array, :string}, default: []
  end
end
```

### Usage in Phoenix Controllers
```elixir
def create(conn, params) do
  with {:ok, validated_params} <- Skema.cast_and_validate(params, MySchema) do
    # Handle valid params
  else
    {:error, errors} -> # Handle validation errors
  end
end
```

### Custom Types
Custom types should implement either:
- `cast/1` function for type casting
- `validate/1` function for validation
- `type/0` function returning base type