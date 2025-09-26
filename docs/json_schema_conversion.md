# Skema to JSON Schema Conversion

This document describes how to convert Skema schema maps to JSON Schema format.

## Overview

The Skema to JSON Schema converter transforms Skema schema definitions into standard JSON Schema documents. This enables:

- API documentation generation
- Frontend validation with JSON Schema libraries
- OpenAPI specification integration
- Cross-platform validation consistency

**Note**: Only schema maps are supported. Schema modules (using `defschema`) are not supported by this converter.

## Type Mappings

### Basic Types

| Skema Type | JSON Schema Type | Notes |
|------------|------------------|-------|
| `:string` / `:binary` | `"type": "string"` | Direct mapping |
| `:integer` | `"type": "integer"` | Direct mapping |
| `:float` | `"type": "number"` | Direct mapping |
| `:number` | `"type": "number"` | Integer or float |
| `:boolean` | `"type": "boolean"` | Direct mapping |
| `:atom` | `"type": "string"` | Atoms represented as strings |
| `:decimal` | `"type": "number"` | Decimal numbers |
| `:map` | `"type": "object"` | Generic object |
| `:array` / `:list` | `"type": "array"` | Generic array |
| `:any` | No type constraint | Type property omitted |

### Date/Time Types

| Skema Type | JSON Schema |
|------------|-------------|
| `:date` | `"type": "string", "format": "date"` |
| `:time` | `"type": "string", "format": "time"` |
| `:datetime` | `"type": "string", "format": "date-time"` |
| `:utc_datetime` | `"type": "string", "format": "date-time"` |
| `:naive_datetime` | `"type": "string", "format": "date-time"` |

### Complex Types

| Skema Type | JSON Schema |
|------------|-------------|
| `{:array, type}` | `"type": "array", "items": {...}` |
| `%{...}` (nested schema) | `"type": "object", "properties": {...}` |

## Validation Mappings

### Required Fields

```elixir
# Skema
%{
  name: [type: :string, required: true],
  email: [type: :string, required: true]
}

# JSON Schema
{
  "type": "object",
  "properties": {
    "name": {"type": "string"},
    "email": {"type": "string"}
  },
  "required": ["name", "email"]
}
```

### String Validations

```elixir
# Length constraints
%{
  username: [type: :string, length: [min: 3, max: 20]],
  description: [type: :string, length: [equal_to: 100]]
}

# JSON Schema
{
  "properties": {
    "username": {
      "type": "string",
      "minLength": 3,
      "maxLength": 20
    },
    "description": {
      "type": "string",
      "minLength": 100,
      "maxLength": 100
    }
  }
}
```

### Pattern Matching

```elixir
# Regex format
%{
  email: [type: :string, format: ~r/.+@.+\..+/],
  phone: [type: :string, format: ~r/^\d{10}$/]
}

# JSON Schema
{
  "properties": {
    "email": {
      "type": "string",
      "pattern": ".+@.+\\..+"
    },
    "phone": {
      "type": "string",
      "pattern": "^\\d{10}$"
    }
  }
}
```

### Numeric Validations

```elixir
# Number constraints
%{
  age: [type: :integer, number: [min: 0, max: 150]],
  score: [type: :float, number: [greater_than: 0, less_than: 100]],
  count: [type: :integer, number: [equal_to: 42]]
}

# JSON Schema
{
  "properties": {
    "age": {
      "type": "integer",
      "minimum": 0,
      "maximum": 150
    },
    "score": {
      "type": "number",
      "minimum": 0,
      "maximum": 100,
      "exclusiveMinimum": true,
      "exclusiveMaximum": true
    },
    "count": {
      "type": "integer",
      "const": 42
    }
  }
}
```

### Enumeration

```elixir
# Inclusion/exclusion
%{
  status: [type: :string, in: ["active", "inactive", "pending"]],
  role: [type: :string, not_in: ["admin", "super_admin"]]
}

# JSON Schema
{
  "properties": {
    "status": {
      "type": "string",
      "enum": ["active", "inactive", "pending"]
    },
    "role": {
      "type": "string",
      "not": {
        "enum": ["admin", "super_admin"]
      }
    }
  }
}
```

### Array Validations

