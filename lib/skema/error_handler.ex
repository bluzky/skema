defmodule Skema.ErrorHandler do
  @moduledoc """
  Handles error formatting and enhanced error processing for Skema.

  This module provides utilities for formatting error responses,
  enhancing cast errors with validation results, and standardizing
  error output across the library.
  """

  alias Skema.{Result, Validator}

  @doc """
  Enhances cast errors by running validation on successfully cast data
  to provide a more comprehensive error picture.
  """
  @spec enhance_cast_errors_with_validation(%Result{}) :: %Result{}
  def enhance_cast_errors_with_validation(%Result{} = result) do
    # Run validation on successfully cast data to provide more comprehensive errors
    validation_result = Validator.process_validation(%{result | params: result.valid_data})

    case validation_result do
      {:error, %Result{errors: validation_errors}} ->
        # Merge validation errors with cast errors
        combined_errors = Map.merge(result.errors, validation_errors)
        %{result | errors: combined_errors}

      _ ->
        result
    end
  end

  @doc """
  Formats error response for public API consumption.

  Accepts both Result structs and custom error maps.
  """
  @spec format_error_response({:error, %Result{} | map()}) :: {:error, map()}
  def format_error_response({:error, %Result{errors: errors}}) do
    {:error, %{errors: errors}}
  end

  def format_error_response({:error, errors}) when is_map(errors) do
    {:error, %{errors: errors}}
  end

  @doc """
  Creates a standardized error response for non-map input.
  """
  @spec format_invalid_input_error() :: {:error, map()}
  def format_invalid_input_error do
    {:error, %{errors: %{_base: ["expected a map"]}}}
  end

  @doc """
  Merges errors from multiple Result structs.
  """
  @spec merge_errors(list(%Result{})) :: map()
  def merge_errors(results) when is_list(results) do
    Enum.reduce(results, %{}, fn result, acc ->
      Map.merge(acc, result.errors)
    end)
  end

  @doc """
  Checks if a result has any errors.
  """
  @spec has_errors?(%Result{}) :: boolean()
  def has_errors?(%Result{valid?: false}), do: true
  def has_errors?(%Result{valid?: true}), do: false

  @doc """
  Gets the first error message for a field, if any.
  """
  @spec get_first_error(%Result{}, atom()) :: String.t() | nil
  def get_first_error(%Result{errors: errors}, field) do
    case Map.get(errors, field) do
      nil -> nil
      error_list when is_list(error_list) -> List.first(error_list)
      error -> error
    end
  end

  @doc """
  Converts error messages to a flattened list of strings.
  """
  @spec flatten_errors(%Result{}) :: list(String.t())
  def flatten_errors(%Result{errors: errors}) do
    errors
    |> Enum.flat_map(fn {_field, field_errors} ->
      case field_errors do
        error_list when is_list(error_list) -> error_list
        error -> [error]
      end
    end)
    |> Enum.map(&to_string/1)
  end
end