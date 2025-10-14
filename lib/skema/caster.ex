defmodule Skema.Caster do
  @moduledoc """
  Handles type casting logic for Skema schemas.

  This module is responsible for converting raw input data to proper types
  according to schema definitions. It processes each field, applies custom
  casting functions, and handles nested schemas and arrays.
  """

  alias Skema.Result
  alias Skema.Type

  @doc """
  Processes casting for all fields in a schema.

  Returns `{:ok, data}` if casting succeeds, `{:error, result}` otherwise.
  """
  @spec process_casting(%Result{}) :: {:ok, map()} | {:error, %Result{}}
  def process_casting(%Result{} = result) do
    final_result =
      Enum.reduce(result.schema, result, fn field, acc ->
        process_field(acc, field)
      end)

    if final_result.valid? do
      {:ok, final_result.valid_data}
    else
      {:error, final_result}
    end
  end

  @doc """
  Processes casting and validation for all fields in a schema in a single pass.

  This is an optimized version that validates each field immediately after successful casting,
  reducing the number of iterations from 2 to 1.

  Returns `{:ok, data}` if both casting and validation succeed, `{:error, result}` otherwise.
  """
  @spec process_cast_and_validate(%Result{}) :: {:ok, map()} | {:error, %Result{}}
  def process_cast_and_validate(%Result{} = result) do
    final_result =
      Enum.reduce(result.schema, result, fn field, acc ->
        process_field_with_validation(acc, field)
      end)

    if final_result.valid? do
      {:ok, final_result.valid_data}
    else
      {:error, final_result}
    end
  end

  @doc """
  Processes casting for a single field.
  """
  @spec process_field(%Result{}, {atom(), list()}) :: %Result{}
  def process_field(result, {field_name, definitions}) do
    case cast_field(result.params, field_name, definitions) do
      {:ok, value} ->
        Result.put_data(result, field_name, value)

      {:error, error} ->
        Result.put_error(result, field_name, error)
    end
  end

  @doc """
  Processes casting and validation for a single field.

  Casts the field first, and if successful, immediately validates it.
  """
  @spec process_field_with_validation(%Result{}, {atom(), list()}) :: %Result{}
  def process_field_with_validation(result, {field_name, definitions}) do
    case cast_field(result.params, field_name, definitions) do
      {:ok, value} ->
        # Cast succeeded, now validate
        updated_result = Result.put_data(result, field_name, value)

        # Validate the field using the validator
        case Skema.Validator.validate_field(field_name, value, updated_result.valid_data, definitions) do
          :ok ->
            updated_result

          {:error, error} ->
            Result.put_error(updated_result, field_name, error)
        end

      {:error, error} ->
        Result.put_error(result, field_name, error)
    end
  end

  @doc """
  Casts a single field value according to its definition.
  """
  @spec cast_field(map(), atom(), keyword()) :: {:ok, any()} | {:error, any()}
  def cast_field(data, field_name, definitions) when is_list(definitions) do
    {custom_message, clean_definitions} = Keyword.pop(definitions, :message)

    case perform_cast(data, field_name, clean_definitions) do
      {:ok, value} ->
        {:ok, value}

      {:error, error} ->
        formatted_error =
          case custom_message do
            nil -> if is_binary(error), do: [error], else: error
            msg -> [msg]
          end

        {:error, formatted_error}
    end
  end

  def cast_field(_, _, _), do: raise("Use Skema.expand/1 to build full schema")

  # Private functions

  defp perform_cast(data, field_name, definitions) do
    source_field = definitions[:from] || field_name
    value = extract_field_value(data, source_field, definitions[:default])

    case definitions[:cast_func] do
      nil ->
        cast_with_type(value, definitions[:type])

      cast_func ->
        case apply_function_safely(cast_func, value, data) do
          :error -> {:error, "is invalid"}
          result -> result
        end
    end
  end

  defp extract_field_value(data, field_name, default) do
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

  defp cast_with_type(nil, _type), do: {:ok, nil}

  defp cast_with_type(value, {:array, %{} = nested_schema}) do
    cast_array_of_schemas(nested_schema, value)
  end

  defp cast_with_type(value, %{} = nested_schema) when is_map(value) do
    # Defer to Skema module to avoid circular dependency
    Skema.cast(value, nested_schema)
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
end
