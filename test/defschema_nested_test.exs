defmodule DefSchemaNestedTest do
  @moduledoc """
  Comprehensive test cases for cast_and_validate with defschema-defined nested schemas.
  Tests struct-based nested schemas and their integration with Skema's validation system.
  """
  use ExUnit.Case
  use Skema

  describe "multi-level defschema nesting" do
    defschema Address do
      field(:street, :string, required: true)
      field(:city, :string, required: true)
      field(:state, :string, default: "CA")
      field(:zip_code, :string, length: [min: 5, max: 5])
    end

    defschema Employee do
      field(:name, :string, required: true)
      field(:email, :string, required: true, format: ~r/@/)
      field(:salary, :integer, number: [min: 30000])
      field(:address, Address, required: true)
    end

    defschema Department do
      field(:name, :string, required: true)
      field(:budget, :integer, number: [min: 0])
      field(:manager, Employee, required: true)
      field(:employees, {:array, Employee}, default: [])
    end

    defschema Company do
      field(:name, :string, required: true)
      field(:headquarters, Address, required: true)
      field(:departments, {:array, Department}, default: [])
      field(:founded_year, :integer, number: [min: 1800, max: 2024])
    end

    test "handles 3-level nested defschema structures successfully" do
      data = %{
        "name" => "Tech Corp",
        "founded_year" => "2010",
        "headquarters" => %{
          "street" => "123 Tech St",
          "city" => "San Francisco",
          "zip_code" => "94105"
        },
        "departments" => [
          %{
            "name" => "Engineering",
            "budget" => "1000000",
            "manager" => %{
              "name" => "Alice Johnson",
              "email" => "alice@techcorp.com",
              "salary" => "150000",
              "address" => %{
                "street" => "456 Manager Ave",
                "city" => "Palo Alto",
                "zip_code" => "94301"
              }
            },
            "employees" => [
              %{
                "name" => "Bob Smith",
                "email" => "bob@techcorp.com",
                "salary" => "120000",
                "address" => %{
                  "street" => "789 Developer Dr",
                  "city" => "Mountain View",
                  "zip_code" => "94041"
                }
              }
            ]
          }
        ]
      }

      assert {:ok, %Company{} = company} = Company.cast_and_validate(data)
      
      # Verify top-level struct
      assert company.name == "Tech Corp"
      assert company.founded_year == 2010
      
      # Verify nested struct types and values
      assert %Address{} = company.headquarters
      assert company.headquarters.street == "123 Tech St"
      assert company.headquarters.state == "CA"  # default value
      
      # Verify array of nested structs
      assert length(company.departments) == 1
      assert %Department{} = dept = Enum.at(company.departments, 0)
      assert dept.name == "Engineering"
      
      # Verify deeply nested struct
      assert %Employee{} = dept.manager
      assert dept.manager.name == "Alice Johnson"
      assert %Address{} = dept.manager.address
      assert dept.manager.address.city == "Palo Alto"
      
      # Verify array within nested struct
      assert length(dept.employees) == 1
      assert %Employee{} = employee = Enum.at(dept.employees, 0)
      assert employee.name == "Bob Smith"
      assert %Address{} = employee.address
    end

    test "propagates validation errors through nested defschema structures" do
      data = %{
        "name" => "Tech Corp",
        "founded_year" => "1799", # Too old
        "headquarters" => %{
          "street" => "123 Tech St",
          "city" => "San Francisco",
          "zip_code" => "9410" # Wrong length (should be 5 chars)
        },
        "departments" => [
          %{
            "name" => "Engineering",
            "budget" => "-1000", # Negative budget
            "manager" => %{
              "name" => "Alice Johnson",
              "email" => "alice-invalid-email", # Invalid email
              "salary" => "25000", # Below minimum
              "address" => %{
                # Missing required street
                "city" => "Palo Alto",
                "zip_code" => "94301"
              }
            }
          }
        ]
      }

      assert {:error, %{errors: errors}} = Company.cast_and_validate(data)
      
      # Should have validation errors at multiple levels
      assert Map.has_key?(errors, :founded_year)
      assert Map.has_key?(errors, :headquarters)
      assert Map.has_key?(errors, :departments)
    end

    test "handles missing required nested structs" do
      data = %{
        "name" => "Tech Corp",
        "founded_year" => "2010"
        # Missing required headquarters
      }

      assert {:error, %{errors: errors}} = Company.cast_and_validate(data)
      assert Map.has_key?(errors, :headquarters)
    end

    test "applies default values throughout nested structure" do
      data = %{
        "name" => "Simple Corp",
        "founded_year" => "2020",
        "headquarters" => %{
          "street" => "100 Simple St",
          "city" => "Simple City"
          # zip_code and state will use defaults
        }
      }

      assert {:ok, %Company{} = company} = Company.cast_and_validate(data)
      assert company.headquarters.state == "CA"
      assert company.departments == [] # default empty array
    end
  end

  describe "array of defschema structs" do
    defschema Category do
      field(:name, :string, required: true)
      field(:description, :string, default: "")
      field(:priority, :integer, number: [min: 1, max: 10], default: 5)
    end

    defschema Product do
      field(:title, :string, required: true, length: [min: 3])
      field(:price, :float, number: [min: 0])
      field(:categories, {:array, Category}, default: [])
      field(:in_stock, :boolean, default: true)
    end

    defschema Store do
      field(:name, :string, required: true)
      field(:products, {:array, Product}, default: [])
    end

    test "handles arrays of nested defschema structs successfully" do
      data = %{
        "name" => "Electronics Store",
        "products" => [
          %{
            "title" => "Laptop",
            "price" => "999.99",
            "categories" => [
              %{"name" => "Electronics", "priority" => "1"},
              %{"name" => "Computers", "description" => "Computing devices"}
            ]
          },
          %{
            "title" => "Mouse",
            "price" => "29.99",
            "in_stock" => "false"
          }
        ]
      }

      assert {:ok, %Store{} = store} = Store.cast_and_validate(data)
      assert store.name == "Electronics Store"
      assert length(store.products) == 2
      
      # First product
      laptop = Enum.at(store.products, 0)
      assert %Product{} = laptop
      assert laptop.title == "Laptop"
      assert laptop.price == 999.99
      assert laptop.in_stock == true  # default
      assert length(laptop.categories) == 2
      
      # Categories are structs
      electronics_cat = Enum.at(laptop.categories, 0)
      assert %Category{} = electronics_cat
      assert electronics_cat.name == "Electronics"
      assert electronics_cat.priority == 1
      assert electronics_cat.description == ""  # default
      
      computers_cat = Enum.at(laptop.categories, 1)
      assert %Category{} = computers_cat
      assert computers_cat.name == "Computers"
      assert computers_cat.priority == 5  # default
      assert computers_cat.description == "Computing devices"
      
      # Second product
      mouse = Enum.at(store.products, 1)
      assert %Product{} = mouse
      assert mouse.title == "Mouse"
      assert mouse.in_stock == false
      assert mouse.categories == []  # default
    end

    test "handles validation errors in arrays of defschema structs" do
      data = %{
        "name" => "Electronics Store",
        "products" => [
          %{
            "title" => "AB", # Too short (min: 3)
            "price" => "-10", # Negative price
            "categories" => [
              %{"name" => "Electronics", "priority" => "15"} # Priority too high (max: 10)
            ]
          },
          %{
            "title" => "Valid Product",
            "price" => "29.99"
            # This one should be valid
          },
          %{
            # Missing required title
            "price" => "50.00"
          }
        ]
      }

      assert {:error, %{errors: errors}} = Store.cast_and_validate(data)
      
      # Should have errors for the products array
      assert Map.has_key?(errors, :products)
    end

    test "handles empty arrays of defschema structs" do
      data = %{
        "name" => "Empty Store",
        "products" => []
      }

      assert {:ok, %Store{} = store} = Store.cast_and_validate(data)
      assert store.products == []
    end
  end

  describe "cast_and_validate vs separate cast and validate" do
    defschema Contact do
      field(:email, :string, required: true, format: ~r/@/)
      field(:phone, :string, length: [min: 10])
    end

    defschema Person do
      field(:name, :string, required: true, length: [min: 2])
      field(:age, :integer, number: [min: 0, max: 150])
      field(:contact, Contact, required: true)
    end

    test "cast_and_validate produces same result as cast + validate for valid data" do
      data = %{
        "name" => "John Doe",
        "age" => "30",
        "contact" => %{
          "email" => "john@example.com",
          "phone" => "1234567890"
        }
      }

      # Using cast_and_validate
      assert {:ok, result1} = Person.cast_and_validate(data)
      
      # Using separate cast and validate
      assert {:ok, cast_result} = Person.cast(data)
      assert :ok = Person.validate(cast_result)
      result2 = cast_result

      # Results should be equivalent
      assert result1.name == result2.name
      assert result1.age == result2.age
      assert result1.contact.email == result2.contact.email
      assert result1.contact.phone == result2.contact.phone
    end

    test "cast_and_validate handles combined cast and validation errors" do
      data = %{
        "name" => "J", # Too short
        "age" => "not_a_number", # Cast error
        "contact" => %{
          "email" => "invalid-email", # Validation error
          "phone" => "123" # Too short
        }
      }

      assert {:error, %{errors: cast_and_validate_errors}} = Person.cast_and_validate(data)
      
      # Should have errors for multiple fields
      assert Map.has_key?(cast_and_validate_errors, :age) # Cast error
      assert Map.has_key?(cast_and_validate_errors, :name) # Validation error
      assert Map.has_key?(cast_and_validate_errors, :contact) # Nested errors
    end

    test "cast succeeds but validate fails for nested structs" do
      data = %{
        "name" => "J", # Too short (validation error)
        "age" => "30", # Valid
        "contact" => %{
          "email" => "john@example.com", # Valid
          "phone" => "123" # Too short (validation error)
        }
      }

      # Cast should succeed (only type conversion)
      assert {:ok, person} = Person.cast(data)
      assert person.name == "J"
      assert person.age == 30
      
      # But validation should fail
      assert {:error, %{errors: validation_errors}} = Person.validate(person)
      assert Map.has_key?(validation_errors, :name)
      assert Map.has_key?(validation_errors, :contact)
    end
  end

  describe "complex real-world scenarios" do
    defschema PaymentMethod do
      field(:type, :string, required: true, in: ~w(credit_card paypal bank_transfer))
      field(:details, :map, default: %{})
      field(:is_default, :boolean, default: false)
    end

    defschema ShippingAddress do
      field(:recipient, :string, required: true)
      field(:street, :string, required: true)
      field(:city, :string, required: true)
      field(:postal_code, :string, required: true)
      field(:country, :string, default: "US")
    end

    defschema OrderItem do
      field(:product_id, :string, required: true)
      field(:product_name, :string, required: true)
      field(:quantity, :integer, required: true, number: [min: 1])
      field(:unit_price, :float, required: true, number: [min: 0])
      field(:total_price, :float, required: true, number: [min: 0])
    end

    defschema Order do
      field(:id, :string, required: true)
      field(:customer_email, :string, required: true, format: ~r/@/)
      field(:items, {:array, OrderItem}, required: true)
      field(:shipping_address, ShippingAddress, required: true)
      field(:payment_method, PaymentMethod, required: true)
      field(:subtotal, :float, number: [min: 0])
      field(:tax, :float, number: [min: 0])
      field(:total, :float, number: [min: 0])
      field(:status, :string, default: "pending", in: ~w(pending confirmed shipped delivered cancelled))
    end

    test "handles complex e-commerce order structure" do
      data = %{
        "id" => "ORD-2024-001",
        "customer_email" => "customer@example.com",
        "items" => [
          %{
            "product_id" => "PROD-123",
            "product_name" => "Wireless Headphones",
            "quantity" => "2",
            "unit_price" => "99.99",
            "total_price" => "199.98"
          },
          %{
            "product_id" => "PROD-456",
            "product_name" => "Phone Case",
            "quantity" => "1",
            "unit_price" => "19.99",
            "total_price" => "19.99"
          }
        ],
        "shipping_address" => %{
          "recipient" => "John Doe",
          "street" => "123 Main St",
          "city" => "Anytown",
          "postal_code" => "12345"
        },
        "payment_method" => %{
          "type" => "credit_card",
          "details" => %{"last_four" => "1234", "brand" => "visa"},
          "is_default" => "true"
        },
        "subtotal" => "219.97",
        "tax" => "17.60",
        "total" => "237.57"
      }

      assert {:ok, %Order{} = order} = Order.cast_and_validate(data)
      
      # Verify order details
      assert order.id == "ORD-2024-001"
      assert order.customer_email == "customer@example.com"
      assert order.status == "pending"  # default
      
      # Verify items array
      assert length(order.items) == 2
      first_item = Enum.at(order.items, 0)
      assert %OrderItem{} = first_item
      assert first_item.product_name == "Wireless Headphones"
      assert first_item.quantity == 2
      assert first_item.unit_price == 99.99
      
      # Verify nested structs
      assert %ShippingAddress{} = order.shipping_address
      assert order.shipping_address.recipient == "John Doe"
      assert order.shipping_address.country == "US"  # default
      
      assert %PaymentMethod{} = order.payment_method
      assert order.payment_method.type == "credit_card"
      assert order.payment_method.is_default == true
      assert order.payment_method.details["last_four"] == "1234"
    end

    test "handles complex validation errors across multiple nested structures" do
      data = %{
        "id" => "ORD-2024-001",
        "customer_email" => "invalid-email", # Invalid email
        "items" => [
          %{
            "product_id" => "PROD-123",
            "product_name" => "Wireless Headphones",
            "quantity" => "0", # Invalid quantity (min: 1)
            "unit_price" => "-99.99", # Invalid negative price
            "total_price" => "199.98"
          }
        ],
        "shipping_address" => %{
          "recipient" => "John Doe",
          # Missing required street
          "city" => "Anytown",
          "postal_code" => "12345"
        },
        "payment_method" => %{
          "type" => "bitcoin", # Invalid payment type
          "is_default" => "true"
        },
        "subtotal" => "-10", # Invalid negative subtotal
        "tax" => "17.60",
        "total" => "237.57"
      }

      assert {:error, %{errors: errors}} = Order.cast_and_validate(data)
      
      # Should have validation errors across multiple nested structures
      assert Map.has_key?(errors, :customer_email)
      assert Map.has_key?(errors, :items)
      assert Map.has_key?(errors, :shipping_address)
      assert Map.has_key?(errors, :payment_method)
      assert Map.has_key?(errors, :subtotal)
    end
  end

  describe "performance and edge cases" do
    defschema SimpleItem do
      field(:id, :integer, required: true)
      field(:name, :string, required: true)
      field(:value, :float, default: 0.0)
    end

    defschema Container do
      field(:name, :string, required: true)
      field(:items, {:array, SimpleItem}, default: [])
    end

    test "handles large arrays of nested defschema structs" do
      # Generate 200 items
      items = Enum.map(1..200, fn i ->
        %{
          "id" => to_string(i),
          "name" => "Item #{i}",
          "value" => to_string(i * 1.5)
        }
      end)

      data = %{
        "name" => "Large Container",
        "items" => items
      }

      assert {:ok, %Container{} = container} = Container.cast_and_validate(data)
      assert container.name == "Large Container"
      assert length(container.items) == 200
      
      # Verify some items are properly cast to structs
      first_item = Enum.at(container.items, 0)
      assert %SimpleItem{} = first_item
      assert first_item.id == 1
      assert first_item.name == "Item 1"
      assert first_item.value == 1.5
      
      last_item = Enum.at(container.items, 199)
      assert %SimpleItem{} = last_item
      assert last_item.id == 200
      assert last_item.value == 300.0
    end

    test "handles invalid struct types gracefully" do
      # Trying to pass wrong type for nested struct field
      data = %{
        "name" => "Container",
        "items" => "not_an_array"
      }

      assert {:error, %{errors: errors}} = Container.cast_and_validate(data)
      assert Map.has_key?(errors, :items)
    end
  end

  describe "custom casting with defschema" do
    defmodule DateParser do
      @moduledoc false
      def parse_iso_date(date_string) when is_binary(date_string) do
        case Date.from_iso8601(date_string) do
          {:ok, date} -> {:ok, date}
          {:error, _} -> {:error, "invalid date format"}
        end
      end
      def parse_iso_date(_), do: {:error, "must be a string"}
    end

    defschema EventDate do
      field(:start_date, :date, cast_func: {DateParser, :parse_iso_date})
      field(:end_date, :date, cast_func: {DateParser, :parse_iso_date})
      field(:all_day, :boolean, default: false)
    end

    defschema Event do
      field(:title, :string, required: true)
      field(:description, :string, default: "")
      field(:event_date, EventDate, required: true)
    end

    test "applies custom casting in nested defschema structures" do
      data = %{
        "title" => "Conference 2024",
        "description" => "Annual tech conference",
        "event_date" => %{
          "start_date" => "2024-06-15",
          "end_date" => "2024-06-17",
          "all_day" => "true"
        }
      }

      assert {:ok, %Event{} = event} = Event.cast_and_validate(data)
      assert event.title == "Conference 2024"
      
      assert %EventDate{} = event.event_date
      assert event.event_date.start_date == ~D[2024-06-15]
      assert event.event_date.end_date == ~D[2024-06-17]
      assert event.event_date.all_day == true
    end

    test "handles custom casting errors in nested defschema" do
      data = %{
        "title" => "Conference 2024",
        "event_date" => %{
          "start_date" => "invalid-date",
          "end_date" => "2024-06-17"
        }
      }

      assert {:error, %{errors: errors}} = Event.cast_and_validate(data)
      assert Map.has_key?(errors, :event_date)
    end
  end
end