defmodule Skema.JsonSchema.Converter.ToSkemaTest do
  use ExUnit.Case, async: true

  alias Skema.JsonSchema

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
      assert result["email"][:format] == ".+@.+\\..+"
      assert result["phone"][:format] == "^\\d{10}$"
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

  describe "to_schema/2 - documentation" do
    test "converts description to doc field" do
      json_schema = %{
        "type" => "object",
        "properties" => %{
          "name" => %{
            "type" => "string",
            "description" => "The user's full name"
          },
          "age" => %{
            "type" => "integer",
            "description" => "Age in years"
          },
          "email" => %{
            "type" => "string",
            "description" => "Contact email address"
          }
        }
      }

      result = JsonSchema.to_schema(json_schema)

      assert result["name"][:type] == :string
      assert result["name"][:doc] == "The user's full name"
      assert result["age"][:type] == :integer
      assert result["age"][:doc] == "Age in years"
      assert result["email"][:type] == :string
      assert result["email"][:doc] == "Contact email address"
    end

    test "handles fields without description" do
      json_schema = %{
        "type" => "object",
        "properties" => %{
          "name" => %{
            "type" => "string",
            "description" => "Has documentation"
          },
          "age" => %{
            "type" => "integer"
            # No description field
          }
        }
      }

      result = JsonSchema.to_schema(json_schema)

      assert result["name"][:doc] == "Has documentation"
      refute Keyword.has_key?(result["age"], :doc)
    end

    test "handles atom_keys with documentation" do
      json_schema = %{
        "type" => "object",
        "properties" => %{
          "name" => %{
            "type" => "string",
            "description" => "The user's name"
          }
        }
      }

      result = JsonSchema.to_schema(json_schema, atom_keys: true)

      assert result.name[:type] == :string
      assert result.name[:doc] == "The user's name"
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
      assert result["profile"]["website"][:format] == "^https?://.+"
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

  describe "to_schema/2 - per_field_required option" do
    test "uses per-field required when option is true" do
      json_schema = %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string", "required" => true},
          "email" => %{"type" => "string", "required" => true},
          "age" => %{"type" => "integer"}
        }
      }

      result = JsonSchema.to_schema(json_schema, per_field_required: true)

      assert result["name"][:type] == :string
      assert result["name"][:required] == true
      assert result["email"][:type] == :string
      assert result["email"][:required] == true
      assert result["age"][:type] == :integer
      refute result["age"][:required]
    end

    test "ignores required array when per_field_required is true" do
      json_schema = %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string", "required" => true},
          "age" => %{"type" => "integer"}
        },
        "required" => ["age"]  # This should be ignored
      }

      result = JsonSchema.to_schema(json_schema, per_field_required: true)

      assert result["name"][:required] == true
      refute result["age"][:required]  # Not required because no per-field property
    end

    test "works with nested schemas and per_field_required" do
      json_schema = %{
        "type" => "object",
        "properties" => %{
          "profile" => %{
            "type" => "object",
            "properties" => %{
              "name" => %{"type" => "string", "required" => true},
              "bio" => %{"type" => "string"}
            }
          }
        }
      }

      result = JsonSchema.to_schema(json_schema, per_field_required: true)

      assert is_map(result["profile"])
      assert result["profile"]["name"][:type] == :string
      assert result["profile"]["name"][:required] == true
      assert result["profile"]["bio"][:type] == :string
      refute result["profile"]["bio"][:required]
    end

    test "combines per_field_required with atom_keys option" do
      json_schema = %{
        "type" => "object",
        "properties" => %{
          "user_name" => %{"type" => "string", "required" => true},
          "user_age" => %{"type" => "integer"}
        }
      }

      result = JsonSchema.to_schema(json_schema, per_field_required: true, atom_keys: true)

      assert result.user_name[:type] == :string
      assert result.user_name[:required] == true
      assert result.user_age[:type] == :integer
      refute result.user_age[:required]
    end

    test "defaults to traditional behavior when per_field_required is false" do
      json_schema = %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string", "required" => true},  # This should be ignored
          "age" => %{"type" => "integer"}
        },
        "required" => ["name"]
      }

      result = JsonSchema.to_schema(json_schema, per_field_required: false)

      assert result["name"][:required] == true  # From required array
      refute result["age"][:required]
    end
  end
end