```elixir
# Array with length constraints
%{
  tags: [type: {:array, :string}, length: [min: 1, max: 5]],
  coordinates: [type: {:array, :float}, length: [equal_to: 2]]
}

# JSON Schema
{
  "properties": {
    "tags": {
      "type": "array",
      "items": {"type": "string"},
      "minItems": 1,
      "maxItems": 5
    },
    "coordinates": {
      "type": "array",
      "items": {"type": "number"},
      "minItems": 2,
      "maxItems": 2
    }
  }
}
```

### Default Values

```elixir
# Default values
%{
  active: [type: :boolean, default: true],
  count: [type: :integer, default: 0],
  tags: [type: {:array, :string}, default: []]
}

# JSON Schema
{
  "properties": {
    "active": {
      "type": "boolean",
      "default": true
    },
    "count": {
      "type": "integer",
      "default": 0
    },
    "tags": {
      "type": "array",
      "items": {"type": "string"},
      "default": []
    }
  }
}
```

### Documentation

```elixir
# Doc fields
%{
  name: [type: :string, doc: "The user's full name"],
  age: [type: :integer, doc: "Age in years"],
  email: [type: :string, doc: "Contact email address"]
}

# JSON Schema
{
  "properties": {
    "name": {
      "type": "string",
      "description": "The user's full name"
    },
    "age": {
      "type": "integer",
      "description": "Age in years"
    },
    "email": {
      "type": "string",
      "description": "Contact email address"
    }
  }
}
```

## Complex Example

```elixir
# Complete Skema schema
schema = %{
  name: [type: :string, required: true, length: [min: 2, max: 50]],
  age: [type: :integer, number: [min: 0, max: 150]],
  email: [type: :string, format: ~r/.+@.+\..+/],
  status: [type: :string, in: ["active", "inactive"], default: "active"],
  tags: [type: {:array, :string}, length: [max: 10], default: []],
  profile: %{
    bio: [type: :string, length: [max: 500]],
    website: [type: :string, format: ~r/^https?:\/\/.+/],
    social_links: [type: {:array, :string}, length: [max: 5]]
  },
  scores: [type: {:array, :integer}],
  metadata: [type: :map, default: %{}]
}
```

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "name": {
      "type": "string",
      "minLength": 2,
      "maxLength": 50
    },
    "age": {
      "type": "integer",
      "minimum": 0,
      "maximum": 150
    },
    "email": {
      "type": "string",
      "pattern": ".+@.+\\..+"
    },
    "status": {
      "type": "string",
      "enum": ["active", "inactive"],
      "default": "active"
    },
    "tags": {
      "type": "array",
      "items": {"type": "string"},
      "maxItems": 10,
      "default": []
    },
    "profile": {
      "type": "object",
      "properties": {
        "bio": {
          "type": "string",
          "maxLength": 500
        },
        "website": {
          "type": "string",
          "pattern": "^https?:\\/\\/.+"
        },
        "social_links": {
          "type": "array",
          "items": {"type": "string"},
          "maxItems": 5
        }
      }
    },
    "scores": {
      "type": "array",
      "items": {"type": "integer"}
    },
    "metadata": {
      "type": "object",
      "default": {}
    }
  },
  "required": ["name"]
}
```

## Unsupported Features

The following Skema features cannot be converted to JSON Schema:

- **Custom Functions**: `cast_func`, `func` - No JSON Schema equivalent
- **Field Mapping**: `from`, `as` - Application-level concern
- **Transformations**: `into` - Post-processing logic
- **Custom Messages**: `message` - Error message customization
- **Dynamic Required**: `required: function` - Runtime evaluation
- **Array Item Validation**: `each: [validations]` - Use typed arrays instead

## Conversion API

```elixir
# Convert schema map to JSON Schema
json_schema = Skema.JsonSchema.from_schema(schema)

# Convert with options
json_schema = Skema.JsonSchema.from_schema(schema,
  schema_version: "https://json-schema.org/draft/2019-09/schema",
  title: "User Schema",
  description: "Schema for user data validation"
)
```

## Best Practices

1. **Keep schemas simple** - Complex validations may not convert cleanly
2. **Use standard types** - Avoid custom Elixir-specific types
3. **Test converted schemas** - Validate against JSON Schema validators
4. **Document limitations** - Note unsupported features for your team
5. **Version your schemas** - Track changes to both Skema and JSON Schema versions

## Limitations

- Only supports schema maps, not schema modules
- Custom validation functions are ignored
- Some advanced Valdi validations have no JSON Schema equivalent
- Regex patterns may need escaping adjustments
- Default function values are not supported (only static defaults)