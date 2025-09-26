defmodule Skema.JsonSchema.Converter.ToSkema do
  @moduledoc """
  Converts JSON Schema format to Skema schema maps.
  """

  require Logger

  @doc """
  Converts JSON Schema properties to a Skema schema map.

  ## Options
  - `atom_keys` - Convert field names to atoms (default: false, uses strings for security)
  - `strict` - When false, skip unsupported features instead of raising (default: false)
  - `default_type` - Default type when type is not specified (default: :any)
  """
  def convert_properties_to_schema(properties, required_fields, strict, default_type, atom_keys) do
    Enum.reduce(properties, %{}, fn {field_name, field_schema}, acc ->
      field_key = if atom_keys, do: String.to_atom(field_name), else: field_name
      is_required = field_name in required_fields

      field_def = convert_json_field_to_skema(field_schema, is_required, strict, default_type, atom_keys)
      Map.put(acc, field_key, field_def)
    end)
  end

  @doc """
  Converts a single JSON Schema field to Skema field definition.
  """
  def convert_json_field_to_skema(field_schema, is_required, strict, default_type, atom_keys) do
    type = convert_json_type_to_skema(field_schema, default_type, atom_keys, strict)
    default = Map.get(field_schema, "default")

    # If type is already a nested schema (map), return it directly
    if is_map(type) do
      type
    else
      field_def = [type: type]
      field_def = if is_required, do: Keyword.put(field_def, :required, true), else: field_def
      field_def = if default != nil, do: Keyword.put(field_def, :default, default), else: field_def

      # Add doc field from description
      description = Map.get(field_schema, "description")
      field_def = if description != nil, do: Keyword.put(field_def, :doc, description), else: field_def

      field_def
      |> add_skema_length_constraints(field_schema)
      |> add_skema_number_constraints(field_schema)
      |> add_skema_format_constraints(field_schema)
      |> add_skema_inclusion_constraints(field_schema)
    end
  end

  # Type conversion from JSON Schema to Skema
  defp convert_json_type_to_skema(field_schema, default_type, atom_keys, strict) do
    case Map.get(field_schema, "type") do
      "string" ->
        case Map.get(field_schema, "format") do
          "date" -> :date
          "time" -> :time
          "date-time" -> :datetime
          _ -> :string
        end

      "integer" ->
        :integer

      "number" ->
        :float

      "boolean" ->
        :boolean

      "object" ->
        case Map.get(field_schema, "properties") do
          nil -> :map
          properties ->
            required = Map.get(field_schema, "required", [])
            convert_properties_to_schema(properties, required, strict, default_type, atom_keys)
        end

      "array" ->
        case Map.get(field_schema, "items") do
          # Default to array of default_type when items not specified
          nil -> {:array, default_type}
          items -> {:array, convert_json_type_to_skema(items, default_type, atom_keys, strict)}
        end

      nil ->
        if strict do
          raise ArgumentError, "JSON Schema field missing required 'type' property: #{inspect(field_schema)}"
        else
          Logger.warning("JSON Schema field missing 'type' property: #{inspect(field_schema)}. Defaulting to #{inspect(default_type)}.")
          default_type
        end

      unknown_type ->
        if strict do
          raise ArgumentError, "Unknown JSON Schema type '#{unknown_type}': #{inspect(field_schema)}"
        else
          Logger.warning("Unknown JSON Schema type '#{unknown_type}' in field #{inspect(field_schema)}. Defaulting to #{inspect(default_type)}.")
          default_type
        end
    end
  end

  # Add Skema constraints from JSON Schema properties
  defp add_skema_length_constraints(field_def, field_schema) do
    min_length = Map.get(field_schema, "minLength") || Map.get(field_schema, "minItems")
    max_length = Map.get(field_schema, "maxLength") || Map.get(field_schema, "maxItems")

    cond do
      min_length && max_length && min_length == max_length ->
        Keyword.put(field_def, :length, equal_to: min_length)

      min_length || max_length ->
        length_opts = []
        length_opts = if min_length, do: Keyword.put(length_opts, :min, min_length), else: length_opts
        length_opts = if max_length, do: Keyword.put(length_opts, :max, max_length), else: length_opts
        Keyword.put(field_def, :length, length_opts)

      true ->
        field_def
    end
  end

  defp add_skema_number_constraints(field_def, field_schema) do
    minimum = Map.get(field_schema, "minimum")
    maximum = Map.get(field_schema, "maximum")
    exclusive_min = Map.get(field_schema, "exclusiveMinimum", false)
    exclusive_max = Map.get(field_schema, "exclusiveMaximum", false)
    const = Map.get(field_schema, "const")

    cond do
      const ->
        Keyword.put(field_def, :in, [const])

      minimum || maximum ->
        number_opts = []

        number_opts =
          cond do
            minimum && exclusive_min ->
              Keyword.put(number_opts, :greater_than, minimum)

            minimum ->
              Keyword.put(number_opts, :min, minimum)

            true ->
              number_opts
          end

        number_opts =
          cond do
            maximum && exclusive_max ->
              Keyword.put(number_opts, :less_than, maximum)

            maximum ->
              Keyword.put(number_opts, :max, maximum)

            true ->
              number_opts
          end

        Keyword.put(field_def, :number, number_opts)

      true ->
        field_def
    end
  end

  defp add_skema_format_constraints(field_def, field_schema) do
    case Map.get(field_schema, "pattern") do
      nil -> field_def
      # Pass pattern string directly to Valdi - let it handle compilation
      pattern -> Keyword.put(field_def, :format, pattern)
    end
  end

  defp add_skema_inclusion_constraints(field_def, field_schema) do
    field_def =
      case Map.get(field_schema, "enum") do
        nil -> field_def
        values when is_list(values) -> Keyword.put(field_def, :in, values)
        _ -> field_def
      end

    case Map.get(field_schema, "not") do
      %{"enum" => values} when is_list(values) ->
        Keyword.put(field_def, :not_in, values)

      _ ->
        field_def
    end
  end
end