defmodule Skema.Result do
  @moduledoc """
  Result Struct for Skema operations
  """
  @enforce_keys [:schema]
  defstruct schema: %{},
            valid_data: %{},
            params: %{},
            errors: %{},
            valid?: true

  @doc """
  Create a new Result struct with given schema map and params.
  """
  @spec new(%{}) :: %Skema.Result{}
  def new(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Put error to result.
  """
  @spec put_error(%Skema.Result{}, field :: atom, error :: String.t()) :: %Skema.Result{}
  def put_error(result, field, error) do
    errors =
      case get_error(result, field) do
        nil -> error
        errors -> [error | errors]
      end

    %Skema.Result{result | errors: Map.put(result.errors, field, errors), valid?: false}
  end

  @doc """
  Put valid data to result.
  """
  @spec put_data(%Skema.Result{}, field :: atom, value :: any) :: %Skema.Result{}
  def put_data(result, field, value) do
    %Skema.Result{result | valid_data: Map.put(result.valid_data, field, value)}
  end

  @doc """
  Get error from result for given field.
  """
  @spec get_error(%Skema.Result{}, field :: atom) :: String.t() | nil
  def get_error(result, field) do
    Map.get(result.errors, field)
  end
end
