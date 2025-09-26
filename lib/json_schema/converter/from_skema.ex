defmodule Skema.JsonSchema.Converter.FromSkema do
  @moduledoc """
  Converts Skema schema maps to JSON Schema format.

  ## Pattern Support

  Supports both `:format` and `:pattern` as aliases for regex pattern constraints.
  When both are present, `:format` takes precedence.

  ## Examples

      # Using :format (traditional)
      field: [type: :string, format: ~r/^[a-z]+$/]

      # Using :pattern (alias)
      field: [type: :string, pattern: ~r/^[a-z]+$/]

      # Both convert to JSON Schema "pattern" property
      %{"type" => "string", "pattern" => "^[a-z]+$"}
  """

  require Logger

  @doc """
  Converts a Skema schema map to JSON Schema properties format.

  Returns a tuple containing:
  - Properties map for JSON Schema "properties" field
  - Required fields list for JSON Schema "required" field
  """
  def convert_schema_to_properties(schema) do
    {properties, required_fields} =
      Enum.reduce(schema, {%{}, []}, fn {field_name, field_def}, {props, required} ->
        field_name_str = to_string(field_name)

        cond do
          is_map(field_def) ->
            # Nested schema
            {nested_props, nested_required} = convert_schema_to_properties(field_def)
            nested_schema = %{"type" => "object", "properties" => nested_props}
            nested_schema = if nested_required != [], do: Map.put(nested_schema, "required", nested_required), else: nested_schema
            {Map.put(props, field_name_str, nested_schema), required}

          is_list(field_def) ->
            # Field definition list
            {json_field, is_required} = convert_field_definition(field_def)
            new_required = if is_required, do: [field_name_str | required], else: required
            {Map.put(props, field_name_str, json_field), new_required}

          true ->
            # Simple type atom
            json_field = %{"type" => convert_type_to_json_schema(field_def)}
            {Map.put(props, field_name_str, json_field), required}
        end
      end)

    {properties, Enum.reverse(required_fields)}
  end

  @doc """
  Converts a Skema field definition (keyword list) to JSON Schema field format.

  Returns a tuple containing:
  - JSON field map
  - Boolean indicating if field is required
  """
  def convert_field_definition(field_def) do
    type = Keyword.get(field_def, :type, :any)
    required = Keyword.get(field_def, :required, false)
    default = Keyword.get(field_def, :default)

    json_field = case convert_type_to_json_schema(type) do
      nil -> %{}  # :any type should omit type property
      json_type -> %{"type" => json_type}
    end

    # Add default value if present
    json_field = if default != nil, do: Map.put(json_field, "default", default), else: json_field

    # Add doc field as description
    doc = Keyword.get(field_def, :doc)
    json_field = if doc != nil, do: Map.put(json_field, "description", doc), else: json_field

    json_field = add_type_properties(json_field, type, field_def)

    # Add validation constraints
    json_field = add_validation_constraints(json_field, field_def)

    {json_field, required}
  end

  # Type conversion functions
  defp convert_type_to_json_schema(:string), do: "string"
  defp convert_type_to_json_schema(:binary), do: "string"
  defp convert_type_to_json_schema(:integer), do: "integer"
  defp convert_type_to_json_schema(:float), do: "number"
  defp convert_type_to_json_schema(:number), do: "number"
  defp convert_type_to_json_schema(:boolean), do: "boolean"
  defp convert_type_to_json_schema(:atom), do: "string"
  defp convert_type_to_json_schema(:decimal), do: "number"
  defp convert_type_to_json_schema(:map), do: "object"
  defp convert_type_to_json_schema(:list), do: "array"
  defp convert_type_to_json_schema(:array), do: "array"
  # Date/time types
  defp convert_type_to_json_schema(:date), do: "string"
  defp convert_type_to_json_schema(:time), do: "string"
  defp convert_type_to_json_schema(:datetime), do: "string"
  defp convert_type_to_json_schema(:utc_datetime), do: "string"
  defp convert_type_to_json_schema(:naive_datetime), do: "string"
  defp convert_type_to_json_schema({:array, _item_type}), do: "array"
  defp convert_type_to_json_schema(:any), do: nil  # Special case: :any should omit type
  defp convert_type_to_json_schema(unknown_type) do
    Logger.warning("Unknown Skema type: #{inspect(unknown_type)}. Defaulting to string.")
    "string"
  end

  # Add type-specific properties (format, items, etc.)
  defp add_type_properties(json_field, :date, _field_def) do
    Map.put(json_field, "format", "date")
  end

  defp add_type_properties(json_field, :time, _field_def) do
    Map.put(json_field, "format", "time")
  end

  defp add_type_properties(json_field, :datetime, _field_def) do
    Map.put(json_field, "format", "date-time")
  end

  defp add_type_properties(json_field, :utc_datetime, _field_def) do
    Map.put(json_field, "format", "date-time")
  end

  defp add_type_properties(json_field, :naive_datetime, _field_def) do
    Map.put(json_field, "format", "date-time")
  end

  defp add_type_properties(json_field, {:array, item_type}, _field_def) do
    item_schema = case item_type do
      atom when is_atom(atom) -> %{"type" => convert_type_to_json_schema(atom)}
      other -> %{"type" => convert_type_to_json_schema(other)}
    end
    Map.put(json_field, "items", item_schema)
  end

  defp add_type_properties(json_field, _type, _field_def) do
    json_field
  end

  # Add validation constraints
  defp add_validation_constraints(json_field, field_def) do
    json_field
    |> add_length_constraints(field_def)
    |> add_number_constraints(field_def)
    |> add_format_constraints(field_def)
    |> add_inclusion_constraints(field_def)
  end

  defp add_length_constraints(json_field, field_def) do
    case Keyword.get(field_def, :length) do
      nil ->
        json_field

      length_opts when is_list(length_opts) ->
        min_length = Keyword.get(length_opts, :min)
        max_length = Keyword.get(length_opts, :max)
        equal_to = Keyword.get(length_opts, :equal_to)

        # Use appropriate length property names based on type
        {min_prop, max_prop} = case Map.get(json_field, "type") do
          "array" -> {"minItems", "maxItems"}
          _ -> {"minLength", "maxLength"}
        end

        cond do
          equal_to ->
            json_field
            |> Map.put(min_prop, equal_to)
            |> Map.put(max_prop, equal_to)

          min_length && max_length ->
            json_field
            |> Map.put(min_prop, min_length)
            |> Map.put(max_prop, max_length)

          min_length ->
            Map.put(json_field, min_prop, min_length)

          max_length ->
            Map.put(json_field, max_prop, max_length)

          true ->
            json_field
        end

      # Handle direct integer value for array length
      length_value when is_integer(length_value) ->
        {min_prop, max_prop} = case Map.get(json_field, "type") do
          "array" -> {"minItems", "maxItems"}
          _ -> {"minLength", "maxLength"}
        end

        json_field
        |> Map.put(min_prop, length_value)
        |> Map.put(max_prop, length_value)

      _ ->
        json_field
    end
  end

  defp add_number_constraints(json_field, field_def) do
    case Keyword.get(field_def, :number) do
      nil ->
        json_field

      number_opts when is_list(number_opts) ->
        min = Keyword.get(number_opts, :min)
        max = Keyword.get(number_opts, :max)
        greater_than = Keyword.get(number_opts, :greater_than)
        less_than = Keyword.get(number_opts, :less_than)
        equal_to = Keyword.get(number_opts, :equal_to)

        cond do
          equal_to ->
            Map.put(json_field, "const", equal_to)

          true ->
            json_field =
              cond do
                greater_than ->
                  json_field
                  |> Map.put("minimum", greater_than)
                  |> Map.put("exclusiveMinimum", true)

                min ->
                  Map.put(json_field, "minimum", min)

                true ->
                  json_field
              end

            cond do
              less_than ->
                json_field
                |> Map.put("maximum", less_than)
                |> Map.put("exclusiveMaximum", true)

              max ->
                Map.put(json_field, "maximum", max)

              true ->
                json_field
            end
        end

      _ ->
        json_field
    end
  end

  defp add_format_constraints(json_field, field_def) do
    # Support both :format and :pattern as aliases
    pattern_value = Keyword.get(field_def, :format) || Keyword.get(field_def, :pattern)

    case pattern_value do
      nil -> json_field
      %Regex{} = regex -> Map.put(json_field, "pattern", Regex.source(regex))
      pattern when is_binary(pattern) -> Map.put(json_field, "pattern", pattern)
      _ -> json_field
    end
  end

  defp add_inclusion_constraints(json_field, field_def) do
    json_field =
      case Keyword.get(field_def, :in) do
        nil -> json_field
        values when is_list(values) -> Map.put(json_field, "enum", values)
        _ -> json_field
      end

    case Keyword.get(field_def, :not_in) do
      nil -> json_field
      values when is_list(values) -> Map.put(json_field, "not", %{"enum" => values})
      _ -> json_field
    end
  end
end