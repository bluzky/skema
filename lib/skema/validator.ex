defmodule Skema.Validator do
  @moduledoc """
  Handles validation logic for Skema schemas.

  This module is responsible for validating data against business rules
  and constraints defined in schema field definitions. It supports
  built-in validations, custom functions, and nested schema validation.
  """

  alias Skema.Result

  @doc """
  Processes validation for all fields in a schema.

  Returns `:ok` if validation succeeds, `{:error, result}` otherwise.
  """
  @spec process_validation(%Result{}) :: :ok | {:error, %Result{}}
  def process_validation(%Result{} = result) do
    final_result =
      Enum.reduce(result.schema, result, fn {field_name, _} = field, acc ->
        if Result.get_error(acc, field_name) do
          # Skip validation if there's already a casting error
          acc
        else
          process_field(acc, field)
        end
      end)

    if final_result.valid? do
      :ok
    else
      {:error, final_result}
    end
  end

  @doc """
  Processes validation for a single field.
  """
  @spec process_field(%Result{}, {atom(), list()}) :: %Result{}
  def process_field(result, {field_name, definitions}) when is_list(definitions) do
    value = extract_field_value(result.valid_data, field_name)

    case validate_field(field_name, value, result.valid_data, definitions) do
      :ok ->
        result

      {:error, error} ->
        Result.put_error(result, field_name, error)
    end
  end

  @doc """
  Validates a single field value against all its validation rules.
  """
  @spec validate_field(atom(), any(), map(), keyword()) :: :ok | {:error, any()}
  def validate_field(field_name, value, all_data, definitions) do
    definitions
    |> Enum.map(&validate_rule(field_name, value, all_data, &1))
    |> collect_validation_results()
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

  defp validate_rule(_field_name, value, data, {:required, required_func})
       when is_function(required_func) or is_tuple(required_func) do
    case apply_function_safely(required_func, value, data) do
      {:error, _} = error ->
        error

      result ->
        is_required = result not in [false, nil]
        Valdi.validate(value, required: is_required)
    end
  end

  defp validate_rule(_field_name, value, _data, {:required, required}) do
    Valdi.validate(value, required: required)
  end

  defp validate_rule(_field_name, nil, _data, _rule), do: :ok

  defp validate_rule(_field_name, value, _data, {:type, %{} = nested_schema}) do
    if is_map(value) do
      # For nested schemas, defer to Skema module to avoid circular dependency
      Skema.validate(value, nested_schema)
    else
      {:error, "is invalid"}
    end
  end

  defp validate_rule(_field_name, value, _data, {:type, {:array, nested_type}}) when is_list(value) do
    value
    |> Enum.map(&validate_rule(nil, &1, value, {:type, nested_type}))
    |> Enum.reverse()
    |> collect_validation_results()
  end

  defp validate_rule(_field_name, value, _data, {:type, type}) do
    validate_type(value, type)
  end

  defp validate_rule(field_name, value, data, {:func, func}) do
    apply_validation_function(func, field_name, value, data)
  end

  defp validate_rule(_field_name, value, _data, validator) do
    Valdi.validate(value, [validator], ignore_unknown: true)
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

  defp apply_function_safely(func, value, data) do
    case func do
      {mod, func_name} ->
        cond do
          function_exported?(mod, func_name, 1) ->
            apply(mod, func_name, [value])

          function_exported?(mod, func_name, 2) ->
            apply(mod, func_name, [value, data])

          true ->
            {:error, "invalid function"}
        end

      func when is_function(func, 2) ->
        func.(value, data)

      func when is_function(func, 1) ->
        func.(value)

      _ ->
        {:error, "invalid function"}
    end
  end
end
