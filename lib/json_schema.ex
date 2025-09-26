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
        name: [type: :string, required: true, length: [min: 2, max: 50], doc: "User's full name"],
        age: [type: :integer, number: [min: 0, max: 150], doc: "Age in years"],
        tags: [type: {:array, :string}]
      }

      json_schema = Skema.JsonSchema.from_schema(schema)

      # JSON Schema to Skema
      json_schema = %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string", "minLength" => 2, "maxLength" => 50, "description" => "User's full name"},
          "age" => %{"type" => "integer", "minimum" => 0, "maximum" => 150, "description" => "Age in years"},
          "tags" => %{"type" => "array", "items" => %{"type" => "string"}}
        },
        "required" => ["name"]
      }

      skema_schema = Skema.JsonSchema.to_schema(json_schema)
  """

  alias Skema.JsonSchema.Converter.FromSkema
  alias Skema.JsonSchema.Converter.ToSkema

  @type schema_opts :: [
          schema_version: String.t(),
          title: String.t(),
          description: String.t(),
          default_type: atom(),
          strict: boolean(),
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

      schema = %{
        name: [type: :string, required: true],
        age: [type: :integer, number: [min: 0]]
      }

      json_schema = Skema.JsonSchema.from_schema(schema, title: "User Schema")
  """
  @spec from_schema(map(), schema_opts()) :: map()
  def from_schema(schema, opts \\ []) when is_map(schema) do
    schema_version = Keyword.get(opts, :schema_version, @default_schema_version)
    title = Keyword.get(opts, :title)
    description = Keyword.get(opts, :description)

    {properties, required_fields} = FromSkema.convert_schema_to_properties(schema)

    json_schema = %{
      "$schema" => schema_version,
      "type" => "object",
      "properties" => properties
    }

    json_schema = if required_fields != [], do: Map.put(json_schema, "required", required_fields), else: json_schema
    json_schema = if title, do: Map.put(json_schema, "title", title), else: json_schema
    json_schema = if description, do: Map.put(json_schema, "description", description), else: json_schema

    json_schema
  end

  @doc """
  Converts a JSON Schema document to a Skema schema map.

  ## Options

  - `:strict` - When false, skip unsupported features instead of raising (default: false)
  - `:default_type` - Default type when type is not specified (default: :any)
  - `:atom_keys` - Convert field names to atoms (default: false, uses strings for security)

  ## Examples

      json_schema = %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"},
          "age" => %{"type" => "integer", "minimum" => 0}
        },
        "required" => ["name"]
      }

      skema_schema = Skema.JsonSchema.to_schema(json_schema)

  ## Security Note

  By default, field names are converted to strings to prevent atom exhaustion attacks.
  Only use `atom_keys: true` with trusted input where field names are known and limited.
  """
  @spec to_schema(map(), schema_opts()) :: map()
  def to_schema(json_schema, opts \\ []) when is_map(json_schema) do
    strict = Keyword.get(opts, :strict, false)
    default_type = Keyword.get(opts, :default_type, :any)
    atom_keys = Keyword.get(opts, :atom_keys, false)

    properties = Map.get(json_schema, "properties", %{})
    required_fields = Map.get(json_schema, "required", [])

    ToSkema.convert_properties_to_schema(properties, required_fields, strict, default_type, atom_keys)
  end
end