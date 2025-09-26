defmodule Skema.JsonSchema.Converter.FromSkemaTest do
  use ExUnit.Case, async: true

  alias Skema.JsonSchema

  describe "from_schema/2 - basic types" do
    test "converts string type" do
      schema = %{name: [type: :string]}

      result = JsonSchema.from_schema(schema)

      assert result["properties"]["name"] == %{"type" => "string"}
    end

    test "converts integer type" do
      schema = %{age: [type: :integer]}

      result = JsonSchema.from_schema(schema)

      assert result["properties"]["age"] == %{"type" => "integer"}
    end

    test "converts float and number types" do
      schema = %{
        score: [type: :float],
        rating: [type: :number]
      }

      result = JsonSchema.from_schema(schema)

      assert result["properties"]["score"] == %{"type" => "number"}
      assert result["properties"]["rating"] == %{"type" => "number"}
    end

    test "converts boolean type" do
      schema = %{active: [type: :boolean]}

      result = JsonSchema.from_schema(schema)

      assert result["properties"]["active"] == %{"type" => "boolean"}
    end

    test "converts atom type to string" do
      schema = %{status: [type: :atom]}

      result = JsonSchema.from_schema(schema)

      assert result["properties"]["status"] == %{"type" => "string"}
    end

    test "converts map type to object" do
      schema = %{metadata: [type: :map]}

      result = JsonSchema.from_schema(schema)

      assert result["properties"]["metadata"] == %{"type" => "object"}
    end

    test "converts typed array" do
      schema = %{
        tags: [type: {:array, :string}],
        numbers: [type: {:array, :integer}]
      }

      result = JsonSchema.from_schema(schema)

      assert result["properties"]["tags"] == %{
               "type" => "array",
               "items" => %{"type" => "string"}
             }

      assert result["properties"]["numbers"] == %{
               "type" => "array",
               "items" => %{"type" => "integer"}
             }
    end

    test "omits type for :any" do
      schema = %{anything: [type: :any]}

      result = JsonSchema.from_schema(schema)

      assert result["properties"]["anything"] == %{}
    end
  end

  describe "from_schema/2 - date/time types" do
    test "converts date/time types with proper formats" do
      schema = %{
        birth_date: [type: :date],
        meeting_time: [type: :time],
        created_at: [type: :datetime],
        updated_at: [type: :utc_datetime],
        scheduled_at: [type: :naive_datetime]
      }

      result = JsonSchema.from_schema(schema)

      assert result["properties"]["birth_date"] == %{"type" => "string", "format" => "date"}
      assert result["properties"]["meeting_time"] == %{"type" => "string", "format" => "time"}
      assert result["properties"]["created_at"] == %{"type" => "string", "format" => "date-time"}
      assert result["properties"]["updated_at"] == %{"type" => "string", "format" => "date-time"}
      assert result["properties"]["scheduled_at"] == %{"type" => "string", "format" => "date-time"}
    end
  end

  describe "from_schema/2 - required fields" do
    test "marks required fields correctly" do
      schema = %{
        name: [type: :string, required: true],
        email: [type: :string, required: true],
        age: [type: :integer]
      }

      result = JsonSchema.from_schema(schema)

      assert Enum.sort(result["required"]) == ["email", "name"]
    end

    test "omits required array when no required fields" do
      schema = %{
        name: [type: :string],
        age: [type: :integer]
      }

      result = JsonSchema.from_schema(schema)

      refute Map.has_key?(result, "required")
    end
  end

  describe "from_schema/2 - validations" do
    test "converts string length constraints" do
      schema = %{
        username: [type: :string, length: [min: 3, max: 20]],
        code: [type: :string, length: [equal_to: 6]]
      }

      result = JsonSchema.from_schema(schema)

      assert result["properties"]["username"] == %{
               "type" => "string",
               "minLength" => 3,
               "maxLength" => 20
             }

      assert result["properties"]["code"] == %{
               "type" => "string",
               "minLength" => 6,
               "maxLength" => 6
             }
    end

    test "converts array length constraints" do
      schema = %{
        tags: [type: {:array, :string}, length: [min: 1, max: 5]],
        coordinates: [type: {:array, :float}, length: [equal_to: 2]]
      }

      result = JsonSchema.from_schema(schema)

      assert result["properties"]["tags"] == %{
               "type" => "array",
               "items" => %{"type" => "string"},
               "minItems" => 1,
               "maxItems" => 5
             }

      assert result["properties"]["coordinates"] == %{
               "type" => "array",
               "items" => %{"type" => "number"},
               "minItems" => 2,
               "maxItems" => 2
             }
    end

    test "converts number constraints" do
      schema = %{
        age: [type: :integer, number: [min: 0, max: 150]],
        score: [type: :float, number: [greater_than: 0, less_than: 100]],
        count: [type: :integer, number: [equal_to: 42]]
      }

      result = JsonSchema.from_schema(schema)

      assert result["properties"]["age"] == %{
               "type" => "integer",
               "minimum" => 0,
               "maximum" => 150
             }

      assert result["properties"]["score"] == %{
               "type" => "number",
               "minimum" => 0,
               "maximum" => 100,
               "exclusiveMinimum" => true,
               "exclusiveMaximum" => true
             }

      assert result["properties"]["count"] == %{
               "type" => "integer",
               "const" => 42
             }
    end

    test "converts format regex constraints" do
      schema = %{
        email: [type: :string, format: ~r/.+@.+\..+/],
        phone: [type: :string, format: ~r/^\d{10}$/]
      }

      result = JsonSchema.from_schema(schema)

      assert result["properties"]["email"] == %{
               "type" => "string",
               "pattern" => ".+@.+\\..+"
             }

      assert result["properties"]["phone"] == %{
               "type" => "string",
               "pattern" => "^\\d{10}$"
             }
    end

    test "converts pattern constraints (alias for format)" do
      schema = %{
        username: [type: :string, pattern: ~r/^[a-zA-Z0-9_]+$/],
        code: [type: :string, pattern: "^[A-Z]{3}\\d{3}$"]
      }

      result = JsonSchema.from_schema(schema)

      assert result["properties"]["username"] == %{
               "type" => "string",
               "pattern" => "^[a-zA-Z0-9_]+$"
             }

      assert result["properties"]["code"] == %{
               "type" => "string",
               "pattern" => "^[A-Z]{3}\\d{3}$"
             }
    end

    test "format takes precedence over pattern when both are present" do
      schema = %{
        field: [type: :string, format: ~r/format_pattern/, pattern: ~r/pattern_value/]
      }

      result = JsonSchema.from_schema(schema)

      assert result["properties"]["field"] == %{
               "type" => "string",
               "pattern" => "format_pattern"
             }
    end

    test "converts inclusion constraints" do
      schema = %{
        status: [type: :string, in: ["active", "inactive", "pending"]],
        role: [type: :string, not_in: ["admin", "super_admin"]]
      }

      result = JsonSchema.from_schema(schema)

      assert result["properties"]["status"] == %{
               "type" => "string",
               "enum" => ["active", "inactive", "pending"]
             }

      assert result["properties"]["role"] == %{
               "type" => "string",
               "not" => %{"enum" => ["admin", "super_admin"]}
             }
    end
  end

  describe "from_schema/2 - documentation" do
    test "converts doc field to description" do
      schema = %{
        name: [type: :string, doc: "The user's full name"],
        age: [type: :integer, doc: "Age in years"],
        email: [type: :string, doc: "Contact email address"]
      }

      result = JsonSchema.from_schema(schema)

      assert result["properties"]["name"] == %{
        "type" => "string",
        "description" => "The user's full name"
      }

      assert result["properties"]["age"] == %{
        "type" => "integer",
        "description" => "Age in years"
      }

      assert result["properties"]["email"] == %{
        "type" => "string",
        "description" => "Contact email address"
      }
    end

    test "handles fields without doc" do
      schema = %{
        name: [type: :string, doc: "Has documentation"],
        age: [type: :integer]  # No doc field
      }

      result = JsonSchema.from_schema(schema)

      assert result["properties"]["name"]["description"] == "Has documentation"
      refute Map.has_key?(result["properties"]["age"], "description")
    end
  end

  describe "from_schema/2 - default values" do
    test "includes default values" do
      schema = %{
        active: [type: :boolean, default: true],
        count: [type: :integer, default: 0],
        tags: [type: {:array, :string}, default: []]
      }

      result = JsonSchema.from_schema(schema)

      assert result["properties"]["active"] == %{
               "type" => "boolean",
               "default" => true
             }

      assert result["properties"]["count"] == %{
               "type" => "integer",
               "default" => 0
             }

      assert result["properties"]["tags"] == %{
               "type" => "array",
               "items" => %{"type" => "string"},
               "default" => []
             }
    end
  end

  describe "from_schema/2 - nested schemas" do
    test "converts nested schemas" do
      schema = %{
        profile: %{
          bio: [type: :string, length: [max: 500]],
          website: [type: :string, format: ~r/^https?:\/\/.+/]
        }
      }

      result = JsonSchema.from_schema(schema)

      assert result["properties"]["profile"] == %{
               "type" => "object",
               "properties" => %{
                 "bio" => %{
                   "type" => "string",
                   "maxLength" => 500
                 },
                 "website" => %{
                   "type" => "string",
                   "pattern" => "^https?://.+"
                 }
               }
             }
    end

    test "handles nested required fields" do
      schema = %{
        profile: %{
          name: [type: :string, required: true],
          bio: [type: :string]
        }
      }

      result = JsonSchema.from_schema(schema)

      assert result["properties"]["profile"]["required"] == ["name"]
    end
  end

  describe "from_schema/2 - options" do
    test "includes schema metadata with options" do
      schema = %{name: [type: :string]}

      result =
        JsonSchema.from_schema(schema,
          title: "User Schema",
          description: "Schema for user validation",
          schema_version: "https://json-schema.org/draft/2019-09/schema"
        )

      assert result["$schema"] == "https://json-schema.org/draft/2019-09/schema"
      assert result["title"] == "User Schema"
      assert result["description"] == "Schema for user validation"
    end
  end
end