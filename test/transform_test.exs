defmodule TransformTest do
  use ExUnit.Case
  use Skema

  # Helper module for transform functions
  defmodule TransformHelpers do
    @moduledoc false
    def format_display_name(_value, data) do
      "#{data.name} (#{data.age})"
    end
  end

  # Test schema for transform tests
  defschema TransformableUser do
    field(:name, :string, into: &String.upcase/1)
    field(:email, :string, into: &String.downcase/1)
    field(:age, :integer)
    field(:display_name, :string, into: {TransformHelpers, :format_display_name})
  end

  # Schema without __fields__ for error testing
  defmodule NonTransformableStruct do
    @moduledoc false
    defstruct [:name, :email]
  end

  describe "Skema.transform/2" do
    test "transform field with simple function" do
      schema = %{
        name: [into: &String.upcase/1]
      }

      data = %{name: "john doe"}

      assert {:ok, %{name: "JOHN DOE"}} = Skema.transform(data, schema)
    end

    test "transform field with function that accesses other data" do
      schema = %{
        full_name: [
          into: fn _value, data ->
            "#{data.first_name} #{data.last_name}"
          end
        ]
      }

      data = %{first_name: "John", last_name: "Doe", full_name: nil}

      assert {:ok, %{full_name: "John Doe"}} = Skema.transform(data, schema)
    end

    test "transform field with module function tuple" do
      defmodule TestTransformer do
        @moduledoc false
        def format_email(email) do
          String.downcase(email)
        end

        def format_name(name, data) do
          if data.is_admin do
            "Admin #{name}"
          else
            name
          end
        end
      end

      schema = %{
        email: [into: {TestTransformer, :format_email}],
        name: [into: {TestTransformer, :format_name}]
      }

      data = %{email: "JOHN@EXAMPLE.COM", name: "John", is_admin: true}

      assert {:ok, %{email: "john@example.com", name: "Admin John"}} =
               Skema.transform(data, schema)
    end

    test "transform field with custom field name using :as" do
      schema = %{
        user_email: [as: :email, into: &String.downcase/1]
      }

      data = %{user_email: "JOHN@EXAMPLE.COM"}

      assert {:ok, %{email: "john@example.com"}} = Skema.transform(data, schema)
    end

    test "transform returns error tuple" do
      schema = %{
        age: [
          into: fn value ->
            if value < 0 do
              {:error, "age cannot be negative"}
            else
              {:ok, value}
            end
          end
        ]
      }

      data = %{age: -5}

      assert {:error, %{errors: %{age: "age cannot be negative"}}} =
               Skema.transform(data, schema)
    end

    test "transform returns raw value when no tuple" do
      schema = %{
        score: [into: fn value -> value * 2 end]
      }

      data = %{score: 50}

      assert {:ok, %{score: 100}} = Skema.transform(data, schema)
    end

    test "transform multiple fields" do
      schema = %{
        name: [into: &String.upcase/1],
        email: [into: &String.downcase/1],
        age: [into: fn age -> age + 1 end]
      }

      data = %{name: "john", email: "JOHN@EXAMPLE.COM", age: 25}

      assert {:ok, %{name: "JOHN", email: "john@example.com", age: 26}} =
               Skema.transform(data, schema)
    end

    test "transform field without into option keeps original value" do
      schema = %{
        name: [],
        email: [into: &String.downcase/1]
      }

      data = %{name: "John", email: "JOHN@EXAMPLE.COM"}

      assert {:ok, %{name: "John", email: "john@example.com"}} =
               Skema.transform(data, schema)
    end

    test "transform with nested data" do
      schema = %{
        user: %{
          name: [into: &String.upcase/1],
          email: [into: &String.downcase/1]
        }
      }

      data = %{user: %{name: "john", email: "JOHN@EXAMPLE.COM"}}

      # Note: Currently transform doesn't handle nested schemas
      # This test documents the current behavior
      assert {:ok, %{user: %{name: "john", email: "JOHN@EXAMPLE.COM"}}} =
               Skema.transform(data, schema)
    end

    test "transform with bad function arity" do
      schema = %{
        name: [
          into: fn _value, _data, _extra ->
            "bad function"
          end
        ]
      }

      data = %{name: "john"}

      assert {:error, %{errors: %{name: "bad function"}}} =
               Skema.transform(data, schema)
    end

    test "transform with missing field uses nil" do
      schema = %{
        missing_field: [into: fn value -> value || "default" end]
      }

      data = %{name: "john"}

      assert {:ok, %{missing_field: "default"}} = Skema.transform(data, schema)
    end

    test "transform complex data processing" do
      schema = %{
        tags: [
          into: fn tags_string ->
            tags_string
            |> String.split(",")
            |> Enum.map(&String.trim/1)
            |> Enum.reject(&(&1 == ""))
          end
        ],
        created_at: [
          into: fn _value, data ->
            if data.auto_timestamp do
              DateTime.to_iso8601(DateTime.utc_now())
            else
              data.created_at
            end
          end
        ]
      }

      data = %{
        tags: "elixir, phoenix, web",
        auto_timestamp: true,
        created_at: "2023-01-01T00:00:00Z"
      }

      {:ok, result} = Skema.transform(data, schema)

      assert result.tags == ["elixir", "phoenix", "web"]
      # ISO8601 format
      assert String.contains?(result.created_at, "T")
      # Should be current time
      assert result.created_at != "2023-01-01T00:00:00Z"
    end

    test "transform with conditional logic" do
      schema = %{
        display_name: [
          into: fn _value, data ->
            cond do
              Map.get(data, :first_name) && Map.get(data, :last_name) ->
                "#{data.first_name} #{data.last_name}"

              Map.get(data, :username) ->
                "@#{data.username}"

              true ->
                "Anonymous"
            end
          end
        ]
      }

      # Test full name
      data1 = %{first_name: "John", last_name: "Doe"}
      assert {:ok, %{display_name: "John Doe"}} = Skema.transform(data1, schema)

      # Test username fallback
      data2 = %{username: "johndoe"}
      assert {:ok, %{display_name: "@johndoe"}} = Skema.transform(data2, schema)

      # Test anonymous fallback
      data3 = %{email: "john@example.com"}
      assert {:ok, %{display_name: "Anonymous"}} = Skema.transform(data3, schema)
    end

    test "transform with data validation in transformation" do
      schema = %{
        normalized_email: [
          into: fn email ->
            cleaned = String.downcase(String.trim(email))

            if String.contains?(cleaned, "@") do
              {:ok, cleaned}
            else
              {:error, "invalid email format"}
            end
          end
        ]
      }

      # Valid email
      data1 = %{normalized_email: "  JOHN@EXAMPLE.COM  "}

      assert {:ok, %{normalized_email: "john@example.com"}} =
               Skema.transform(data1, schema)

      # Invalid email
      data2 = %{normalized_email: "not-an-email"}

      assert {:error, %{errors: %{normalized_email: "invalid email format"}}} =
               Skema.transform(data2, schema)
    end

    test "transform persists original data for untransformed fields" do
      schema = %{
        name: [into: &String.upcase/1]
        # email not specified in schema
      }

      data = %{name: "john", email: "john@example.com", age: 25}

      assert {:ok, %{name: "JOHN", email: "john@example.com", age: 25}} =
               Skema.transform(data, schema)
    end
  end

  describe "Skema.transform/2 edge cases" do
    test "transform with nil transformation function" do
      schema = %{
        name: [into: nil]
      }

      data = %{name: "john"}

      assert {:ok, %{name: "john"}} = Skema.transform(data, schema)
    end

    test "transform with invalid function format" do
      schema = %{
        name: [into: "not a function"]
      }

      data = %{name: "john"}

      assert {:error, %{errors: %{name: "bad function"}}} =
               Skema.transform(data, schema)
    end

    test "transform empty data" do
      schema = %{
        name: [into: fn value -> if value, do: String.upcase(value), else: "NO NAME" end]
      }

      data = %{}

      assert {:ok, %{name: "NO NAME"}} = Skema.transform(data, schema)
    end

    test "transform empty schema" do
      schema = %{}
      data = %{name: "john", email: "john@example.com"}

      assert {:ok, %{name: "john", email: "john@example.com"}} =
               Skema.transform(data, schema)
    end
  end

  describe "Skema.transform/1 with struct" do
    test "transforms struct data using schema __fields__" do
      user = %TransformableUser{
        name: "john doe",
        email: "JOHN@EXAMPLE.COM",
        age: 30,
        display_name: "unused"
      }

      assert {:ok, result} = Skema.transform(user)
      assert result.name == "JOHN DOE"
      assert result.email == "john@example.com"
      assert result.age == 30
      assert result.display_name == "john doe (30)"
    end

    test "returns error for struct without __fields__" do
      non_transformable = %NonTransformableStruct{name: "john", email: "john@example.com"}

      assert {:error, "Schema Elixir.TransformTest.NonTransformableStruct does not support transform"} =
               Skema.transform(non_transformable)
    end
  end

  describe "Skema.transform/2 with schema module" do
    test "transforms data using schema module" do
      data = %{
        name: "john doe",
        email: "JOHN@EXAMPLE.COM",
        age: 30,
        display_name: "unused"
      }

      assert {:ok, result} = Skema.transform(data, TransformableUser)
      assert result.name == "JOHN DOE"
      assert result.email == "john@example.com"
      assert result.age == 30
      assert result.display_name == "john doe (30)"
    end
  end

  describe "Skema.transform/2 with keyword list schema" do
    test "transforms data using keyword list schema" do
      schema = [
        name: [into: &String.upcase/1],
        email: [into: &String.downcase/1]
      ]

      data = %{name: "john doe", email: "JOHN@EXAMPLE.COM"}

      assert {:ok, result} = Skema.transform(data, schema)
      assert result.name == "JOHN DOE"
      assert result.email == "john@example.com"
    end
  end
end
