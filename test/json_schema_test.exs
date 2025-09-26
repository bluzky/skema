defmodule Skema.JsonSchemaTest do
  use ExUnit.Case, async: true

  alias Skema.JsonSchema

  describe "main API integration" do
    test "from_schema/2 returns proper JSON Schema structure" do
      schema = %{name: [type: :string, required: true]}
      result = JsonSchema.from_schema(schema)

      # Verify top-level JSON Schema structure
      assert result["$schema"] == "https://json-schema.org/draft/2020-12/schema"
      assert result["type"] == "object"
      assert Map.has_key?(result, "properties")
      assert result["required"] == ["name"]
    end

    test "to_schema/2 returns proper Skema schema structure" do
      json_schema = %{
        "type" => "object",
        "properties" => %{"name" => %{"type" => "string"}},
        "required" => ["name"]
      }

      result = JsonSchema.to_schema(json_schema)

      # Verify it's a proper Skema schema map
      assert is_map(result)
      assert result["name"][:type] == :string
      assert result["name"][:required] == true
    end

    test "handles empty schema maps" do
      # Empty Skema schema
      empty_skema = %{}
      json_result = JsonSchema.from_schema(empty_skema)
      assert json_result["properties"] == %{}
      refute Map.has_key?(json_result, "required")

      # Empty JSON Schema
      empty_json = %{"type" => "object", "properties" => %{}}
      skema_result = JsonSchema.to_schema(empty_json)
      assert skema_result == %{}
    end
  end

  describe "bidirectional conversion integration" do
    test "complex schema converts back and forth preserving structure" do
      original_schema = %{
        name: [type: :string, required: true, length: [min: 2, max: 50]],
        age: [type: :integer, number: [min: 0, max: 150]],
        email: [type: :string, format: ~r/.+@.+\..+/],
        status: [type: :string, in: ["active", "inactive"], default: "active"],
        tags: [type: {:array, :string}, length: [max: 10], default: []],
        profile: %{
          bio: [type: :string, length: [max: 500]],
          website: [type: :string, format: ~r/^https?:\/\/.+/],
          social_links: [type: {:array, :string}, length: [max: 5]]
        },
        scores: [type: {:array, :integer}],
        metadata: [type: :map, default: %{}]
      }

      # Convert to JSON Schema and back
      json_schema = JsonSchema.from_schema(original_schema)
      converted_schema = JsonSchema.to_schema(json_schema)

      # Should preserve core structure and constraints
      assert converted_schema["name"][:type] == :string
      assert converted_schema["name"][:required] == true

      assert converted_schema["name"][:length] == [min: 2, max: 50] or
               converted_schema["name"][:length] == [max: 50, min: 2]

      assert converted_schema["age"][:type] == :integer

      assert converted_schema["age"][:number] == [min: 0, max: 150] or
               converted_schema["age"][:number] == [max: 150, min: 0]

      assert converted_schema["status"][:type] == :string
      assert converted_schema["status"][:in] == ["active", "inactive"]
      assert converted_schema["status"][:default] == "active"

      assert converted_schema["tags"][:type] == {:array, :string}
      assert converted_schema["tags"][:length] == [max: 10]
      assert converted_schema["tags"][:default] == []

      # Check nested schema
      assert is_map(converted_schema["profile"])
      assert converted_schema["profile"]["bio"][:type] == :string
      assert converted_schema["profile"]["bio"][:length] == [max: 500]
    end

    test "preserves documentation in round-trip conversion" do
      original_schema = %{
        name: [type: :string, required: true, doc: "User's full name"],
        age: [type: :integer, doc: "Age in years"],
        profile: %{
          bio: [type: :string, doc: "Short biography"]
        }
      }

      # Convert to JSON Schema and back
      json_schema = JsonSchema.from_schema(original_schema)
      converted_schema = JsonSchema.to_schema(json_schema)

      # Should preserve documentation
      assert converted_schema["name"][:doc] == "User's full name"
      assert converted_schema["age"][:doc] == "Age in years"
      assert converted_schema["profile"]["bio"][:doc] == "Short biography"
    end

    test "round-trip conversion with atom_keys option" do
      original_schema = %{
        user_name: [type: :string, required: true],
        user_age: [type: :integer]
      }

      # Convert to JSON Schema and back with atom_keys
      json_schema = JsonSchema.from_schema(original_schema)
      converted_schema = JsonSchema.to_schema(json_schema, atom_keys: true)

      # Should use atom keys
      assert converted_schema.user_name[:type] == :string
      assert converted_schema.user_name[:required] == true
      assert converted_schema.user_age[:type] == :integer
    end
  end

  describe "API options integration" do
    test "from_schema/2 with custom options" do
      schema = %{name: [type: :string]}

      result = JsonSchema.from_schema(schema,
        title: "User Schema",
        description: "Schema for user validation",
        schema_version: "https://json-schema.org/draft/2019-09/schema"
      )

      assert result["$schema"] == "https://json-schema.org/draft/2019-09/schema"
      assert result["title"] == "User Schema"
      assert result["description"] == "Schema for user validation"
    end

    test "to_schema/2 with all options combined" do
      json_schema = %{
        "type" => "object",
        "properties" => %{
          "unknown_field" => %{"type" => "unknown_type"},
          "valid_field" => %{"type" => "string"}
        }
      }

      # Test with strict: false, default_type, and atom_keys
      result = JsonSchema.to_schema(json_schema,
        strict: false,
        default_type: :binary,
        atom_keys: true
      )

      assert result.unknown_field[:type] == :binary  # Uses custom default_type
      assert result.valid_field[:type] == :string
    end
  end
end