defmodule Skema do
  @moduledoc """
  Skema is a simple schema validation and casting library for Elixir.

  Provides four main APIs:
  1. `cast_and_validate/2` - casting and validating data with given schema
  2. `cast/2` - casting data with given schema
  3. `validate/2` - validating data with given schema
  4. `transform/2` - transforming data with given schema

  ## Define schema
  Skema schema can be a map with field name as key and field definition as value,
  or a schema module.

  ```elixir
  schema = %{
    email: [type: :string, required: true],
    age: [type: :integer, number: [min: 18]],
    hobbies: [type: {:array, :string}]
  }
  ```

  or using defschema:

  ```elixir
  defmodule UserSchema do
    use Skema

    defschema do
      field :email, :string, required: true
      field :age, :integer, number: [min: 18]
      field :hobbies, {:array, :string}
    end
  end
  ```

  ## Data Processing Pipeline

  Skema provides a complete data processing pipeline:

  1. **Cast** - Convert raw input to proper types
  2. **Validate** - Check business rules and constraints
  3. **Transform** - Normalize, format, and compute derived values

  ```elixir
  # Full pipeline
  raw_data = %{"email" => "  JOHN@EXAMPLE.COM  ", "age" => "25"}

  with {:ok, cast_data} <- Skema.cast(raw_data, schema),
       :ok <- Skema.validate(cast_data, schema),
       {:ok, final_data} <- Skema.transform(cast_data, transform_schema) do
    {:ok, final_data}
  end

  # Or use the combined function
  case Skema.cast_and_validate(raw_data, schema) do
    {:ok, data} -> IO.puts("Data is valid")
    {:error, errors} -> IO.puts(inspect(errors))
  end
  ```

  ## Transformation Features

  Transform allows you to modify data after casting and validation:

  ```elixir
  transform_schema = %{
    email: [into: &String.downcase/1],
    full_name: [
      into: fn _value, data ->
        "\#{data.first_name} \#{data.last_name}"
      end
    ],
    user_id: [as: :id, into: &generate_uuid/1]
  }
  ```

  ### Transformation Options

  - `into` - Function to transform the field value
  - `as` - Rename the field in the output

  ### Function Types

  ```elixir
  # Simple transformation
  [into: &String.upcase/1]

  # Access to all data
  [into: fn value, data -> transform_with_context(value, data) end]

  # Module function
  [into: {MyModule, :transform_field}]

  # Error handling
  [into: fn value ->
    if valid?(value) do
      {:ok, normalize(value)}
    else
      {:error, "invalid value"}
    end
  end]
  ```

  ## API Differences

  - **cast/2** - Type conversion only, returns `{:ok, data}` or `{:error, result}`
  - **validate/2** - Rule checking only, returns `:ok` or `{:error, result}`
  - **transform/2** - Data transformation, returns `{:ok, data}` or `{:error, result}`
  - **cast_and_validate/2** - Combined cast + validate, returns `{:ok, data}` or `{:error, errors}`
  """

  alias Skema.Caster
  alias Skema.ErrorHandler
  alias Skema.Result
  alias Skema.Transformer
  alias Skema.Validator

  @doc false
  defmacro __using__(_) do
    quote do
      import Skema.Schema, only: [defschema: 1, defschema: 2]
    end
  end

  @doc """
  Cast and validate data with given schema.

  Returns `{:ok, data}` if both casting and validation succeed,
  `{:error, errors}` otherwise.
  """
  @spec cast_and_validate(data :: map(), schema :: map() | module()) ::
          {:ok, map()} | {:error, errors :: map()}
  def cast_and_validate(data, schema) do
    with {:ok, casted_data} <- cast(data, schema),
         :ok <- validate(casted_data, schema) do
      {:ok, casted_data}
    else
      {:error, %Result{} = result} ->
        # For cast errors, also run validation on valid data to get complete error picture
        enhanced_result = ErrorHandler.enhance_cast_errors_with_validation(result)
        ErrorHandler.format_error_response({:error, enhanced_result})
    end
  end

  @doc """
  Shortcut for `cast_and_validate/2`.
  """
  @spec load(data :: map(), schema :: map() | module()) ::
          {:ok, map()} | {:error, errors :: map()}
  def load(data, schema), do: cast_and_validate(data, schema)

  @doc """
  Cast data to proper types according to schema.

  Returns `{:ok, data}` if casting succeeds, `{:error, result}` otherwise.
  """
  @spec cast(data :: map(), schema :: map() | module()) ::
          {:ok, map()} | {:error, %Result{}}
  def cast(data, schema) when is_atom(schema) do
    fields_schema = Map.new(schema.__fields__())

    case cast(data, fields_schema) do
      {:ok, data} -> {:ok, struct(schema, data)}
      error -> error
    end
  end

  def cast(data, schema) when is_map(data) and is_list(schema) do
    # Handle keyword list schemas (from __fields__())
    cast(data, Map.new(schema))
  end

  def cast(data, schema) when is_map(data) and is_map(schema) do
    schema
    |> prepare_schema()
    |> build_initial_result(data)
    |> Caster.process_casting()
  end

  @doc """
  Validate data according to schema rules.

  Returns `:ok` if validation succeeds, `{:error, result}` otherwise.
  """
  @spec validate(data :: map(), schema :: map() | module()) ::
          :ok | {:error, %Result{}}
  def validate(data, schema) when is_atom(schema) do
    validate(data, schema.__fields__())
  end

  def validate(data, schema) when is_map(data) and is_list(schema) do
    # Handle keyword list schemas (from __fields__())
    validate(data, Map.new(schema))
  end

  def validate(data, schema) when is_map(data) and is_map(schema) do
    schema
    |> prepare_schema()
    |> build_validation_result(data)
    |> Validator.process_validation()
  end

  @doc """
  Transform data according to schema transformation rules.

  Supports multiple function signatures:
  - `transform(%SomeSchema{} = data)` - Transform struct using its schema's __fields__()
  - `transform(data, schema_module)` - Transform data using a schema module
  - `transform(data, schema_map)` - Transform data using a schema map
  - `transform(data, schema_keyword_list)` - Transform data using a keyword list schema

  ## Examples

      # Using struct with schema
      user = %UserSchema{name: "john", email: "JOHN@EXAMPLE.COM"}
      {:ok, transformed} = Skema.transform(user)
      # => %{name: "JOHN", email: "john@example.com"}

      # Using schema module
      data = %{name: "john", email: "JOHN@EXAMPLE.COM"}
      {:ok, transformed} = Skema.transform(data, UserSchema)

      # Using schema map
      schema = %{name: [into: &String.upcase/1]}
      {:ok, transformed} = Skema.transform(data, schema)

  ## Transformation Context

  When transformation functions access the `data` parameter, they receive the
  **original input data**, not data that has been transformed by other fields.
  This ensures transformations are independent and deterministic.

      schema = %{
        name: [into: &String.upcase/1],
        display: [into: &String.upcase/1]
      }
      
      data = %{name: "john"}
      {:ok, result} = Skema.transform(data, schema)
      # result.display will be "Name: john", not "Name: JOHN"

  Returns `{:ok, data}` if transformation succeeds, `{:error, result}` otherwise.
  """
  @spec transform(data :: map() | struct(), schema :: map() | module()) ::
          {:ok, map()} | {:error, %Result{}}
  def transform(%schema{} = data) do
    # Handle struct data with schema that has __fields__()
    if function_exported?(schema, :__fields__, 0) do
      data_map = Map.from_struct(data)
      transform(data_map, schema.__fields__())
    else
      {:error, "Schema #{schema} does not support transform"}
    end
  end

  def transform(data, schema) when is_atom(schema) do
    transform(data, schema.__fields__())
  end

  def transform(data, schema) when is_map(data) and is_list(schema) do
    # Handle keyword list schemas (from __fields__())
    transform(data, Map.new(schema))
  end

  def transform(data, schema) when is_map(data) and is_map(schema) do
    schema
    |> prepare_schema()
    |> build_transformation_result(data)
    |> Transformer.process_transformation()
  end

  # ============================================================================
  # Schema Processing Helpers
  # ============================================================================

  defp prepare_schema(schema) do
    Skema.SchemaHelper.expand(schema)
  end

  defp build_initial_result(schema, data) do
    Result.new(schema: schema, params: data)
  end

  defp build_validation_result(schema, data) do
    Result.new(schema: schema, params: data, valid_data: data)
  end

  defp build_transformation_result(schema, data) do
    Result.new(schema: schema, params: data, valid_data: data)
  end

  # Casting logic moved to Skema.Caster module

  # Validation logic moved to Skema.Validator module

  # Transformation logic moved to Skema.Transformer module

  # Utility functions moved to respective modules
  # - apply_function_safely moved to Skema.Caster, Skema.Validator, Skema.Transformer
  # - enhance_cast_errors_with_validation moved to Skema.ErrorHandler
  # - format_error_response moved to Skema.ErrorHandler
end
