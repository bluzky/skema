defmodule Skema.Schema do
  @moduledoc """
  Schema definition macros for Skema.

  Provides `defschema` macro for defining structured schemas with type annotations,
  validation rules, and automatic struct generation.

  ## Features

  - Type-safe struct generation with `@type` annotations
  - Automatic field validation and casting
  - Support for default values (static or function-based)
  - Required field enforcement via `@enforce_keys`
  - Nested schema support
  - Custom casting and validation functions

  ## Basic Usage

  ```elixir
  defmodule User do
    use Skema.Schema

    defschema do
      field :name, :string, required: true
      field :email, :string, required: true
      field :age, :integer, default: 0
      field :created_at, :naive_datetime, default: &NaiveDateTime.utc_now/0
    end
  end
  ```

  ## Advanced Usage

  ```elixir
  defmodule BlogPost do
    use Skema.Schema

    defschema do
      field :title, :string, required: true, length: [min: 5, max: 100]
      field :content, :string, required: true
      field :status, :string, default: "draft", in: ~w(draft published archived)
      field :tags, {:array, :string}, default: []
      field :author, User, required: true
      field :published_at, :naive_datetime,
        default: fn -> if status == "published", do: NaiveDateTime.utc_now() end
    end
  end
  ```

  ## Nested Schemas

  ```elixir
  defmodule Company do
    use Skema.Schema

    defschema Address do
      field :street, :string, required: true
      field :city, :string, required: true
      field :country, :string, default: "US"
    end

    defschema do
      field :name, :string, required: true
      field :address, Address, required: true
      field :employees, {:array, User}, default: []
    end
  end
  ```
  """

  # Module attributes for accumulating field definitions
  @accumulating_attrs [
    :ts_fields,
    :ts_types,
    :ts_enforce_keys
  ]

  @attrs_to_delete @accumulating_attrs

  @doc false
  defmacro __using__(_opts) do
    quote do
      import Skema.Schema, only: [defschema: 1, defschema: 2]
    end
  end

  @doc """
  Defines a typed struct with validation capabilities.

  Inside a `defschema` block, each field is defined through the `field/3` macro.

  ## Options per field

  - `type` - The field type (built-in Elixir types, custom types, or other schemas)
  - `required` - If `true`, the field is required and cannot be `nil`
  - `default` - Default value (static value or zero-arity function)
  - `cast_func` - Custom casting function
  - `from` - Source field name if different from target field name
  - `as` - Target field name if different from source field name
  - `into` - Transformation function for `Skema.transform/2`
  - Validation options: `length`, `number`, `format`, `in`, `not_in`, `func`, `each`

  ## Examples

  ### Basic Schema
  ```elixir
  defmodule Person do
    use Skema.Schema

    defschema do
      field :name, :string, required: true
      field :age, :integer, number: [min: 0, max: 150]
      field :email, :string, format: ~r/@/
    end
  end
  ```

  ### Schema in Submodule
  ```elixir
  defmodule MyModule do
    use Skema.Schema

    defschema User do
      field :username, :string, required: true
      field :role, :string, default: "user", in: ~w(user admin)
    end

    defschema Post do
      field :title, :string, required: true
      field :author, User, required: true
      field :tags, {:array, :string}, default: []
    end
  end
  ```

  ### Dynamic Defaults
  ```elixir
  defschema Document do
    field :title, :string, required: true
    field :created_at, :naive_datetime, default: &NaiveDateTime.utc_now/0
    field :uuid, :string, default: fn -> Ecto.UUID.generate() end
  end
  ```
  """
  defmacro defschema(module \\ nil, do: block) do
    ast = build_schema_ast(block)
    method_ast = generate_helper_methods()

    case module do
      nil ->
        quote do
          # Create a lexical scope to avoid polluting the calling module
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

  # Improved helper method generation with better documentation
  @doc false
  def generate_helper_methods do
    quote do
      @doc """
      Creates a new struct instance from a map or another struct.

      ## Examples

          iex> User.new(%{name: "John", age: 30})
          %User{name: "John", age: 30}

          iex> User.new(%OtherStruct{name: "Jane"})
          %User{name: "Jane", age: nil}
      """
      def new(struct) when is_struct(struct) do
        struct(__MODULE__, Map.from_struct(struct))
      end

      def new(map) when is_map(map) do
        struct(__MODULE__, map)
      end

      def new(_) do
        raise ArgumentError, "expected a map or struct"
      end

      @doc """
      Casts and validates the given parameters according to the schema.

      Returns `{:ok, struct}` if successful, `{:error, errors}` otherwise.

      ## Examples

          iex> User.cast(%{name: "John", age: "30"})
          {:ok, %User{name: "John", age: 30}}

          iex> User.cast(%{age: "invalid"})
          {:error, %{errors: %{age: ["is invalid"], name: ["is required"]}}}
      """
      def cast(params) when is_map(params) do
        case Skema.cast(params, @ts_fields) do
          {:ok, data} -> {:ok, new(data)}
          error -> error
        end
      end

      def cast(_) do
        {:error, %{errors: %{_base: ["expected a map"]}}}
      end

      @doc """
      Validates the given parameters according to the schema rules.

      Returns `:ok` if validation passes, `{:error, errors}` otherwise.

      ## Examples

          iex> User.validate(%{name: "John", age: 30})
          :ok

          iex> User.validate(%{name: "", age: -1})
          {:error, %{errors: %{name: ["can't be blank"], age: ["must be greater than 0"]}}}
      """
      def validate(params) when is_map(params) do
        Skema.validate(params, @ts_fields)
      end

      def validate(_) do
        {:error, %{errors: %{_base: ["expected a map"]}}}
      end

      @doc """
      Performs casting and validation in a single step.

      Returns `{:ok, struct}` if both succeed, `{:error, errors}` otherwise.

      ## Examples

          iex> User.cast_and_validate(%{"name" => "John", "age" => "30"})
          {:ok, %User{name: "John", age: 30}}
      """
      def cast_and_validate(params) when is_map(params) do
        case Skema.cast_and_validate(params, @ts_fields) do
          {:ok, data} -> {:ok, new(data)}
          error -> error
        end
      end

      def cast_and_validate(_) do
        {:error, %{errors: %{_base: ["expected a map"]}}}
      end

      @doc """
      Transforms data according to schema transformation rules.

      Returns `{:ok, struct}` if successful, `{:error, errors}` otherwise.
      """
      def transform(params) when is_map(params) do
        case Skema.transform(params, @ts_fields) do
          {:ok, data} -> {:ok, new(data)}
          error -> error
        end
      end

      def transform(_) do
        {:error, %{errors: %{_base: ["expected a map"]}}}
      end

      @doc """
      Returns the schema field definitions.

      ## Examples

          iex> User.__fields__()
          %{
            name: [type: :string, required: true],
            age: [type: :integer, default: 0]
          }
      """
      def __fields__, do: @ts_fields

      @doc """
      Returns a list of required field names.
      """
      def __required_fields__ do
        @ts_fields
        |> Enum.filter(fn {_name, opts} -> opts[:required] == true end)
        |> Enum.map(fn {name, _opts} -> name end)
      end

      @doc """
      Returns a list of optional field names.
      """
      def __optional_fields__ do
        @ts_fields
        |> Enum.reject(fn {_name, opts} -> opts[:required] == true end)
        |> Enum.map(fn {name, _opts} -> name end)
      end

      @doc """
      Returns field type information.
      """
      def __field_type__(field_name) do
        case @ts_fields[field_name] do
          nil -> nil
          opts -> opts[:type]
        end
      end
    end
  end

  @doc false
  def build_schema_ast(block) do
    quote do
      @before_compile {unquote(__MODULE__), :__before_compile__}

      import Skema.Schema, only: [field: 2, field: 3]

      # Register accumulating attributes
      Enum.each(unquote(@accumulating_attrs), fn attr ->
        Module.register_attribute(__MODULE__, attr, accumulate: true)
      end)

      # Execute the schema definition block
      unquote(block)

      # Generate struct with default values
      struct_fields =
        @ts_fields
        |> Enum.reverse()
        |> Enum.map(fn {name, opts} ->
          {name, Skema.Schema.__resolve_default_value__(opts[:default])}
        end)

      @enforce_keys Enum.reverse(@ts_enforce_keys)
      defstruct struct_fields

      # Generate type specification
      Skema.Schema.__build_type_spec__(@ts_types)
    end
  end

  @doc false
  # Evaluate zero-arity functions at compile time for static defaults
  def __resolve_default_value__(default) when is_function(default, 0) do
    default.()
  rescue
    # If function can't be evaluated at compile time, keep as is
    _ -> nil
  end

  def __resolve_default_value__(default), do: default

  @doc false
  defmacro __build_type_spec__(types) do
    quote bind_quoted: [types: types] do
      reversed_types = Enum.reverse(types)
      @type t() :: %__MODULE__{unquote_splicing(reversed_types)}
    end
  end

  @doc """
  Defines a field in a typed struct.

  ## Examples

      # Basic field
      field :name, :string

      # Required field
      field :email, :string, required: true

      # Field with default value
      field :status, :string, default: "active"

      # Field with validation
      field :age, :integer, number: [min: 0, max: 150]

      # Field with custom casting
      field :tags, {:array, :string}, cast_func: &parse_comma_separated/1

  ## Options

    * `default` - Sets the default value for the field (can be a value or function)
    * `required` - If set to true, enforces the field and makes its type non-nullable
    * `cast_func` - Custom function for casting the field value
    * `from` - Use value from a different source field name
    * `as` - Output the field with a different name
    * `into` - Transform function for post-processing
    * Validation options: `length`, `number`, `format`, `in`, `not_in`, `func`, `each`
  """
  defmacro field(name, type, opts \\ []) do
    quote bind_quoted: [name: name, type: type, opts: opts] do
      Skema.Schema.__field__(name, type, opts, __ENV__)
    end
  end

  @doc false
  def __field__(name, type, opts, %Macro.Env{module: mod}) when is_atom(name) do
    # Validate field name uniqueness
    if mod |> Module.get_attribute(:ts_fields) |> Keyword.has_key?(name) do
      raise ArgumentError, "field #{inspect(name)} is already defined"
    end

    # Validate options
    validate_field_options!(opts)

    has_default? = Keyword.has_key?(opts, :default)
    is_required? = determine_required_status(opts, has_default?)
    is_nullable? = not has_default? and not is_required?

    # Store field definition
    Module.put_attribute(mod, :ts_fields, {name, [{:type, type} | opts]})
    Module.put_attribute(mod, :ts_types, {name, build_type_annotation(type, is_nullable?)})

    if is_required? do
      Module.put_attribute(mod, :ts_enforce_keys, name)
    end
  end

  def __field__(name, _type, _opts, _env) do
    raise ArgumentError, "field name must be an atom, got #{inspect(name)}"
  end

  # Validate field options at compile time
  defp validate_field_options!(opts) do
    valid_opts = [
      :type,
      :required,
      :default,
      :cast_func,
      :from,
      :as,
      :into,
      :length,
      :number,
      :format,
      :in,
      :not_in,
      :func,
      :each,
      :message
    ]

    invalid_opts = Keyword.keys(opts) -- valid_opts

    if invalid_opts != [] do
      raise ArgumentError,
            "invalid field options: #{inspect(invalid_opts)}. " <>
              "Valid options are: #{inspect(valid_opts)}"
    end
  end

  # Determine if field should be required
  defp determine_required_status(opts, has_default?) do
    case Keyword.get(opts, :required) do
      # Default behavior: required if no default
      nil -> not has_default?
      bool when is_boolean(bool) -> bool
      # Dynamic required, not enforced at struct level
      func when is_function(func) or is_tuple(func) -> false
      other -> raise ArgumentError, "invalid required option: #{inspect(other)}"
    end
  end

  # Build type annotation, making it nullable if needed
  defp build_type_annotation(type, false), do: type
  defp build_type_annotation(type, true), do: quote(do: unquote(type) | nil)

  @doc false
  defmacro __before_compile__(%Macro.Env{module: module}) do
    # Clean up accumulating attributes
    Enum.each(@attrs_to_delete, &Module.delete_attribute(module, &1))
  end
end
