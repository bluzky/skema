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

  alias Skema.Result
  alias Skema.Type

  @doc false
  defmacro __using__(_) do
    quote do
      import Skema.Schema, only: [defschema: 1, defschema: 2]
    end
  end

  # ============================================================================
  # Public API
  # ============================================================================

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
        enhanced_result = enhance_cast_errors_with_validation(result)
        format_error_response({:error, enhanced_result})
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
    |> process_casting()
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
    |> process_validation()
  end

  @doc """
  Transform data according to schema transformation rules.

  Returns `{:ok, data}` if transformation succeeds, `{:error, result}` otherwise.
  """
  @spec transform(data :: map(), schema :: map()) ::
          {:ok, map()} | {:error, %Result{}}
  def transform(data, schema) when is_map(data) and is_map(schema) do
    schema
    |> prepare_schema()
    |> build_transformation_result(data)
    |> process_transformation()
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

  # ============================================================================
  # Casting Logic
  # ============================================================================

  defp process_casting(%Result{} = result) do
    final_result =
      Enum.reduce(result.schema, result, fn field, acc ->
        process_cast_field(acc, field)
      end)

    if final_result.valid? do
      {:ok, final_result.valid_data}
    else
      {:error, final_result}
    end
  end

  defp process_cast_field(result, {field_name, definitions}) do
    case cast_single_field(result.params, field_name, definitions) do
      {:ok, value} ->
        Result.put_data(result, field_name, value)

      {:error, error} ->
        Result.put_error(result, field_name, error)
    end
  end

  defp cast_single_field(data, field_name, definitions) do
    {custom_message, clean_definitions} = extract_custom_message(definitions)

    case perform_field_cast(data, field_name, clean_definitions) do
      {:ok, value} ->
        {:ok, value}

      {:error, error} ->
        formatted_error = format_cast_error(error, custom_message)
        {:error, formatted_error}
    end
  end

  defp extract_custom_message(definitions) do
    Keyword.pop(definitions, :message)
  end

  defp format_cast_error(error, nil) do
    if is_binary(error), do: [error], else: error
  end

  defp format_cast_error(_error, custom_message) do
    [custom_message]
  end

  defp perform_field_cast(data, field_name, definitions) do
    source_field = definitions[:from] || field_name
    value = extract_field_value(data, source_field, definitions[:default])

    case get_cast_function(definitions) do
      nil ->
        cast_with_type(value, definitions[:type])

      cast_func ->
        apply_custom_cast_function(cast_func, value, data)
    end
  end

  defp extract_field_value(data, field_name, default \\ nil) do
    case Map.fetch(data, field_name) do
      {:ok, value} ->
        value

      :error ->
        case Map.fetch(data, "#{field_name}") do
          {:ok, value} -> value
          :error -> default
        end
    end
  end

  defp get_cast_function(definitions) do
    definitions[:cast_func]
  end

  defp cast_with_type(nil, _type), do: {:ok, nil}

  defp cast_with_type(value, {:array, %{} = nested_schema}) do
    cast_array_of_schemas(nested_schema, value)
  end

  defp cast_with_type(value, %{} = nested_schema) when is_map(value) do
    cast(value, nested_schema)
  end

  defp cast_with_type(_value, %{}), do: {:error, "is invalid"}

  defp cast_with_type(value, type) do
    case Type.cast(type, value) do
      :error -> {:error, "is invalid"}
      result -> result
    end
  end

  defp cast_array_of_schemas(schema, value, acc \\ [])

  defp cast_array_of_schemas(_schema, [], acc) do
    {:ok, Enum.reverse(acc)}
  end

  defp cast_array_of_schemas(schema, [item | rest], acc) do
    case cast_with_type(item, schema) do
      {:ok, casted_item} ->
        cast_array_of_schemas(schema, rest, [casted_item | acc])

      error ->
        error
    end
  end

  defp apply_custom_cast_function(func, value, data) do
    case apply_function_safely(func, value, data) do
      :error -> {:error, "is invalid"}
      result -> result
    end
  end

  # ============================================================================
  # Validation Logic
  # ============================================================================

  defp process_validation(%Result{} = result) do
    final_result =
      Enum.reduce(result.schema, result, fn {field_name, _} = field, acc ->
        if Result.get_error(acc, field_name) do
          # Skip validation if there's already a casting error
          acc
        else
          process_validation_field(acc, field)
        end
      end)

    if final_result.valid? do
      :ok
    else
      {:error, final_result}
    end
  end

  defp process_validation_field(result, {field_name, definitions}) do
    value = extract_field_value(result.valid_data, field_name)

    case validate_single_field(field_name, value, result.valid_data, definitions) do
      :ok ->
        result

      {:error, error} ->
        Result.put_error(result, field_name, error)
    end
  end

  defp validate_single_field(field_name, value, all_data, definitions) do
    definitions
    |> Enum.map(&validate_single_rule(field_name, value, all_data, &1))
    |> collect_validation_results()
  end

  defp validate_single_rule(_field_name, value, data, {:required, required_func})
       when is_function(required_func) or is_tuple(required_func) do
    case apply_function_safely(required_func, value, data) do
      {:error, _} = error ->
        error

      result ->
        is_required = result not in [false, nil]
        Valdi.validate(value, required: is_required)
    end
  end

  defp validate_single_rule(_field_name, value, _data, {:required, required}) do
    Valdi.validate(value, required: required)
  end

  defp validate_single_rule(_field_name, nil, _data, _rule), do: :ok

  defp validate_single_rule(_field_name, value, _data, {:type, %{} = nested_schema}) do
    if is_map(value) do
      validate(value, nested_schema)
    else
      {:error, "is invalid"}
    end
  end

  defp validate_single_rule(_field_name, value, _data, {:type, {:array, nested_type}}) when is_list(value) do
    value
    |> Enum.map(&validate_single_rule(nil, &1, value, {:type, nested_type}))
    |> Enum.reverse()
    |> collect_validation_results()
  end

  defp validate_single_rule(_field_name, value, _data, {:type, type}) do
    validate_type(value, type)
  end

  defp validate_single_rule(field_name, value, data, {:func, func}) do
    apply_validation_function(func, field_name, value, data)
  end

  defp validate_single_rule(_field_name, value, _data, validator) do
    Valdi.validate(value, [validator])
  end

  defp validate_type(value, type) do
    cond do
      is_atom(type) and function_exported?(type, :validate, 1) ->
        type.validate(value)

      is_atom(type) and function_exported?(type, :type, 0) ->
        # Support Ecto.Type and custom type
        Valdi.validate(value, type: type.type())

      true ->
        Valdi.validate(value, type: type)
    end
  end

  defp apply_validation_function(func, field_name, value, data) do
    case func do
      {mod, func_name} ->
        apply(mod, func_name, [value, data])

      {mod, func_name, args} ->
        apply(mod, func_name, args ++ [value, data])

      func when is_function(func, 3) ->
        func.(field_name, value, data)

      func when is_function(func) ->
        func.(value)

      _ ->
        {:error, "invalid custom validation function"}
    end
  end

  defp collect_validation_results(results) do
    case Enum.reduce(results, {:ok, []}, &accumulate_validation_result/2) do
      {:ok, _} -> :ok
      {:error, errors} -> {:error, Enum.concat(errors)}
    end
  end

  defp accumulate_validation_result(:ok, acc), do: acc

  defp accumulate_validation_result({:error, %Result{} = result}, {_, acc_msgs}) do
    {:error, [[result] | acc_msgs]}
  end

  defp accumulate_validation_result({:error, msg}, {_, acc_msgs}) when is_list(msg) do
    {:error, [msg | acc_msgs]}
  end

  defp accumulate_validation_result({:error, msg}, {_, acc_msgs}) do
    {:error, [[msg] | acc_msgs]}
  end

  # ============================================================================
  # Transformation Logic
  # ============================================================================

  defp process_transformation(%Result{} = result) do
    final_result =
      Enum.reduce(result.schema, result, fn {field_name, _} = field, acc ->
        if Result.get_error(acc, field_name) do
          # Skip transformation if there's an error
          acc
        else
          process_transformation_field(acc, field)
        end
      end)

    if final_result.valid? do
      {:ok, final_result.valid_data}
    else
      {:error, final_result}
    end
  end

  defp process_transformation_field(result, {field_name, definitions}) do
    value = extract_field_value(result.valid_data, field_name)
    target_field_name = definitions[:as] || field_name

    case apply_transformation(definitions[:into], value, result.valid_data) do
      {:ok, transformed_value} ->
        Result.put_data(result, target_field_name, transformed_value)

      {:error, error} ->
        Result.put_error(result, target_field_name, error)

      transformed_value ->
        Result.put_data(result, target_field_name, transformed_value)
    end
  end

  defp apply_transformation(nil, value, _data), do: {:ok, value}

  defp apply_transformation(transform_func, value, data) do
    case apply_function_safely(transform_func, value, data) do
      {status, result} when status in [:error, :ok] -> {status, result}
      result -> {:ok, result}
    end
  end

  # ============================================================================
  # Utility Functions
  # ============================================================================

  defp apply_function_safely(func, value, data) do
    case func do
      {mod, func_name} ->
        cond do
          function_exported?(mod, func_name, 1) ->
            apply(mod, func_name, [value])

          function_exported?(mod, func_name, 2) ->
            apply(mod, func_name, [value, data])

          true ->
            {:error, "bad function"}
        end

      func when is_function(func, 2) ->
        func.(value, data)

      func when is_function(func, 1) ->
        func.(value)

      _ ->
        {:error, "bad function"}
    end
  end

  defp enhance_cast_errors_with_validation(%Result{} = result) do
    # Run validation on successfully cast data to provide more comprehensive errors
    validation_result = validate(result.valid_data, result.schema)

    case validation_result do
      {:error, %Result{errors: validation_errors}} ->
        # Merge validation errors with cast errors
        combined_errors = Map.merge(result.errors, validation_errors)
        %{result | errors: combined_errors}

      _ ->
        result
    end
  end

  defp format_error_response({:error, %Result{errors: errors}}) do
    {:error, %{errors: errors}}
  end
end
