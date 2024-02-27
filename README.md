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
            - [1. Custom cast function accept value only](#1-custom-cast-fuction-accept-value-only)
            - [2.Custom cast function accept tuple {M, f}](#3custom-cast-function-accept-tuple-m-f)
        - [Nested schema](#nested-schema)
    - [Validation](#validation)
    - [Contributors](#contributors)


## Why Skema
    - Reduce code boilerplate 
    - Shorter schema definition
    - Default function which generate value each casting time
    - Custom validation functions
    - Custom parse functions
    
## Installation

[Available in Hex](https://hex.pm/skema), the package can be installed
by adding `skema` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:skema, "~> 0.1"}
  ]
end
```

## Usage

**Process order**
> Cast data -> validate casted data -> transform data

```elixir
use Skema
defschema IndexParams do
    field :keyword, :string
    field :status, :string, required: true
    field :group_id, :integer, number: [greater_than: 0]
    field :name, :string
end

def index(conn, params) do
    with {:ok, better_params} <- IndexParams.cast(params) do
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

Define a field using macro `@spec field(field_name :: atom(), type :: term(), opts \\ [])`

- `type`: `Skema` support same data type as `Ecto`. I borrowed code from Ecto

Supported options:

- `default`: default value or default function
- `cast_func`: custom cast function
- `number, format, length, in, not_in, func, required, each` are available validations
- `from`: use value from another field
- `as`: alias key you will receive from `Skema.cast` if casting is succeeded


### Default value
You can define a default value for a field if it's missing from the params.

```elixir
field :status, :string, default: "pending"
```

Or you can define a default value as a function. This function is evaluated when `Skema.cast` gets invoked.

```elixir
field :date, :utc_datetime, default: &Timex.now/0
```

### Custom cast function
You can define your own casting function, `skema` provide `cast_func` option.
Your `cast_func` must follows this spec 

#### 1. Custom cast fuction accept value only

```elixir
fn(any) :: {:ok, any} | {:error, binary} | :error
```

```elixir
def my_array_parser(value) do
    if is_binary(value) do
        ids = 
            String.split(value, ",")
            |> Enum.map(&String.to_integer(&1))
        
        {:ok, ids}
    else
        {:error, "Invalid string"
    end
end

defschema Sample do
   field :user_id, {:array, :integer}, cast_func: &my_array_parser/1
end

```
This is a demo parser function.


### Nested schema
With `Skema` you can parse and validate nested map and list easily

```elixir
defschema Address do
    field :street, :string
    field :district, :string
    field :city, :string
end

defschema User do
    field :name, :string,
    field :email, :string, required: true
    field :addresses, {:array, Address}
end
```


## Validation

`Skema` uses `Valdi` validation library. You can read more about [Valdi here](https://github.com/bluzky/valdi)
Basically it supports following validation

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
    field :name, :string, required: true,
    field :quantity, :integer, number: [min: 0],
    field :type: :string, in: ~w(physical digital),
    field :expiration_date, :naive_datetime, func: &my_validation_func/1,
    field :tags, {:array, :string}, each: [length: [max: 50]]
end
  ```

### Dynamic required
- Can accept function or `{module, function}` tuple
- Only support 2 arity function


```elixir
def require_email?(value, data), do: is_nil(email.phone)

....

field :email, :string, required: {__MODULE__, :require_email?}
```

### Validate array item
Support validate array item with `:each` option, `each` accept a list of validators

```elixir
...
    field :values, {:array, :number}, each: [number: [min: 20, max: 50]]
...
```

## Thank you
If you find a bug or want to improve something, please send a pull request. Thank you!
