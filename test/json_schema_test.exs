defmodule Skema.JsonSchemaTest do
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

  describe "to_schema/2 - basic types" do
    test "converts string type" do
      json_schema = %{
        "type" => "object",
        "properties" => %{"name" => %{"type" => "string"}}
      }

      result = JsonSchema.to_schema(json_schema)

      assert result == %{"name" => [type: :string]}
    end

    test "converts integer type" do
      json_schema = %{
        "type" => "object",
        "properties" => %{"age" => %{"type" => "integer"}}
      }

      result = JsonSchema.to_schema(json_schema)

      assert result == %{"age" => [type: :integer]}
    end

    test "converts number type to float" do
      json_schema = %{
        "type" => "object",
        "properties" => %{"score" => %{"type" => "number"}}
      }

      result = JsonSchema.to_schema(json_schema)

      assert result == %{"score" => [type: :float]}
    end

    test "converts boolean type" do
      json_schema = %{
        "type" => "object",
        "properties" => %{"active" => %{"type" => "boolean"}}
      }

      result = JsonSchema.to_schema(json_schema)

      assert result == %{"active" => [type: :boolean]}
    end

    test "converts object type to map" do
      json_schema = %{
        "type" => "object",
        "properties" => %{"metadata" => %{"type" => "object"}}
      }

      result = JsonSchema.to_schema(json_schema)

      assert result == %{"metadata" => [type: :map]}
    end

    test "converts array types" do
      json_schema = %{
        "type" => "object",
        "properties" => %{
          "untyped_array" => %{"type" => "array"},
          "typed_array" => %{
            "type" => "array",
            "items" => %{"type" => "string"}
          }
        }
      }

      result = JsonSchema.to_schema(json_schema)

      assert result == %{
               # Default to array of :any
               "untyped_array" => [type: {:array, :any}],
               "typed_array" => [type: {:array, :string}]
             }
    end

    test "defaults to :any for missing or unknown types" do
      json_schema = %{
        "type" => "object",
        "properties" => %{
          "unknown" => %{"type" => "unknown"},
          "missing" => %{}
        }
      }

      result = JsonSchema.to_schema(json_schema)

      assert result == %{
               "unknown" => [type: :any],
               "missing" => [type: :any]
             }
    end
  end

  describe "to_schema/2 - string formats" do
    test "converts string format types" do
      json_schema = %{
        "type" => "object",
        "properties" => %{
          "birth_date" => %{"type" => "string", "format" => "date"},
          "meeting_time" => %{"type" => "string", "format" => "time"},
          "created_at" => %{"type" => "string", "format" => "date-time"}
        }
      }

      result = JsonSchema.to_schema(json_schema)

      assert result == %{
               "birth_date" => [type: :date],
               "meeting_time" => [type: :time],
               "created_at" => [type: :datetime]
             }
    end
  end

  describe "to_schema/2 - required fields" do
    test "marks required fields correctly" do
      json_schema = %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"},
          "email" => %{"type" => "string"},
          "age" => %{"type" => "integer"}
        },
        "required" => ["name", "email"]
      }

      result = JsonSchema.to_schema(json_schema)

      assert result["name"][:type] == :string
      assert result["name"][:required] == true
      assert result["email"][:type] == :string
      assert result["email"][:required] == true
      assert result["age"][:type] == :integer
      refute result["age"][:required]
    end

    test "handles no required fields" do
      json_schema = %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"},
          "age" => %{"type" => "integer"}
        }
      }

      result = JsonSchema.to_schema(json_schema)

      assert result == %{
               "name" => [type: :string],
               "age" => [type: :integer]
             }
    end
  end

  describe "to_schema/2 - constraints" do
    test "converts string length constraints" do
      json_schema = %{
        "type" => "object",
        "properties" => %{
          "username" => %{
            "type" => "string",
            "minLength" => 3,
            "maxLength" => 20
          },
          "code" => %{
            "type" => "string",
            "minLength" => 6,
            "maxLength" => 6
          }
        }
      }

      result = JsonSchema.to_schema(json_schema)

      assert result["username"][:type] == :string
      assert result["username"][:length] == [min: 3, max: 20] or result["username"][:length] == [max: 20, min: 3]
      assert result["code"][:type] == :string
      assert result["code"][:length] == [equal_to: 6]
    end

    test "converts array length constraints" do
      json_schema = %{
        "type" => "object",
        "properties" => %{
          "tags" => %{
            "type" => "array",
            "items" => %{"type" => "string"},
            "minItems" => 1,
            "maxItems" => 5
          },
          "coordinates" => %{
            "type" => "array",
            "items" => %{"type" => "number"},
            "minItems" => 2,
            "maxItems" => 2
          }
        }
      }

      result = JsonSchema.to_schema(json_schema)

      assert result["tags"][:type] == {:array, :string}
      assert result["tags"][:length] == [min: 1, max: 5] or result["tags"][:length] == [max: 5, min: 1]
      assert result["coordinates"][:type] == {:array, :float}
      assert result["coordinates"][:length] == [equal_to: 2]
    end

    test "converts number constraints" do
      json_schema = %{
        "type" => "object",
        "properties" => %{
          "age" => %{
            "type" => "integer",
            "minimum" => 0,
            "maximum" => 150
          },
          "score" => %{
            "type" => "number",
            "minimum" => 0,
            "maximum" => 100,
            "exclusiveMinimum" => true,
            "exclusiveMaximum" => true
          },
          "count" => %{
            "type" => "integer",
            "const" => 42
          }
        }
      }

      result = JsonSchema.to_schema(json_schema)

      assert result["age"][:type] == :integer
      assert result["age"][:number] == [min: 0, max: 150] or result["age"][:number] == [max: 150, min: 0]
      assert result["score"][:type] == :float

      assert result["score"][:number] == [greater_than: 0, less_than: 100] or
               result["score"][:number] == [less_than: 100, greater_than: 0]

      assert result["count"][:type] == :integer
      assert result["count"][:in] == [42]
    end

    test "converts pattern constraints" do
      json_schema = %{
        "type" => "object",
        "properties" => %{
          "email" => %{
            "type" => "string",
            "pattern" => ".+@.+\\..+"
          },
          "phone" => %{
            "type" => "string",
            "pattern" => "^\\d{10}$"
          }
        }
      }

      result = JsonSchema.to_schema(json_schema)

      assert result["email"][:type] == :string
      assert result["phone"][:type] == :string
      assert Regex.source(result["email"][:format]) == ".+@.+\\..+"
      assert Regex.source(result["phone"][:format]) == "^\\d{10}$"
    end

    test "converts enum constraints" do
      json_schema = %{
        "type" => "object",
        "properties" => %{
          "status" => %{
            "type" => "string",
            "enum" => ["active", "inactive", "pending"]
          },
          "role" => %{
            "type" => "string",
            "not" => %{"enum" => ["admin", "super_admin"]}
          }
        }
      }

      result = JsonSchema.to_schema(json_schema)

      assert result["status"][:type] == :string
      assert result["status"][:in] == ["active", "inactive", "pending"]
      assert result["role"][:type] == :string
      assert result["role"][:not_in] == ["admin", "super_admin"]
    end
  end

  describe "to_schema/2 - default values" do
    test "includes default values" do
      json_schema = %{
        "type" => "object",
        "properties" => %{
          "active" => %{"type" => "boolean", "default" => true},
          "count" => %{"type" => "integer", "default" => 0},
          "tags" => %{
            "type" => "array",
            "items" => %{"type" => "string"},
            "default" => []
          }
        }
      }

      result = JsonSchema.to_schema(json_schema)

      assert result["active"][:type] == :boolean
      assert result["active"][:default] == true
      assert result["count"][:type] == :integer
      assert result["count"][:default] == 0
      assert result["tags"][:type] == {:array, :string}
      assert result["tags"][:default] == []
    end
  end

  describe "to_schema/2 - nested schemas" do
    test "converts nested schemas" do
      json_schema = %{
        "type" => "object",
        "properties" => %{
          "profile" => %{
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
        }
      }

      result = JsonSchema.to_schema(json_schema)

      assert is_map(result["profile"])
      assert result["profile"]["bio"][:type] == :string
      assert result["profile"]["bio"][:length] == [max: 500]
      assert result["profile"]["website"][:type] == :string
      assert Regex.source(result["profile"]["website"][:format]) == "^https?://.+"
    end

    test "handles nested required fields" do
      json_schema = %{
        "type" => "object",
        "properties" => %{
          "profile" => %{
            "type" => "object",
            "properties" => %{
              "name" => %{"type" => "string"},
              "bio" => %{"type" => "string"}
            },
            "required" => ["name"]
          }
        }
      }

      result = JsonSchema.to_schema(json_schema)

      assert is_map(result["profile"])
      assert result["profile"]["name"][:type] == :string
      assert result["profile"]["name"][:required] == true
      assert result["profile"]["bio"][:type] == :string
      refute result["profile"]["bio"][:required]
    end
  end

  describe "to_schema/2 - atom_keys option" do
    test "converts to string keys by default" do
      json_schema = %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"},
          "age" => %{"type" => "integer"}
        },
        "required" => ["name"]
      }

      result = JsonSchema.to_schema(json_schema)

      assert result["name"][:type] == :string
      assert result["name"][:required] == true
      assert result["age"][:type] == :integer
      refute result["age"][:required]
    end

    test "converts to atom keys when atom_keys: true" do
      json_schema = %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"},
          "age" => %{"type" => "integer"}
        },
        "required" => ["name"]
      }

      result = JsonSchema.to_schema(json_schema, atom_keys: true)

      assert result.name[:type] == :string
      assert result.name[:required] == true
      assert result.age[:type] == :integer
      refute result.age[:required]
    end

    test "handles nested schemas with atom_keys option" do
      json_schema = %{
        "type" => "object",
        "properties" => %{
          "profile" => %{
            "type" => "object",
            "properties" => %{
              "name" => %{"type" => "string"},
              "bio" => %{"type" => "string"}
            },
            "required" => ["name"]
          }
        }
      }

      result = JsonSchema.to_schema(json_schema, atom_keys: true)

      assert result.profile.name[:type] == :string
      assert result.profile.name[:required] == true
      assert result.profile.bio[:type] == :string
      refute result.profile.bio[:required]
    end
  end

  describe "bidirectional conversion" do
    test "complex schema converts back and forth" do
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
  end
end
