defmodule DefSchemaTest do
  use ExUnit.Case
  use Skema

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

      assert {:ok, %UserNestedModel{user: %UserModel{name: "D", email: "d@h.com", age: 10}}} = UserNestedModel.cast(data)
    end

    test "cast with no value should default to nil and skip validation" do
      data = %{
        user: %{
          name: "D",
          age: 10
        }
      }

      assert {:ok, %{user: %{email: nil}}} = UserNestedModel.cast(data)
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
               UserNestedModel.cast(data)

      assert {:error, %{errors: %{user: [%{errors: %{email: ["length must be greater than or equal to 5"]}}]}}} =
               UserNestedModel.validate(casted_data)
    end

    test "cast_and_validate missing required value should error" do
      data = %{
        user: %{
          age: 10
        }
      }

      assert {:ok, casted_data} =
               UserNestedModel.cast(data)

      assert {:error, %{errors: %{user: [%{errors: %{name: ["is required"]}}]}}} =
               UserNestedModel.validate(casted_data)
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

      assert {:ok, %{users: []}} = UserListModel.cast(data)
    end

    test "cast_and_validate nil array embed should ok" do
      data = %{
        "users" => nil
      }

      assert {:ok, %{users: nil}} = UserListModel.cast(data)
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

      assert {:ok, casted} = UserListModel.cast(data)

      assert {:error,
              %{
                errors: %{
                  users: [
                    %{errors: %{name: ["is required"]}},
                    %{errors: %{email: ["length must be greater than or equal to 5"]}}
                  ]
                }
              }} =
               UserListModel.validate(casted)
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
              }} = UserRoleModel.cast_and_validate(params)
    end

    test "return error when given map for array type" do
      assert {:error, %{errors: %{users: ["is invalid"]}}} = UserListModel.cast(%{users: %{}})
    end
  end
end
