defmodule SkemaTest.StringList do
  @moduledoc false
  defstruct values: []

  def cast(value) when is_binary(value) do
    rs =
      value
      |> String.split(",")
      |> Enum.reject(&(&1 in [nil, ""]))

    {:ok, %__MODULE__{values: rs}}
  end

  def cast(_), do: :error
end

defmodule SkemaTest.User do
  @moduledoc false
  defstruct [:name]

  def new(name) do
    %__MODULE__{name: name}
  end

  def cast(%{name: name}) do
    {:ok, new(name)}
  end

  def cast(_), do: :error
end

defmodule ParamTest do
  use ExUnit.Case

  alias SkemaTest.StringList
  alias SkemaTest.User

  describe "Skema.cast_and_validate" do
    @type_checks [
      [:string, "Bluz", "Bluz", :ok],
      [:string, 10, nil, :error],
      [:binary, "Bluz", "Bluz", :ok],
      [:binary, true, nil, :error],
      [:boolean, "1", true, :ok],
      [:boolean, "true", true, :ok],
      [:boolean, "0", false, :ok],
      [:boolean, "false", false, :ok],
      [:boolean, true, true, :ok],
      [:boolean, 10, nil, :error],
      [:integer, 10, 10, :ok],
      [:integer, "10", 10, :ok],
      [:integer, 10.0, nil, :error],
      [:integer, "10.0", nil, :error],
      [:float, 10.1, 10.1, :ok],
      [:float, "10.1", 10.1, :ok],
      [:float, 10, 10.0, :ok],
      [:float, "10", 10.0, :ok],
      [:float, "10xx", nil, :error],
      [:decimal, "10.1", Decimal.new("10.1"), :ok],
      [:decimal, 10, Decimal.new("10"), :ok],
      [:decimal, 10.1, Decimal.new("10.1"), :ok],
      [:decimal, Decimal.new("10.1"), Decimal.new("10.1"), :ok],
      [:decimal, "10.1a", nil, :error],
      [:decimal, :ok, nil, :error],
      [:map, %{name: "Bluz"}, %{name: "Bluz"}, :ok],
      [:map, %{"name" => "Bluz"}, %{"name" => "Bluz"}, :ok],
      [:map, [], nil, :error],
      [{:array, :integer}, [1, 2, 3], [1, 2, 3], :ok],
      [{:array, :integer}, ["1", "2", "3"], [1, 2, 3], :ok],
      [{:array, :string}, ["1", "2", "3"], ["1", "2", "3"], :ok],
      [StringList, "1,2,3", %StringList{values: ["1", "2", "3"]}, :ok],
      [StringList, "", %StringList{values: []}, :ok],
      [StringList, [], nil, :error],
      [
        {:array, StringList},
        ["1", "2"],
        [
          %StringList{values: ["1"]},
          %StringList{values: ["2"]}
        ],
        :ok
      ],
      [{:array, StringList}, [1, 2], nil, :error],
      [:date, "2020-10-11", ~D[2020-10-11], :ok],
      [:date, "2020-10-11T01:01:01", ~D[2020-10-11], :ok],
      [:date, ~D[2020-10-11], ~D[2020-10-11], :ok],
      [:date, ~N[2020-10-11 01:00:00], ~D[2020-10-11], :ok],
      [:date, ~U[2020-10-11 01:00:00Z], ~D[2020-10-11], :ok],
      [:date, "2", nil, :error],
      [:time, "01:01:01", ~T[01:01:01], :ok],
      [:time, ~N[2020-10-11 01:01:01], ~T[01:01:01], :ok],
      [:time, ~U[2020-10-11 01:01:01Z], ~T[01:01:01], :ok],
      [:time, ~T[01:01:01], ~T[01:01:01], :ok],
      [:time, "2", nil, :error],
      [:naive_datetime, "-2020-10-11 01:01:01", ~N[-2020-10-11 01:01:01], :ok],
      [:naive_datetime, "2020-10-11 01:01:01", ~N[2020-10-11 01:01:01], :ok],
      [:naive_datetime, "2020-10-11 01:01:01+07", ~N[2020-10-11 01:01:01], :ok],
      [:naive_datetime, ~N[2020-10-11 01:01:01], ~N[2020-10-11 01:01:01], :ok],
      [
        :naive_datetime,
        %{year: 2020, month: 10, day: 11, hour: 1, minute: 1, second: 1},
        ~N[2020-10-11 01:01:01],
        :ok
      ],
      [
        :naive_datetime,
        %{year: "", month: 10, day: 11, hour: 1, minute: 1, second: 1},
        nil,
        :error
      ],
      [
        :naive_datetime,
        %{year: "", month: "", day: "", hour: "", minute: "", second: ""},
        nil,
        :ok
      ],
      [:naive_datetime, "2", nil, :error],
      [:naive_datetime, true, nil, :error],
      [:datetime, "-2020-10-11 01:01:01", ~U[-2020-10-11 01:01:01Z], :ok],
      [:datetime, "2020-10-11 01:01:01", ~U[2020-10-11 01:01:01Z], :ok],
      [:datetime, "2020-10-11 01:01:01-07", ~U[2020-10-11 08:01:01Z], :ok],
      [:datetime, ~N[2020-10-11 01:01:01], ~U[2020-10-11 01:01:01Z], :ok],
      [:datetime, ~U[2020-10-11 01:01:01Z], ~U[2020-10-11 01:01:01Z], :ok],
      [:datetime, "2", nil, :error],
      [:utc_datetime, "-2020-10-11 01:01:01", ~U[-2020-10-11 01:01:01Z], :ok],
      [:utc_datetime, "2020-10-11 01:01:01", ~U[2020-10-11 01:01:01Z], :ok],
      [:utc_datetime, "2020-10-11 01:01:01-07", ~U[2020-10-11 08:01:01Z], :ok],
      [:utc_datetime, ~N[2020-10-11 01:01:01], ~U[2020-10-11 01:01:01Z], :ok],
      [:utc_datetime, ~U[2020-10-11 01:01:01Z], ~U[2020-10-11 01:01:01Z], :ok],
      [:utc_datetime, "2", nil, :error],
      [:atom, "hello", :hello, :ok],
      [:atom, "goodbye", nil, :error],
      [:any, "any", "any", :ok],
      [User, %User{name: "Dzung"}, %User{name: "Dzung"}, :ok],
      [User, %{name: "Dzung"}, %User{name: "Dzung"}, :ok],
      [User, %{email: "Dzung"}, nil, :error]
    ]

    test "cast_and_validate base type" do
      Enum.each(@type_checks, fn [type, value, expected_value, expect] ->
        rs = Skema.cast_and_validate(%{"key" => value}, %{key: type})

        if expect == :ok do
          assert {:ok, %{key: ^expected_value}} = rs
        else
          assert {:error, _} = rs
        end
      end)
    end

    test "schema short hand" do
      assert {:ok, %{number: 10}} = Skema.cast_and_validate(%{number: "10"}, %{number: :integer})

      assert {:ok, %{number: 10}} =
               Skema.cast_and_validate(%{number: "10"}, %{number: [:integer, number: [min: 5]]})
    end

    test "cast_and_validate mixed keys atom and string" do
      assert {:ok, %{active: false, is_admin: true, name: "blue", age: 19}} =
               Skema.cast_and_validate(
                 %{"active" => false, "is_admin" => true, "name" => "blue", "age" => 19},
                 %{
                   active: :boolean,
                   is_admin: :boolean,
                   name: :string,
                   age: :integer
                 }
               )
    end

    test "Skema.cast_and_validate! success" do
      assert %{number: 10} = Skema.cast_and_validate!(%{number: "10"}, %{number: :integer})
    end

    test "Skema.cast_and_validate! raise exception" do
      assert_raise RuntimeError, fn ->
        Skema.cast_and_validate!(%{number: 10}, %{number: {:array, :string}})
      end
    end

    test "cast_and_validate with alias" do
      schema = %{
        email: [type: :string, as: :user_email]
      }

      rs = Skema.cast_and_validate(%{email: "xx@yy.com"}, schema)
      assert {:ok, %{user_email: "xx@yy.com"}} = rs
    end

    test "cast_and_validate with from" do
      schema = %{
        user_email: [type: :string, from: :email]
      }

      rs = Skema.cast_and_validate(%{email: "xx@yy.com"}, schema)
      assert {:ok, %{user_email: "xx@yy.com"}} = rs
    end

    test "cast_and_validate use default value if field not exist in params" do
      assert {:ok, %{name: "Dzung"}} =
               Skema.cast_and_validate(%{}, %{name: [type: :string, default: "Dzung"]})
    end

    test "cast_and_validate use default function if field not exist in params" do
      assert {:ok, %{name: "123"}} =
               Skema.cast_and_validate(%{}, %{name: [type: :string, default: fn -> "123" end]})
    end

    test "cast_and_validate func is used if set" do
      assert {:ok, %{name: "Dzung is so handsome"}} =
               Skema.cast_and_validate(%{name: "Dzung"}, %{
                 name: [
                   type: :string,
                   cast_func: fn value -> {:ok, "#{value} is so handsome"} end
                 ]
               })
    end

    test "cast_and_validate func with 2 arguments" do
      assert {:ok, %{name: "DZUNG"}} =
               Skema.cast_and_validate(%{name: "Dzung", strong: true}, %{
                 name: [
                   type: :string,
                   cast_func: fn value, data ->
                     {:ok, (data.strong && String.upcase(value)) || value}
                   end
                 ]
               })
    end

    def upcase_string(value, _data) do
      {:ok, String.upcase(value)}
    end

    def upcase_string1(value) do
      {:ok, String.upcase(value)}
    end

    test "cast_and_validate func with tuple module & function" do
      assert {:ok, %{name: "DZUNG"}} =
               Skema.cast_and_validate(%{name: "Dzung"}, %{
                 name: [
                   type: :string,
                   cast_func: {__MODULE__, :upcase_string}
                 ]
               })
    end

    test "cast_and_validate func with 3 arguments return error" do
      assert {:error, %{name: ["bad function"]}} =
               Skema.cast_and_validate(%{name: "Dzung", strong: true}, %{
                 name: [
                   type: :string,
                   cast_func: fn value, _data, _name ->
                     {:ok, value}
                   end
                 ]
               })
    end

    test "cast_and_validate func return custom message" do
      assert {:error, %{name: ["custom error"]}} =
               Skema.cast_and_validate(%{name: "Dzung"}, %{
                 name: [
                   type: :string,
                   cast_func: fn _ ->
                     {:error, "custom error"}
                   end
                 ]
               })
    end

    @schema %{
      user: [
        type: %{
          name: [type: :string, required: true],
          email: [type: :string, length: [min: 5]],
          age: [type: :integer]
        }
      ]
    }

    test "cast_and_validate embed type with valid value" do
      data = %{
        user: %{
          name: "D",
          email: "d@h.com",
          age: 10
        }
      }

      assert {:ok, ^data} = Skema.cast_and_validate(data, @schema)
    end

    test "cast_and_validate with no value should default to nil and skip validation" do
      data = %{
        user: %{
          name: "D",
          age: 10
        }
      }

      assert {:ok, %{user: %{email: nil}}} = Skema.cast_and_validate(data, @schema)
    end

    test "cast_and_validate embed validation invalid should error" do
      data = %{
        user: %{
          name: "D",
          email: "h",
          age: 10
        }
      }

      assert {:error, %{user: [%{email: ["length must be greater than or equal to 5"]}]}} =
               Skema.cast_and_validate(data, @schema)
    end

    test "cast_and_validate missing required value should error" do
      data = %{
        user: %{
          age: 10
        }
      }

      assert {:error, %{user: [%{name: ["is required"]}]}} = Skema.cast_and_validate(data, @schema)
    end

    @array_schema %{
      user: [
        type:
          {:array,
           %{
             name: [type: :string, required: true],
             email: [type: :string],
             age: [type: :integer]
           }}
      ]
    }

    test "cast_and_validate array embed schema with valid data" do
      data = %{
        "user" => [
          %{
            "name" => "D",
            "email" => "d@h.com",
            "age" => 10
          }
        ]
      }

      assert {:ok, %{user: [%{age: 10, email: "d@h.com", name: "D"}]}} =
               Skema.cast_and_validate(data, @array_schema)
    end

    test "cast_and_validate empty array embed should ok" do
      data = %{
        "user" => []
      }

      assert {:ok, %{user: []}} = Skema.cast_and_validate(data, @array_schema)
    end

    test "cast_and_validate nil array embed should ok" do
      data = %{
        "user" => nil
      }

      assert {:ok, %{user: nil}} = Skema.cast_and_validate(data, @array_schema)
    end

    test "cast_and_validate array embed with invalid value should error" do
      data = %{
        "user" => [
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

      assert {:error, %{user: [%{name: ["is required"]}]}} = Skema.cast_and_validate(data, @array_schema)
    end

    test "error with custom message" do
      schema = %{
        age: [type: :integer, number: [min: 10], message: "so khong hop le"]
      }

      assert {:error, %{age: ["so khong hop le"]}} = Skema.cast_and_validate(%{"age" => "abc"}, schema)
    end

    test "cast_and_validate validate required skip if default is set" do
      assert {:ok, %{name: "Dzung"}} =
               Skema.cast_and_validate(%{}, %{name: [type: :string, default: "Dzung", required: true]})
    end

    test "return cast_and_validate error first" do
      schema = %{
        age: [type: :integer, number: [min: 10]],
        hobbies: [type: {:array, :string}]
      }

      assert {:error, %{age: ["is invalid"]}} = Skema.cast_and_validate(%{"age" => "abc"}, schema)
    end

    test "return cast_and_validate error and validation error for field with cast_and_validate valid" do
      schema = %{
        age: [type: :integer, number: [min: 10]],
        hobbies: [type: {:array, :string}]
      }

      assert {:error, %{age: ["must be greater than or equal to 10"], hobbies: ["is invalid"]}} =
               Skema.cast_and_validate(%{"age" => "1", hobbies: "bad array"}, schema)
    end

    test "return cast_and_validate error and validation error for field with cast_and_validate valid with nested schema" do
      schema = %{
        user: %{
          age: [type: :integer, number: [min: 10]],
          hobbies: [type: {:array, :string}]
        },
        id: :integer
      }

      assert {:error,
              %{
                user: %{
                  hobbies: ["is invalid"]
                },
                id: ["is invalid"]
              }} = Skema.cast_and_validate(%{user: %{"age" => "1", hobbies: "bad array"}, id: "x"}, schema)
    end

    test "return data invalid when data given for nested schema is not map" do
      schema = %{nested: %{schema: :string}}
      cases = [%{nested: []}, %{nested: 1}, %{nested: "string"}]

      Enum.each(cases, fn case ->
        assert {:error, %{nested: ["is invalid"]}} = Skema.cast_and_validate(case, schema)
      end)
    end

    test "return error when given map for array type" do
      schema = %{ids: {:array, :integer}}
      data = %{ids: %{}}
      assert {:error, %{ids: ["is invalid"]}} = Skema.cast_and_validate(data, schema)
    end

    test "validate array item" do
      assert {:ok, %{id: [1, 2, 3]}} =
               Skema.cast_and_validate(%{id: ["1", "2", 3]}, %{
                 id: [type: {:array, :integer}, each: [number: [min: 0]]]
               })
    end

    test "validate array item with error" do
      assert {:error, %{id: [[0, "must be greater than or equal to 2"]]}} =
               Skema.cast_and_validate(%{id: ["1", "2", 3]}, %{
                 id: [type: {:array, :integer}, each: [number: [min: 2]]]
               })
    end

    test "dynamic require validation" do
      assert {:ok, %{name: "Dzung"}} =
               Skema.cast_and_validate(%{}, %{
                 name: [type: :string, default: "Dzung", required: fn _, _ -> true end]
               })

      assert {:error, %{image: ["is required"]}} =
               Skema.cast_and_validate(%{}, %{
                 name: [type: :string, default: "Dzung", required: true],
                 image: [type: :string, required: fn _, data -> data.name == "Dzung" end]
               })

      assert {:error, %{image: ["is required"]}} =
               Skema.cast_and_validate(%{}, %{
                 name: [type: :string, default: "Dzung", required: true],
                 image: [type: :string, required: {__MODULE__, :should_require_image}]
               })

      assert {:error, %{image: ["is required"]}} =
               Skema.cast_and_validate(%{}, %{
                 name: [type: :string, default: "Dzung", required: true],
                 image: [type: :string, required: {__MODULE__, :should_require_image1}]
               })
    end

    def should_require_image1(_image) do
      true
    end

    def should_require_image(_image, data) do
      data.name == "Dzung"
    end
  end

  describe "test transform" do
    test "transform function no transform" do
      schema = %{
        status: [:integer, as: :product_status, into: nil]
      }

      data = %{status: 0, deleted: true}

      assert {:ok, %{product_status: 0}} = Skema.cast_and_validate(data, schema)
    end

    test "transform function accept value only" do
      convert_status = fn status ->
        text =
          case status do
            0 -> "draft"
            1 -> "published"
            2 -> "deleted"
          end

        {:ok, text}
      end

      schema = %{
        status: [:integer, as: :product_status, into: convert_status]
      }

      data = %{
        status: 0
      }

      assert {:ok, %{product_status: "draft"}} = Skema.cast_and_validate(data, schema)
    end

    test "transform function with context" do
      convert_status = fn status, data ->
        text =
          case status do
            0 -> "draft"
            1 -> "published"
            2 -> "banned"
          end

        text = if data.deleted, do: "deleted", else: text

        {:ok, text}
      end

      schema = %{
        status: [:integer, as: :product_status, into: convert_status],
        deleted: :boolean
      }

      data = %{
        status: 0,
        deleted: true
      }

      assert {:ok, %{product_status: "deleted"}} = Skema.cast_and_validate(data, schema)
    end

    test "transform function with module, function tuple 2 arguments" do
      schema = %{
        status: [:string, as: :product_status, into: {__MODULE__, :upcase_string}]
      }

      data = %{status: "success"}

      assert {:ok, %{product_status: "SUCCESS"}} = Skema.cast_and_validate(data, schema)
    end

    test "transform function with module, function tuple 1 arguments" do
      schema = %{
        status: [:string, as: :product_status, into: {__MODULE__, :upcase_string1}]
      }

      data = %{status: "success"}

      assert {:ok, %{product_status: "SUCCESS"}} = Skema.cast_and_validate(data, schema)
    end

    test "transform function return value" do
      convert_status = fn status ->
        case status do
          0 -> "draft"
          1 -> "published"
          2 -> "deleted"
        end
      end

      schema = %{
        status: [:integer, as: :product_status, into: convert_status]
      }

      data = %{
        status: 0
      }

      assert {:ok, %{product_status: "draft"}} = Skema.cast_and_validate(data, schema)
    end
  end
end
