defmodule DefSchemaTest do
  use ExUnit.Case
  use Skema

  describe "defschema module with default value" do
    defschema User do
      field(:name, :string, required: true)
      field(:email, :string, length: [min: 5])
      field(:age, :integer, default: 10)
    end

    test "new with default value" do
      assert %User{age: 10, name: nil, email: nil} = User.new(%{})
    end

    test "new override default value" do
      assert %User{age: 18, name: "Donkey", email: nil} = User.new(%{age: 18, name: "Donkey"})
    end
  end

  describe "test custom ecto type" do
    defmodule CustomType do
      @moduledoc false
      def cast(value) when is_binary(value), do: {:ok, value}
      def cast(_), do: :error
    end

    defschema User2 do
      field(:name, :string, required: true)
      field(:status, CustomType)
    end

    test "cast custom type" do
      assert {:ok, %User2{name: "D", status: "active"}} = User2.cast(%{name: "D", status: "active"})
    end

    test "cast custom type with invalid value" do
      assert {:error, %{errors: %{status: ["is invalid"]}}} = User2.cast(%{name: "D", status: 1})
    end
  end

  describe "Skema.cast_and_validate" do
    defschema UserModel do
      field(:name, :string, required: true)
      field(:email, :string, length: [min: 5])
      field(:age, :integer)
    end

    defschema UserNestedModel do
      field(:user, UserModel)
    end

    test "cast embed type with valid value" do
      data = %{
        user: %{
          name: "D",
          email: "d@h.com",
          age: 10
        }
      }

      assert {:ok, %UserNestedModel{user: %UserModel{name: "D", email: "d@h.com", age: 10}}} =
               Skema.cast(data, UserNestedModel)
    end

    test "cast with no value should default to nil and skip validation" do
      data = %{
        user: %{
          name: "D",
          age: 10
        }
      }

      assert {:ok, %{user: %{email: nil}}} = Skema.cast(data, UserNestedModel)
    end

    test "cast_and_validate embed validation invalid should error" do
      data = %{
        user: %{
          name: "D",
          email: "h",
          age: 10
        }
      }

      assert {:ok, casted_data} =
               Skema.cast(data, UserNestedModel)

      assert {:error, %{errors: %{user: [%{errors: %{email: ["length must be greater than or equal to 5"]}}]}}} =
               Skema.validate(casted_data, UserNestedModel)
    end

    test "cast_and_validate missing required value should error" do
      data = %{
        user: %{
          age: 10
        }
      }

      assert {:ok, casted_data} =
               Skema.cast(data, UserNestedModel)

      assert {:error, %{errors: %{user: [%{errors: %{name: ["is required"]}}]}}} =
               Skema.validate(casted_data, UserNestedModel)
    end

    defschema UserListModel do
      field(:users, {:array, UserModel})
    end

    test "cast_and_validate array embed schema with valid data" do
      data = %{
        "users" => [
          %{
            "name" => "D",
            "email" => "d@h.com",
            "age" => 10
          }
        ]
      }

      assert {:ok, %{users: [%{age: 10, email: "d@h.com", name: "D"}]}} = UserListModel.cast(data)
    end

    test "cast_and_validate empty array embed should ok" do
      data = %{
        "users" => []
      }

      assert {:ok, %{users: []}} = Skema.cast(data, UserListModel)
    end

    test "cast_and_validate nil array embed should ok" do
      data = %{
        "users" => nil
      }

      assert {:ok, %{users: nil}} = Skema.cast(data, UserListModel)
    end

    test "cast_and_validate array embed with invalid value should error" do
      data = %{
        "users" => [
          %{
            "email" => "d@h.com",
            "age" => 10
          },
          %{
            "name" => "HUH",
            "email" => "om",
            "age" => 10
          }
        ]
      }

      assert {:error,
              %{
                errors: %{
                  users: [
                    %{errors: %{name: ["is required"]}},
                    %{errors: %{email: ["length must be greater than or equal to 5"]}}
                  ]
                }
              }} = Skema.cast_and_validate(data, UserListModel)
    end

    defschema UserModel2 do
      field(:age, :integer, number: [min: 10])
      field(:hobbies, {:array, :string})
    end

    defschema UserRoleModel do
      field(:user, UserModel2)
      field(:id, :integer)
    end

    test "return cast error and validation error for field with cast_and_validate valid with nested schema" do
      params = %{user: %{"age" => "1", hobbies: "bad array"}, id: "x"}

      assert {:error,
              %{
                errors: %{
                  user: %{
                    errors: %{
                      hobbies: ["is invalid"]
                    }
                  },
                  id: ["is invalid"]
                }
              }} = Skema.cast_and_validate(params, UserRoleModel)
    end

    test "return error when given map for array type" do
      assert {:error, %{errors: %{users: ["is invalid"]}}} = Skema.cast(%{users: %{}}, UserListModel)
    end
  end
end
