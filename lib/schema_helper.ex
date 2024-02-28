defmodule Skema.SchemaHelper do
  @moduledoc false

  @spec expand(map()) :: map()
  def expand(schema) do
    Map.new(schema, &expand_field/1)
  end

  defp expand_field({field, type}) when is_atom(type) or is_map(type) do
    expand_field({field, [type: type]})
  end

  defp expand_field({field, {:array, type}}) do
    {field, [type: {:array, expand_type(type)}]}
  end

  defp expand_field({field, attrs}) do
    attrs =
      if attrs[:type] do
        Keyword.put(attrs, :type, expand_type(attrs[:type]))
      else
        attrs
      end

    attrs = Keyword.put(attrs, :default, expand_default(attrs[:default]))

    {field, attrs}
  end

  # expand nested schema
  defp expand_type(%{} = type) do
    expand(type)
  end

  defp expand_type(type), do: type

  defp expand_default(default) when is_function(default, 0) do
    default.()
  end

  defp expand_default(default), do: default
end
