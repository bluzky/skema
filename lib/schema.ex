defmodule Skema.Schema do
  @moduledoc """
  Borrow from https://github.com/ejpcmac/typed_struct/blob/main/lib/typed_struct.ex

  Schema specifications:
  Internal presentation of a schema is just a map with field names as keys and field options as values.

  **Example**

  ```elixir
  %{
    name: [type: :string, format: ~r/\d{4}/],
    age: [type: :integer, number: [min: 15, max: 50]].
    skill: [type: {:array, :string}, length: [min: 1, max: 10]]
  }
  ```

  ## I. Field type

  **Built-in types**

  A type could be any of built-in supported types:

  - `boolean`
  - `string` | `binary`
  - `integer`
  - `float`
  - `number` (integer or float)
  - `date`
  - `time`
  - `datetime` | `utc_datetime`: date time with time zone
  - `naive_datetime`: date time without time zone
  - `map`
  - `keyword`
  - `{array, type}` array of built-in type, all item must be the same type


  **Other types**
  Custom type may be supported depends on module.

  **Nested types**
  Nested types could be a another **schema** or list of **schema**


  ```elixir
  %{
    user: [type: %{
        name: [type: :string]
      }]
  }
  ```

  Or list of schema

  ```elixir
  %{
    users: [type: {:array, %{
        name: [type: :string]
      }} ]
  }
  ```

  ## II. Field casting and default value

  These specifications is used for casting data with `Skema.Params.cast`

  ### 1. Default value

  Is used when the given field is missing or nil.

  - Default could be a value

    ```elixir
    %{
      status: [type: :string, default: "active"]
    }
    ```

  - Or a `function/0`, this function will be invoke each time data is `casted`

    ```elixir
    %{
      published_at: [type: :datetime, default: &DateTime.utc_now/0]
    }
    ```

  ### 2. Custom cast function

  You can provide a function to cast field value instead of using default casting function by using
  `cast_func: <function/1>`

  ```elixir
  %{
      published_at: [type: :datetime, cast_func: &DateTime.from_iso8601/1]
  }
  ```

  ## III. Field validation

  **These validation are supported by [valdi](https://hex.pm/packages/valdi)**

  **Custom validation function**

  You can provide a function to validate the value.

  Define validation: `func: <function>`

  Function must be follow this signature

  ```elixir
  @spec func(value::any()) :: :ok | {:error, message::String.t()}
  ```

  ## Define schema with `defschema` macro
  `defschema` helps you define schema clearly and easy to use.

  ```elixir
  defmodule MyStruct do
    use Skema.Schema

    defschema do
      field :field_one, :string
      field :field_two, :integer, required: true
      field :field_four, :atom, default: :hey
      field :update_time, :naive_datetime, default: &NaiveDateTime.utc_now/0
    end
  end
  ```
  """
  @accumulating_attrs [
    :ts_fields,
    :ts_types,
    :ts_enforce_keys
  ]

  @attrs_to_delete @accumulating_attrs

  @doc false
  defmacro __using__(_) do
    quote do
      import Skema.Schema, only: [defschema: 1, defschema: 2]
    end
  end

  @doc """
  Defines a typed struct.

  Inside a `defschema` block, each field is defined through the `field/2`
  macro.

  ## Examples

      defmodule MyStruct do
        use Skema.Schema

        defschema do
          field :field_one, :string
          field :field_three, :boolean, required: true
          field :field_four, :atom, default: :hey
          field :update_time, :naive_datetime, default: &NaiveDateTime.utc_now/0
        end
      end

  You can create the struct in a submodule instead:

      defmodule MyModule do
        use Skema.Schema

        defschema Comment do
          field :user_id, :integer, required: true
          field :content, :string, required: true
        end

        defschema Post do
          field :field_one, :string
          field :field_two, :integer, required: true
          field :field_three, :boolean, required: true
          field :field_four, :string, default: "hello"
          field :update_time, :naive_datetime, default: &NaiveDateTime.utc_now/0
          field :comment, Comment, required: true
        end
      end

      MyModule.Post.cast(%{field_two: 1, field_three: true, comment: %{user_id: 1, content: "hello"}})

  """
  defmacro defschema(module \\ nil, do: block) do
    ast = Skema.Schema.__typedstruct__(block)
    method_ast = Skema.Schema.__default_functions__()

    case module do
      nil ->
        quote do
          # Create a lexical scope.
          (fn -> unquote(ast) end).()
          unquote(method_ast)
        end

      module ->
        quote do
          defmodule unquote(module) do
            unquote(ast)

            unquote(method_ast)
          end
        end
    end
  end

  def __default_functions__ do
    quote do
      def new(struct) when is_struct(struct) do
        struct(__MODULE__, Map.from_struct(struct))
      end

      def new(map) do
        struct(__MODULE__, map)
      end

      def cast(params) when is_map(params) do
        case Skema.cast(params, @ts_fields) do
          {:ok, data} -> {:ok, new(data)}
          error -> error
        end
      end

      def validate(params) do
        Skema.validate(params, @ts_fields)
      end

      def __fields__ do
        @ts_fields
      end
    end
  end

  @doc false
  def __typedstruct__(block) do
    quote do
      @before_compile {unquote(__MODULE__), :__before_compile__}

      import Skema.Schema

      Enum.each(unquote(@accumulating_attrs), fn attr ->
        Module.register_attribute(__MODULE__, attr, accumulate: true)
      end)

      unquote(block)

      definitions = Enum.map(@ts_fields, fn {name, opts} ->
        {name, Skema.Schema.__default_value__(opts[:default])}
      end)

      @enforce_keys @ts_enforce_keys
      defstruct definitions

      Skema.Schema.__type__(@ts_types)
    end
  end

  # expand default value, this only applied a single time at build time
  def __default_value__(default) when is_function(default, 0) do
    default.()
  end

  def __default_value__(default), do: default

  @doc false
  defmacro __type__(types) do
    quote bind_quoted: [types: types] do
      @type t() :: %__MODULE__{unquote_splicing(types)}
    end
  end

  @doc """
  Defines a field in a typed struct.

  ## Example

      # A field named :example of type String.t()
      field :example, String.t()

  ## Options

    * `default` - sets the default value for the field
    * `required` - if set to true, enforces the field and makes its type
      non-nullable
  """
  defmacro field(name, type, opts \\ []) do
    quote bind_quoted: [name: name, type: type, opts: opts] do
      Skema.Schema.__field__(name, type, opts, __ENV__)
    end
  end

  @doc false
  def __field__(name, type, opts, %Macro.Env{module: mod}) when is_atom(name) do
    if mod |> Module.get_attribute(:ts_fields) |> Keyword.has_key?(name) do
      raise ArgumentError, "the field #{inspect(name)} is already set"
    end

    has_default? = Keyword.has_key?(opts, :default)

    enforce? =
      if is_nil(opts[:required]),
        do: not has_default?,
        else: opts[:required] == true

    nullable? = not has_default? and not enforce?

    Module.put_attribute(mod, :ts_fields, {name, [{:type, type} | opts]})
    Module.put_attribute(mod, :ts_types, {name, type_for(type, nullable?)})
    if enforce?, do: Module.put_attribute(mod, :ts_enforce_keys, name)
  end

  def __field__(name, _type, _opts, _env) do
    raise ArgumentError, "a field name must be an atom, got #{inspect(name)}"
  end

  # Makes the type nullable if the key is not enforced.
  defp type_for(type, false), do: type
  defp type_for(type, _), do: quote(do: unquote(type) | nil)

  @doc false
  defmacro __before_compile__(%Macro.Env{module: module}) do
    Enum.each(unquote(@attrs_to_delete), &Module.delete_attribute(module, &1))
  end
end
