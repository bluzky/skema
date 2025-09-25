defmodule Skema.JsonSchema do
  @moduledoc """
  Utilities for converting between Skema schema maps and JSON Schema format.

  This module provides bidirectional conversion between Skema schema definitions
  and JSON Schema documents, enabling interoperability with JSON Schema-based
  systems and tools.

  ## Features

  - Convert Skema schema maps to JSON Schema format
  - Convert JSON Schema documents to Skema schema maps
  - Support for common types, validations, and constraints
  - Configurable schema metadata (title, description, version)

  ## Limitations

  - Only supports schema maps, not schema modules (defschema)
  - Arrays must always specify item type as `{:array, item_type}` - generic `:array` type is not supported
  - Some advanced features may not have direct equivalents
  - Custom functions and transformations are not supported

  ## Security

  By default, JSON Schema field names are converted to strings to prevent atom exhaustion attacks.
  Use the `:atom_keys` option only with trusted input where field names are known and limited.

  ## Examples

      # Skema to JSON Schema
      schema = %{
        name: [type: :string, required: true, length: [min: 2, max: 50]],
        age: [type: :integer, number: [min: 0, max: 150]],
        tags: [type: {:array, :string}]
      }

      json_schema = Skema.JsonSchema.from_schema(schema)

      # JSON Schema to Skema
      json_schema = %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string", "minLength" => 2, "maxLength" => 50},
          "age" => %{"type" => "integer", "minimum" => 0, "maximum" => 150},
          "tags" => %{"type" => "array", "items" => %{"type" => "string"}}
        },
        "required" => ["name"]
      }

      skema_schema = Skema.JsonSchema.to_schema(json_schema)
  """

  @type skema_schema :: map()
  @type json_schema :: map()
  @type conversion_options :: [
          schema_version: String.t(),
          title: String.t(),
          description: String.t(),
          strict: boolean(),
          default_type: atom(),
          atom_keys: boolean()
        ]

  @default_schema_version "https://json-schema.org/draft/2020-12/schema"

  @doc """
  Converts a Skema schema map to JSON Schema format.

  ## Options

  - `:schema_version` - JSON Schema version URI (default: "#{@default_schema_version}")
  - `:title` - Schema title
  - `:description` - Schema description

  ## Examples

      iex> schema = %{name: [type: :string, required: true]}
      iex> Skema.JsonSchema.from_schema(schema)
      %{
        "$schema" => "https://json-schema.org/draft/2020-12/schema",
        "type" => "object",
        "properties" => %{"name" => %{"type" => "string"}},
        "required" => ["name"]
      }

      iex> schema = %{age: [type: :integer, number: [min: 0, max: 150]]}
      iex> Skema.JsonSchema.from_schema(schema, title: "Person Schema")
      %{
        "$schema" => "https://json-schema.org/draft/2020-12/schema",
        "title" => "Person Schema",
        "type" => "object",
        "properties" => %{"age" => %{"type" => "integer", "minimum" => 0, "maximum" => 150}}
      }
  """
  @spec from_schema(skema_schema(), conversion_options()) :: json_schema()
  def from_schema(schema, opts \\ []) when is_map(schema) do
    schema_version = Keyword.get(opts, :schema_version, @default_schema_version)
    title = Keyword.get(opts, :title)
    description = Keyword.get(opts, :description)

    {properties, required_fields} = convert_schema_to_properties(schema)

    json_schema = %{
      "$schema" => schema_version,
      "type" => "object",
      "properties" => properties
    }

    json_schema =
      if required_fields != [] do
        Map.put(json_schema, "required", required_fields)
      else
        json_schema
      end

    json_schema =
      if title do
        Map.put(json_schema, "title", title)
      else
        json_schema
      end

    if description do
      Map.put(json_schema, "description", description)
    else
      json_schema
    end
  end

  @doc """
  Converts a JSON Schema document to a Skema schema map.

  ## Options

  - `:strict` - When false, skip unsupported features instead of raising (default: false)
  - `:default_type` - Default type when type is not specified (default: :any)
  - `:atom_keys` - Convert field names to atoms (default: false, uses strings for security)

  ## Examples

      iex> json_schema = %{
      ...>   "type" => "object",
      ...>   "properties" => %{"name" => %{"type" => "string"}},
      ...>   "required" => ["name"]
      ...> }
      iex> Skema.JsonSchema.to_schema(json_schema)
      %{"name" => [type: :string, required: true]}

      iex> Skema.JsonSchema.to_schema(json_schema, atom_keys: true)
      %{name: [type: :string, required: true]}

      iex> json_schema = %{
      ...>   "type" => "object",
      ...>   "properties" => %{
      ...>     "age" => %{"type" => "integer", "minimum" => 0, "maximum" => 150}
      ...>   }
      ...> }
      iex> Skema.JsonSchema.to_schema(json_schema)
      %{"age" => [type: :integer, number: [min: 0, max: 150]]}
  """
  @spec to_schema(json_schema(), conversion_options()) :: skema_schema()
  def to_schema(json_schema, opts \\ []) when is_map(json_schema) do
    strict = Keyword.get(opts, :strict, false)
    default_type = Keyword.get(opts, :default_type, :any)
    atom_keys = Keyword.get(opts, :atom_keys, false)

    properties = Map.get(json_schema, "properties", %{})
    required_fields = Map.get(json_schema, "required", [])

    convert_properties_to_schema(properties, required_fields, strict, default_type, atom_keys)
  end

  # Private functions for Skema to JSON Schema conversion

  defp convert_schema_to_properties(schema) do
    {properties, required_fields} =
      Enum.reduce(schema, {%{}, []}, fn {field_name, field_def}, {props, required} ->
        field_name_str = to_string(field_name)

        cond do
          is_map(field_def) ->
            # Nested schema
            {nested_props, nested_required} = convert_schema_to_properties(field_def)
            nested_schema = %{"type" => "object", "properties" => nested_props}

            nested_schema =
              if nested_required != [], do: Map.put(nested_schema, "required", nested_required), else: nested_schema

            {Map.put(props, field_name_str, nested_schema), required}

          is_list(field_def) ->
            # Field definition list
            {json_field, is_required} = convert_field_definition(field_def)
            new_required = if is_required, do: [field_name_str | required], else: required
            {Map.put(props, field_name_str, json_field), new_required}

          true ->
            # Simple type
            json_field = %{"type" => convert_type_to_json_schema(field_def)}
            {Map.put(props, field_name_str, json_field), required}
        end
      end)

    {properties, Enum.reverse(required_fields)}
  end

  defp convert_field_definition(field_def) do
    type = Keyword.get(field_def, :type, :any)
    required = Keyword.get(field_def, :required, false)
    default = Keyword.get(field_def, :default)

    json_field = %{"type" => convert_type_to_json_schema(type)}

    # Add default value if present
    json_field = if default != nil, do: Map.put(json_field, "default", default), else: json_field

    # Add type-specific properties
    json_field = add_type_properties(json_field, type, field_def)

    # Add validation constraints
    json_field = add_validation_constraints(json_field, field_def)

    {json_field, required}
  end

  defp convert_type_to_json_schema(:string), do: "string"
  defp convert_type_to_json_schema(:binary), do: "string"
  defp convert_type_to_json_schema(:integer), do: "integer"
  defp convert_type_to_json_schema(:float), do: "number"
  defp convert_type_to_json_schema(:number), do: "number"
  defp convert_type_to_json_schema(:boolean), do: "boolean"
  defp convert_type_to_json_schema(:atom), do: "string"
  defp convert_type_to_json_schema(:decimal), do: "number"
  defp convert_type_to_json_schema(:map), do: "object"
  # Note: :array and :list without item types are not supported in Skema
  # Arrays must always specify item type as {:array, item_type}
  defp convert_type_to_json_schema(:date), do: "string"
  defp convert_type_to_json_schema(:time), do: "string"
  defp convert_type_to_json_schema(:datetime), do: "string"
  defp convert_type_to_json_schema(:utc_datetime), do: "string"
  defp convert_type_to_json_schema(:naive_datetime), do: "string"
  defp convert_type_to_json_schema({:array, _item_type}), do: "array"
  defp convert_type_to_json_schema(_), do: nil

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
    items_schema = %{"type" => convert_type_to_json_schema(item_type)}
    items_schema = if items_schema["type"], do: items_schema, else: %{}
    Map.put(json_field, "items", items_schema)
  end

  defp add_type_properties(json_field, _type, _field_def) do
    # Remove type if it's nil (for :any type)
    if json_field["type"], do: json_field, else: Map.delete(json_field, "type")
  end

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

      length_opts ->
        json_field =
          case Keyword.get(length_opts, :min) do
            nil ->
              json_field

            min ->
              case json_field["type"] do
                "array" -> Map.put(json_field, "minItems", min)
                "string" -> Map.put(json_field, "minLength", min)
                _ -> json_field
              end
          end

        json_field =
          case Keyword.get(length_opts, :max) do
            nil ->
              json_field

            max ->
              case json_field["type"] do
                "array" -> Map.put(json_field, "maxItems", max)
                "string" -> Map.put(json_field, "maxLength", max)
                _ -> json_field
              end
          end

        case Keyword.get(length_opts, :equal_to) do
          nil ->
            json_field

          equal_to ->
            case json_field["type"] do
              "array" ->
                json_field
                |> Map.put("minItems", equal_to)
                |> Map.put("maxItems", equal_to)

              "string" ->
                json_field
                |> Map.put("minLength", equal_to)
                |> Map.put("maxLength", equal_to)

              _ ->
                json_field
            end
        end
    end
  end

  defp add_number_constraints(json_field, field_def) do
    case Keyword.get(field_def, :number) do
      nil ->
        json_field

      number_opts ->
        json_field =
          case Keyword.get(number_opts, :min) do
            nil -> json_field
            min -> Map.put(json_field, "minimum", min)
          end

        json_field =
          case Keyword.get(number_opts, :max) do
            nil -> json_field
            max -> Map.put(json_field, "maximum", max)
          end

        json_field =
          case Keyword.get(number_opts, :greater_than) do
            nil ->
              json_field

            gt ->
              json_field
              |> Map.put("minimum", gt)
              |> Map.put("exclusiveMinimum", true)
          end

        json_field =
          case Keyword.get(number_opts, :less_than) do
            nil ->
              json_field

            lt ->
              json_field
              |> Map.put("maximum", lt)
              |> Map.put("exclusiveMaximum", true)
          end

        case Keyword.get(number_opts, :equal_to) do
          nil -> json_field
          equal_to -> Map.put(json_field, "const", equal_to)
        end
    end
  end

  defp add_format_constraints(json_field, field_def) do
    case Keyword.get(field_def, :format) do
      nil -> json_field
      %Regex{} = regex -> Map.put(json_field, "pattern", Regex.source(regex))
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
      nil ->
        json_field

      values when is_list(values) ->
        Map.put(json_field, "not", %{"enum" => values})

      _ ->
        json_field
    end
  end

  # Private functions for JSON Schema to Skema conversion

  defp convert_properties_to_schema(properties, required_fields, strict, default_type, atom_keys) do
    Enum.reduce(properties, %{}, fn {field_name, field_schema}, acc ->
      field_key = if atom_keys, do: String.to_atom(field_name), else: field_name
      is_required = field_name in required_fields

      field_def = convert_json_field_to_skema(field_schema, is_required, strict, default_type, atom_keys)
      Map.put(acc, field_key, field_def)
    end)
  end

  defp convert_json_field_to_skema(field_schema, is_required, _strict, default_type, atom_keys) do
    type = convert_json_type_to_skema(field_schema, default_type, atom_keys)
    default = Map.get(field_schema, "default")

    # If type is already a nested schema (map), return it directly
    if is_map(type) do
      type
    else
      field_def = [type: type]
      field_def = if is_required, do: Keyword.put(field_def, :required, true), else: field_def
      field_def = if default != nil, do: Keyword.put(field_def, :default, default), else: field_def

      field_def
      |> add_skema_length_constraints(field_schema)
      |> add_skema_number_constraints(field_schema)
      |> add_skema_format_constraints(field_schema)
      |> add_skema_inclusion_constraints(field_schema)
    end
  end

  defp convert_json_type_to_skema(field_schema, default_type, atom_keys) do
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
          nil ->
            :map

          properties ->
            required = Map.get(field_schema, "required", [])
            convert_properties_to_schema(properties, required, false, default_type, atom_keys)
        end

      "array" ->
        case Map.get(field_schema, "items") do
          # Default to array of default_type when items not specified
          nil -> {:array, default_type}
          items -> {:array, convert_json_type_to_skema(items, default_type, atom_keys)}
        end

      nil ->
        default_type

      _ ->
        default_type
    end
  end

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
            minimum && exclusive_min -> Keyword.put(number_opts, :greater_than, minimum)
            minimum -> Keyword.put(number_opts, :min, minimum)
            true -> number_opts
          end

        number_opts =
          cond do
            maximum && exclusive_max -> Keyword.put(number_opts, :less_than, maximum)
            maximum -> Keyword.put(number_opts, :max, maximum)
            true -> number_opts
          end

        Keyword.put(field_def, :number, number_opts)

      true ->
        field_def
    end
  end

  defp add_skema_format_constraints(field_def, field_schema) do
    case Map.get(field_schema, "pattern") do
      nil ->
        field_def

      pattern ->
        case Regex.compile(pattern) do
          {:ok, regex} -> Keyword.put(field_def, :format, regex)
          {:error, _} -> field_def
        end
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
