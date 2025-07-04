# Skema

Phoenix request params validation library.

[![Build Status](https://github.com/bluzky/skema/workflows/Elixir%20CI/badge.svg)](https://github.com/bluzky/skema/actions) [![Coverage Status](https://coveralls.io/repos/github/bluzky/skema/badge.svg?branch=main)](https://coveralls.io/github/bluzky/skema?branch=main) [![Hex Version](https://img.shields.io/hexpm/v/skema.svg)](https://hex.pm/packages/skema) [![docs](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/skema/)

- [Skema](#skema)
    - [Why Skema](#why-skema)
    - [Installation](#installation)
    - [Usage](#usage)
    - [Define schema](#define-schema)
        - [Default value](#default-value)
        - [Custom cast function](#custom-cast-function)
        - [Nested schema](#nested-schema)
        - [Transform data](#transform-data)
    - [Validation](#validation)
    - [Data Processing Pipeline](#data-processing-pipeline)
    - [Contributors](#contributors)

## Why Skema
- Reduce code boilerplate
- Shorter schema definition
- Default function which generate value each casting time
- Custom validation functions
- Custom cast functions
- Data transformation and normalization
- Complete data processing pipeline (cast → validate → transform)

## Installation

[Available in Hex](https://hex.pm/skema), the package can be installed
by adding `skema` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:skema, "~> 1.0"}
  ]
end
```

## Usage

**Process order**
> Cast data → validate casted data → transform data

```elixir
use Skema

defschema IndexParams do
    field :keyword, :string
    field :status, :string, required: true
    field :group_id, :integer, number: [greater_than: 0]
    field :name, :string
end

def index(conn, params) do
    with {:ok, better_params} <- Skema.cast_and_validate(params, IndexParams) do
        # do anything with your params
    else
        {:error, errors} -> # return params error
    end
end
```

## Define schema

```elixir
use Skema

defschema IndexParams do
    field :keyword, :string
    field :status, :string, required: true
    field :group_id, :integer, number: [greater_than: 0]
    field :name, :string
end
```

Define a field using macro `field(field_name :: atom(), type :: term(), opts \\ [])`

- `type`: `Skema` supports same data types as `Ecto`. Code borrowed from Ecto

Supported options:

- `default`: default value or default function
- `cast_func`: custom cast function
- `number, format, length, in, not_in, func, required, each` are available validations
- `from`: use value from another field
- `as`: alias key you will receive from `Skema.cast` if casting is succeeded
- `into`: transformation function (used by `Skema.transform/2`)

### Default value
You can define a default value for a field if it's missing from the params.

```elixir
field :status, :string, default: "pending"
```

Or you can define a default value as a function. This function is evaluated when `Skema.cast` gets invoked.

```elixir
field :date, :utc_datetime, default: &DateTime.utc_now/0
```

### Custom cast function
You can define your own casting function using the `cast_func` option.
Your `cast_func` must follow this spec:

```elixir
fn(any) :: {:ok, any} | {:error, binary} | :error
```

#### Simple cast function

```elixir
def my_array_parser(value) do
    if is_binary(value) do
        ids =
            String.split(value, ",")
            |> Enum.map(&String.to_integer/1)

        {:ok, ids}
    else
        {:error, "Invalid string"}
    end
end

defschema Sample do
   field :user_ids, {:array, :integer}, cast_func: &my_array_parser/1
end
```

#### Cast function with data access

```elixir
defschema UserParams do
   field :full_name, :string, cast_func: fn _value, data ->
       {:ok, "#{data.first_name} #{data.last_name}"}
   end
end
```

#### Module function tuple

```elixir
defschema Sample do
   field :email, :string, cast_func: {MyModule, :normalize_email}
end
```

### Nested schema
With `Skema` you can parse and validate nested maps and lists easily

```elixir
defschema Address do
    field :street, :string
    field :district, :string
    field :city, :string
end

defschema User do
    field :name, :string
    field :email, :string, required: true
    field :addresses, {:array, Address}
end
```

#### ⚠️ Important: Schema Definition Order

When using `defschema` with nested schemas, **always define the nested schemas before the schemas that reference them**. This is a compile-time dependency requirement.

**❌ Wrong - Will fail with "is invalid" error:**
```elixir
defschema HTTPRequestSchema do
  field :auth, AuthSchema  # ← AuthSchema not yet defined!
end

defschema AuthSchema do
  field :type, :string, required: true
end
```

**✅ Correct - Define dependencies first:**
```elixir
# Define AuthSchema FIRST
defschema AuthSchema do
  field :type, :string, required: true
  field :token, :string
end

# Then define schemas that reference it
defschema HTTPRequestSchema do
  field :url, :string, required: true
  field :auth, AuthSchema  # ← Now AuthSchema exists!
end
```

### Transform data
Transform allows you to modify and normalize data after casting and validation:

```elixir
# Using schema definition
defschema UserParams do
    field :email, :string, into: &String.downcase/1
    field :user_name, :string, as: :username, into: &String.trim/1
end

# Or using map schema with Skema.transform/2
transform_schema = %{
    email: [into: &String.downcase/1],
    full_name: [into: fn _value, data -> "#{data.first_name} #{data.last_name}" end],
    tags: [into: fn tags_string ->
        tags_string
        |> String.split(",")
        |> Enum.map(&String.trim/1)
    end]
}

{:ok, transformed_data} = Skema.transform(data, transform_schema)
```

#### Transform function types

```elixir
# Simple transformation
field :name, :string, into: &String.upcase/1

# Access to all data
field :display_name, :string, into: fn _value, data ->
    "#{data.title} #{data.name}"
end

# Module function
field :email, :string, into: {MyModule, :normalize_email}

# Error handling
field :score, :integer, into: fn value ->
    if value < 0 do
        {:error, "score cannot be negative"}
    else
        {:ok, value}
    end
end

# Field renaming
field :user_email, :string, as: :email, into: &String.downcase/1

# Partial application with predefined parameters
field :name_parts, {:array, :string}, into: &String.split(&1, " ", parts: 2)
```

## Validation

`Skema` uses `Valdi` validation library. You can read more about [Valdi here](https://github.com/bluzky/valdi)

Basically it supports following validations:

- validate inclusion/exclusion
- validate length for string and enumerable types
- validate number
- validate string format/pattern
- validate custom function
- validate required(not nil) or not
- validate each array item

```elixir
defschema Product do
    field :sku, :string, required: true, length: [min: 6, max: 20]
    field :name, :string, required: true
    field :quantity, :integer, number: [min: 0]
    field :type, :string, in: ~w(physical digital)
    field :expiration_date, :naive_datetime, func: &my_validation_func/1
    field :tags, {:array, :string}, each: [length: [max: 50]]
end
```

### Dynamic required
- Can accept function or `{module, function}` tuple
- Only supports 2-arity functions

```elixir
def require_email?(value, data), do: is_nil(data.phone)

# ...

field :email, :string, required: {__MODULE__, :require_email?}
```

### Validate array items
Support validating array items with `:each` option. `each` accepts a list of validators:

```elixir
field :values, {:array, :number}, each: [number: [min: 20, max: 50]]
```

## Data Processing Pipeline

Skema provides a complete data processing pipeline with four main functions:

### 1. `Skema.cast/2` - Type Conversion
Converts raw input data to proper types according to schema definitions.

```elixir
schema = %{age: :integer, active: :boolean}
{:ok, %{age: 25, active: true}} = Skema.cast(%{"age" => "25", "active" => "true"}, schema)
```

### 2. `Skema.validate/2` - Rule Checking
Validates data against business rules and constraints.

```elixir
schema = %{age: [type: :integer, number: [min: 18]]}
:ok = Skema.validate(%{age: 25}, schema)
{:error, _} = Skema.validate(%{age: 15}, schema)
```

### 3. `Skema.transform/2` - Data Transformation
Normalizes, formats, and computes derived values.

```elixir
transform_schema = %{
  email: [into: &String.downcase/1],
  full_name: [into: fn _value, data -> "#{data.first_name} #{data.last_name}" end]
}

{:ok, transformed} = Skema.transform(data, transform_schema)
```

### 4. `Skema.cast_and_validate/2` - Combined Operation
Performs casting and validation in one step.

```elixir
{:ok, data} = Skema.cast_and_validate(params, schema)
```

### Complete Pipeline Example

```elixir
# Raw input
raw_params = %{
  "email" => "  JOHN@EXAMPLE.COM  ",
  "age" => "25",
  "first_name" => "john",
  "last_name" => "doe"
}

# Schema definition
schema = %{
  email: [type: :string, required: true],
  age: [type: :integer, number: [min: 18]],
  first_name: [type: :string, required: true],
  last_name: [type: :string, required: true]
}

# Transform schema
transform_schema = %{
  email: [into: fn email -> String.trim(email) |> String.downcase() end],
  full_name: [into: fn _value, data -> "#{data.first_name} #{data.last_name}" end],
  first_name: [into: &String.capitalize/1],
  last_name: [into: &String.capitalize/1]
}

# Step by step
with {:ok, cast_data} <- Skema.cast(raw_params, schema),
     :ok <- Skema.validate(cast_data, schema),
     {:ok, final_data} <- Skema.transform(cast_data, transform_schema) do
  {:ok, final_data}
  # Result: %{
  #   email: "john@example.com",
  #   age: 25,
  #   first_name: "John",
  #   last_name: "Doe",
  #   full_name: "John Doe"
  # }
end
```

## Thank you
If you find a bug or want to improve something, please send a pull request. Thank you!
