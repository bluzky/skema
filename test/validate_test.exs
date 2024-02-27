defmodule ValidateTest do
  @moduledoc false
  use ExUnit.Case

  test "validate nested map with success" do
    data = %{name: "Doe John", address: %{city: "HCM", street: "NVL"}}

    schema = %{
      name: [type: :string],
      address: %{
        city: [type: :string],
        street: [type: :string]
      }
    }

    assert :ok =
             Skema.validate(data, schema)
  end

  test "validate nested map with bad value should error" do
    data = %{name: "Doe John", address: "HCM"}

    schema = %{
      name: [type: :string],
      address: [
        type: %{
          city: [type: :number],
          street: [type: :string]
        }
      ]
    }

    assert {:error, %{errors: %{address: ["is invalid"]}}} = Skema.validate(data, schema)
  end

  test "validate nested map with bad nested value should error" do
    data = %{name: "Doe John", address: %{city: "HCM", street: "NVL"}}

    schema = %{
      name: [type: :string],
      address: [
        type: %{
          city: [type: :number],
          street: [type: :string]
        }
      ]
    }

    assert {:error, %{errors: %{address: [%{errors: %{city: ["is not a number"]}}]}}} = Skema.validate(data, schema)
  end

  test "validate nested map skip nested check if value nil" do
    data = %{name: "Doe John", address: nil}

    schema = %{
      name: [type: :string],
      address: [
        type: %{
          city: [type: :number],
          street: [type: :string]
        },
        required: false
      ]
    }

    assert :ok = Skema.validate(data, schema)
  end

  test "validate nested map skip nested check if key is missing" do
    data = %{name: "Doe John"}

    schema = %{
      name: [type: :string],
      address: [
        type: %{
          city: [type: :number],
          street: [type: :string]
        },
        required: false
      ]
    }

    assert :ok = Skema.validate(data, schema)
  end

  test "validate array of nested map with valid value should ok" do
    data = %{name: "Doe John", address: [%{city: "HCM", street: "NVL"}]}

    schema = %{
      name: [type: :string],
      address: [
        type:
          {:array,
           %{
             city: [type: :string],
             street: [type: :string]
           }}
      ]
    }

    assert :ok = Skema.validate(data, schema)
  end

  test "validate array of nested map with invalid value should error" do
    data = %{name: "Doe John", address: [%{city: "HCM", street: "NVL"}]}

    schema = %{
      name: [type: :string],
      address: [
        type:
          {:array,
           %{
             city: [type: :number],
             street: [type: :string]
           }}
      ]
    }

    assert {:error, %{errors: %{address: [%{errors: %{city: ["is not a number"]}}]}}} = Skema.validate(data, schema)
  end

  def validate_email(_name, value, _params) do
    if Regex.match?(~r/[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,4}$/, value) do
      :ok
    else
      {:error, "not a valid email"}
    end
  end

  test "validate with custom function ok with good value" do
    assert :ok =
             Skema.validate(
               %{email: "blue@hmail.com"},
               %{email: [type: :string, func: &validate_email/3]}
             )
  end

  test "validate with custom function error with bad value" do
    assert {:error, %{errors: %{email: ["not a valid email"]}}} =
             Skema.validate(
               %{email: "blue@hmail"},
               %{email: [type: :string, func: &validate_email/3]}
             )
  end
end
