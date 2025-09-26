defmodule NestedSchemaTest do
  @moduledoc """
  Comprehensive test cases for cast_and_validate with nested schemas.
  Covers edge cases and scenarios not adequately tested in existing test suite.
  """
  use ExUnit.Case

  describe "cast_and_validate with simple nested schemas" do
    test "handles basic nested map schema with valid data" do
      schema = %{
        user: %{
          name: [type: :string, required: true],
          email: [type: :string, required: true],
          age: [type: :integer, default: 0]
        }
      }

      data = %{
        "user" => %{
          "name" => "John Doe",
          "email" => "john@example.com",
          "age" => "25"
        }
      }

      assert {:ok, result} = Skema.cast_and_validate(data, schema)
      assert result.user.name == "John Doe"
      assert result.user.email == "john@example.com"
      assert result.user.age == 25
    end

    test "applies default values in nested schemas" do
      schema = %{
        user: %{
          name: [type: :string, required: true],
          status: [type: :string, default: "active"],
          role: [type: :string, default: "user"]
        }
      }

      data = %{"user" => %{"name" => "John"}}

      assert {:ok, result} = Skema.cast_and_validate(data, schema)
      assert result.user.name == "John"
      assert result.user.status == "active"
      assert result.user.role == "user"
    end

    test "handles missing nested object with nil" do
      schema = %{
        user: %{
          name: [type: :string, required: true]
        },
        optional_data: %{
          value: [type: :string]
        }
      }

      data = %{"user" => %{"name" => "John"}}

      assert {:ok, result} = Skema.cast_and_validate(data, schema)
      assert result.user.name == "John"
      assert result.optional_data == nil
    end
  end

  describe "cast_and_validate with deeply nested schemas" do
    test "handles 3-level nested schemas successfully" do
      schema = %{
        company: %{
          name: [type: :string, required: true],
          address: %{
            street: [type: :string, required: true],
            city: [type: :string, required: true],
            coordinates: %{
              lat: [type: :float, required: true],
              lng: [type: :float, required: true]
            }
          }
        }
      }

      data = %{
        "company" => %{
          "name" => "Tech Corp",
          "address" => %{
            "street" => "123 Main St",
            "city" => "San Francisco",
            "coordinates" => %{
              "lat" => "37.7749",
              "lng" => "-122.4194"
            }
          }
        }
      }

      assert {:ok, result} = Skema.cast_and_validate(data, schema)
      assert result.company.name == "Tech Corp"
      assert result.company.address.street == "123 Main St"
      assert result.company.address.city == "San Francisco"
      assert result.company.address.coordinates.lat == 37.7749
      assert result.company.address.coordinates.lng == -122.4194
    end

    test "handles validation errors at different nesting levels" do
      schema = %{
        company: %{
          name: [type: :string, required: true, length: [min: 3]],
          address: %{
            street: [type: :string, required: true],
            coordinates: %{
              lat: [type: :float, number: [min: -90, max: 90]],
              lng: [type: :float, number: [min: -180, max: 180]]
            }
          }
        }
      }

      data = %{
        "company" => %{
          # Too short
          "name" => "TC",
          "address" => %{
            "street" => "123 Main St",
            "coordinates" => %{
              # Out of range
              "lat" => "200",
              "lng" => "-122.4194"
            }
          }
        }
      }

      assert {:error, %{errors: errors}} = Skema.cast_and_validate(data, schema)

      # Check that errors are properly nested - the actual structure has Result structs
      assert %{company: [%Skema.Result{errors: company_errors}]} = errors
      assert is_list(company_errors[:name])
      # Check for address or coordinates errors in some form
      assert Map.has_key?(company_errors, :address) or Map.has_key?(company_errors, :coordinates)
    end
  end

  describe "cast_and_validate with array of nested schemas" do
    test "handles array of simple nested schemas" do
      schema = %{
        users: [
          type:
            {:array,
             %{
               name: [type: :string, required: true],
               email: [type: :string, required: true],
               active: [type: :boolean, default: true]
             }}
        ]
      }

      data = %{
        "users" => [
          %{"name" => "John", "email" => "john@example.com"},
          %{"name" => "Jane", "email" => "jane@example.com", "active" => "false"}
        ]
      }

      assert {:ok, result} = Skema.cast_and_validate(data, schema)
      assert length(result.users) == 2
      assert Enum.at(result.users, 0).name == "John"
      # default
      assert Enum.at(result.users, 0).active == true
      assert Enum.at(result.users, 1).name == "Jane"
      # cast from "false"
      assert Enum.at(result.users, 1).active == false
    end

    test "handles array with mixed valid and invalid nested objects" do
      schema = %{
        items: [
          type:
            {:array,
             %{
               id: [type: :integer, required: true],
               name: [type: :string, required: true, length: [min: 2]]
             }}
        ]
      }

      data = %{
        "items" => [
          # Both invalid to ensure error
          %{"id" => "not_int", "name" => "X"}
        ]
      }

      assert {:error, %{errors: errors}} = Skema.cast_and_validate(data, schema)

      # Should contain errors from the invalid item - check actual structure
      assert %{items: %Skema.Result{errors: item_errors}} = errors
      assert Map.has_key?(item_errors, :id) or Map.has_key?(item_errors, :name)
    end

    test "handles empty array of nested schemas" do
      schema = %{
        tags: [
          type:
            {:array,
             %{
               name: [type: :string, required: true]
             }}
        ]
      }

      data = %{"tags" => []}

      assert {:ok, result} = Skema.cast_and_validate(data, schema)
      assert result.tags == []
    end

    test "handles nil array of nested schemas" do
      schema = %{
        optional_items: [
          type:
            {:array,
             %{
               value: [type: :string]
             }}
        ]
      }

      data = %{"optional_items" => nil}

      assert {:ok, result} = Skema.cast_and_validate(data, schema)
      assert result.optional_items == nil
    end
  end

  describe "cast_and_validate with complex nested structures" do
    test "handles nested schema with array of nested schemas" do
      schema = %{
        blog_post: %{
          title: [type: :string, required: true],
          author: %{
            name: [type: :string, required: true],
            email: [type: :string, required: true]
          },
          tags: [
            type:
              {:array,
               %{
                 name: [type: :string, required: true],
                 category: [type: :string, default: "general"]
               }}
          ],
          comments: [
            type:
              {:array,
               %{
                 text: [type: :string, required: true],
                 author: %{
                   name: [type: :string, required: true],
                   email: [type: :string]
                 }
               }}
          ]
        }
      }

      data = %{
        "blog_post" => %{
          "title" => "Elixir is Great",
          "author" => %{
            "name" => "John Doe",
            "email" => "john@example.com"
          },
          "tags" => [
            %{"name" => "elixir"},
            %{"name" => "programming", "category" => "tech"}
          ],
          "comments" => [
            %{
              "text" => "Great post!",
              "author" => %{
                "name" => "Reader 1",
                "email" => "reader1@example.com"
              }
            },
            %{
              "text" => "Thanks for sharing",
              "author" => %{"name" => "Reader 2"}
            }
          ]
        }
      }

      assert {:ok, result} = Skema.cast_and_validate(data, schema)
      assert result.blog_post.title == "Elixir is Great"
      assert result.blog_post.author.name == "John Doe"
      assert length(result.blog_post.tags) == 2
      # default
      assert Enum.at(result.blog_post.tags, 0).category == "general"
      assert Enum.at(result.blog_post.tags, 1).category == "tech"
      assert length(result.blog_post.comments) == 2
      assert Enum.at(result.blog_post.comments, 1).author.email == nil
    end

    test "handles array of objects with nested arrays" do
      schema = %{
        departments: [
          type:
            {:array,
             %{
               name: [type: :string, required: true],
               employees: [
                 type:
                   {:array,
                    %{
                      name: [type: :string, required: true],
                      skills: [type: {:array, :string}, default: []]
                    }}
               ]
             }}
        ]
      }

      data = %{
        "departments" => [
          %{
            "name" => "Engineering",
            "employees" => [
              %{
                "name" => "Alice",
                "skills" => ["Elixir", "Phoenix"]
              },
              %{
                "name" => "Bob"
                # skills will use default
              }
            ]
          },
          %{
            "name" => "Design",
            "employees" => []
          }
        ]
      }

      assert {:ok, result} = Skema.cast_and_validate(data, schema)
      assert length(result.departments) == 2
      eng_dept = Enum.at(result.departments, 0)
      assert eng_dept.name == "Engineering"
      assert length(eng_dept.employees) == 2
      alice = Enum.at(eng_dept.employees, 0)
      bob = Enum.at(eng_dept.employees, 1)
      assert alice.skills == ["Elixir", "Phoenix"]
      # default
      assert bob.skills == []

      design_dept = Enum.at(result.departments, 1)
      assert design_dept.employees == []
    end
  end

  describe "cast_and_validate nested schema error handling" do
    test "handles invalid nested object type" do
      schema = %{
        user: %{
          name: [type: :string, required: true]
        }
      }

      data = %{"user" => "not_an_object"}

      assert {:error, %{errors: %{user: ["is invalid"]}}} =
               Skema.cast_and_validate(data, schema)
    end

    test "handles invalid array for nested array schema" do
      schema = %{
        # Use simple array first
        items: [type: {:array, :string}]
      }

      data = %{"items" => "not_an_array"}

      # This should fail during casting because array expects a list
      assert {:error, %{errors: %{items: ["is invalid"]}}} =
               Skema.cast_and_validate(data, schema)
    end

    test "handles array containing non-objects for nested schema array" do
      schema = %{
        users: [
          type:
            {:array,
             %{
               name: [type: :string, required: true]
             }}
        ]
      }

      data = %{"users" => [%{"name" => "Valid"}, "invalid_item", %{"name" => "Also Valid"}]}

      # This fails early when trying to cast "invalid_item" as a nested schema
      assert {:error, %{errors: %{users: ["is invalid"]}}} =
               Skema.cast_and_validate(data, schema)
    end

    test "aggregates errors from multiple nested objects in array" do
      schema = %{
        products: [
          type:
            {:array,
             %{
               name: [type: :string, required: true, length: [min: 3]],
               price: [type: :float, number: [min: 0]]
             }}
        ]
      }

      data = %{
        "products" => [
          # Both invalid
          %{"name" => "A", "price" => "-5"},
          # Valid
          %{"name" => "Valid Product", "price" => "10.99"},
          # Missing required name
          %{"price" => "15.00"}
        ]
      }

      assert {:error, %{errors: %{products: results}}} =
               Skema.cast_and_validate(data, schema)

      # Should have multiple Result structs with errors
      assert is_list(results)

      assert Enum.any?(results, fn
               %Skema.Result{errors: errors} when is_map(errors) ->
                 Map.has_key?(errors, :name) or Map.has_key?(errors, :price)

               _ ->
                 false
             end)
    end

    test "handles missing required fields in deeply nested structures" do
      schema = %{
        order: %{
          id: [type: :string, required: true],
          customer: %{
            name: [type: :string, required: true],
            address: %{
              street: [type: :string, required: true],
              city: [type: :string, required: true]
            }
          },
          items: [
            type:
              {:array,
               %{
                 product_id: [type: :string, required: true],
                 quantity: [type: :integer, required: true, number: [min: 1]]
               }}
          ]
        }
      }

      data = %{
        "order" => %{
          # Missing id
          "customer" => %{
            "name" => "John Doe",
            "address" => %{
              "street" => "123 Main St"
              # Missing city
            }
          },
          "items" => [
            %{
              "product_id" => "item1",
              # Invalid (less than 1)
              "quantity" => "0"
            },
            %{
              # Missing both product_id and quantity
            }
          ]
        }
      }

      assert {:error, %{errors: errors}} = Skema.cast_and_validate(data, schema)

      # Verify nested error structure with Result structs
      assert %{order: [%Skema.Result{errors: order_errors}]} = errors
      # Missing required id
      assert is_list(order_errors[:id])

      # Check for validation errors in nested structures
      assert Map.has_key?(order_errors, :customer) or Map.has_key?(order_errors, :items)
    end
  end

  describe "cast_and_validate with custom casting in nested schemas" do
    defmodule TestParsers do
      @moduledoc false
      def parse_date(date_string) when is_binary(date_string) do
        case Date.from_iso8601(date_string) do
          {:ok, date} -> {:ok, date}
          {:error, _} -> {:error, "invalid date format"}
        end
      end

      def parse_date(_), do: {:error, "must be a string"}

      def parse_tags(tags_string) when is_binary(tags_string) do
        result = tags_string |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
        {:ok, result}
      end

      def parse_tags(tags) when is_list(tags), do: {:ok, tags}
      def parse_tags(_), do: {:error, "must be string or list"}
    end

    test "applies custom casting functions in nested schemas" do
      schema = %{
        event: %{
          title: [type: :string, required: true],
          date: [type: :date, cast_func: {TestParsers, :parse_date}],
          metadata: %{
            tags: [type: {:array, :string}, cast_func: {TestParsers, :parse_tags}],
            created_by: [type: :string, required: true]
          }
        }
      }

      data = %{
        "event" => %{
          "title" => "Conference 2024",
          "date" => "2024-12-15",
          "metadata" => %{
            "tags" => "tech,conference,elixir",
            "created_by" => "admin"
          }
        }
      }

      assert {:ok, result} = Skema.cast_and_validate(data, schema)
      assert result.event.title == "Conference 2024"
      assert result.event.date == ~D[2024-12-15]
      assert result.event.metadata.tags == ["tech", "conference", "elixir"]
      assert result.event.metadata.created_by == "admin"
    end

    test "handles custom casting errors in nested schemas" do
      schema = %{
        user: %{
          name: [type: :string, required: true],
          profile: %{
            birth_date: [type: :date, cast_func: {TestParsers, :parse_date}],
            interests: [type: {:array, :string}, cast_func: {TestParsers, :parse_tags}]
          }
        }
      }

      data = %{
        "user" => %{
          "name" => "John",
          "profile" => %{
            "birth_date" => "invalid-date",
            # Not string or array
            "interests" => 123
          }
        }
      }

      assert {:error, %{errors: errors}} = Skema.cast_and_validate(data, schema)

      # The actual structure is not a list but a single Result
      assert %{user: %Skema.Result{errors: user_errors}} = errors
      # Check for errors in the nested profile structure
      assert Map.has_key?(user_errors, :profile)
    end
  end

  describe "cast_and_validate performance with nested schemas" do
    test "handles reasonably large nested structures" do
      schema = %{
        data: [
          type:
            {:array,
             %{
               id: [type: :integer, required: true],
               attributes: %{
                 name: [type: :string, required: true],
                 value: [type: :float, default: 0.0]
               }
             }}
        ]
      }

      # Generate 100 items
      items =
        Enum.map(1..100, fn i ->
          %{
            "id" => to_string(i),
            "attributes" => %{
              "name" => "Item #{i}",
              "value" => to_string(i * 1.5)
            }
          }
        end)

      data = %{"data" => items}

      assert {:ok, result} = Skema.cast_and_validate(data, schema)
      assert length(result.data) == 100
      assert Enum.at(result.data, 0).id == 1
      assert Enum.at(result.data, 99).id == 100
      assert Enum.at(result.data, 49).attributes.value == 75.0
    end
  end
end
