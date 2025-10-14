defmodule Skema.Transformer do
  @moduledoc """
  Handles data transformation logic for Skema schemas.

  This module is responsible for transforming data according to schema
  transformation rules. It supports field renaming, value transformation,
  and computation of derived values.
  """

  alias Skema.Result

  @doc """
  Processes transformation for all fields in a schema.

  Returns `{:ok, data}` if transformation succeeds, `{:error, result}` otherwise.
  """
  @spec process_transformation(%Result{}) :: {:ok, map()} | {:error, %Result{}}
  def process_transformation(%Result{} = result) do
    final_result =
      Enum.reduce(result.schema, result, fn {field_name, _} = field, acc ->
        if Result.get_error(acc, field_name) do
          # Skip transformation if there's an error
          acc
        else
          process_field(acc, field)
        end
      end)

    if final_result.valid? do
      {:ok, final_result.valid_data}
    else
      {:error, final_result}
    end
  end

  @doc """
  Processes transformation for a single field.
  """
  @spec process_field(%Result{}, {atom(), list()}) :: %Result{}
  def process_field(result, {field_name, definitions}) when is_list(definitions) do
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

  @doc """
  Applies a transformation function to a field value.

  Supports multiple function signatures and error handling patterns.
  """
  @spec apply_transformation(nil | function(), any(), map()) ::
          {:ok, any()} | {:error, any()} | any()
  defp apply_transformation(nil, value, _data), do: {:ok, value}

  defp apply_transformation(transform_func, value, data) do
    case apply_function_safely(transform_func, value, data) do
      {status, result} when status in [:error, :ok] -> {status, result}
      result -> {:ok, result}
    end
  end

  # Private functions

  defp extract_field_value(data, field_name) do
    case Map.fetch(data, field_name) do
      {:ok, value} ->
        value

      :error ->
        case Map.fetch(data, "#{field_name}") do
          {:ok, value} -> value
          :error -> nil
        end
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
