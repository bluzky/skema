# JSON Schema → Skema Compatibility Guide

**New to JSON Schema?** This guide shows you how to write JSON Schemas that work perfectly with Skema! 🎯

If you're creating JSON Schemas that need to convert to Skema validation, this document shows you exactly what works and what doesn't. Each section includes complete examples you can copy and modify.

**Quick Start Tips:**
✅ **Stick to basic types** - string, integer, number, boolean, array, object
✅ **Use simple validations** - min/max, length, patterns, enums
✅ **Test your regex patterns** - JSON and Elixir regex might differ slightly
❌ **Avoid complex features** - No `allOf`, `oneOf`, or schema references

## What You Can Use 🛠️

### ✅ String
Perfect for names, descriptions, status values, and any text data.

```json
// Example: User profile field with all possible validations
{
  "type": "string",
  "minLength": 5,
  "maxLength": 100,
  "pattern": "^[A-Za-z]+$",
  "enum": ["active", "inactive"],
  "const": "exact_value",
  "default": "active",
  "format": "email"
}
```
```elixir
# What you get in Skema 👆
[type: :string, length: [min: 5, max: 100], format: ~r/^[A-Za-z]+$/,
 in: ["active", "inactive"], default: "active"]
```

**Common use cases:** usernames, email addresses, status fields, descriptions

### ✅ Integer
Great for ages, counts, IDs, and any whole number data.

```json
// Example: Age field with validation
{
  "type": "integer",
  "minimum": 0,
  "maximum": 100,
  "exclusiveMinimum": true,
  "exclusiveMaximum": true,
  "enum": [1, 2, 3],
  "const": 42,
  "default": 0
}
```
```elixir
# What you get in Skema 👆
[type: :integer, number: [greater_than: 0, less_than: 100],
 in: [1, 2, 3], default: 0]
```

**Common use cases:** ages, quantities, scores, priority levels

### ✅ Number (Float)
Ideal for prices, percentages, measurements, and decimal values.

```json
// Example: Price field with validation
{
  "type": "number",
  "minimum": 0.0,
  "maximum": 99.99,
  "exclusiveMinimum": false,
  "exclusiveMaximum": false,
  "enum": [1.5, 2.7, 3.14],
  "const": 3.14159,
  "default": 0.0
}
```
```elixir
# What you get in Skema 👆
[type: :float, number: [min: 0.0, max: 99.99],
 in: [1.5, 2.7, 3.14], default: 0.0]
```

**Common use cases:** prices, ratings, percentages, coordinates

### ✅ Boolean
Perfect for flags, toggles, and yes/no questions.

```json
// Example: Feature flag
{
  "type": "boolean",
  "const": true,
  "default": false
}
```
```elixir
# What you get in Skema 👆
[type: :boolean, in: [true], default: false]
```

**Common use cases:** feature flags, user preferences, active/inactive status

### ✅ Array
For lists, collections, and multiple values of the same type.

```json
// Example: Tags list with limits
{
  "type": "array",
  "items": {"type": "string"},
  "minItems": 1,
  "maxItems": 10,
  "default": []
}
```
```elixir
# What you get in Skema 👆
[type: {:array, :string}, length: [min: 1, max: 10], default: []]
```

**Common use cases:** tags, categories, file lists, user selections

### ✅ Object
For complex data structures with multiple related fields.

```json
// Example: User profile object
{
  "type": "object",
  "properties": {
    "name": {"type": "string"},
    "age": {"type": "integer"}
  },
  "required": ["name"],
  "default": {}
}
```
```elixir
# What you get in Skema 👆
%{
  name: [type: :string, required: true],
  age: [type: :integer]
}
# Note: object-level defaults become [type: :map, default: %{}]
```

**Common use cases:** user profiles, settings, address information, nested data

### ✅ Null
For optional values that might be missing.

```json
{
  "type": "null"
}
```
```elixir
# What you get in Skema 👆
[type: :any]
```

**Use sparingly:** Usually better to make fields optional in parent object

## Special Formats 🎨

### ✅ Date/Time Formats
Need dates or times? Use these formats and get proper Skema types automatically!

```json
{"type": "string", "format": "date"}        // → [type: :date] ✨
{"type": "string", "format": "time"}        // → [type: :time] ✨
{"type": "string", "format": "date-time"}   // → [type: :datetime] ✨
```

### ✅ Common String Patterns
These formats automatically add validation patterns for you:

```json
{"type": "string", "format": "email"}      // → Email validation 📧
{"type": "string", "format": "uri"}        // → URL validation 🔗
{"type": "string", "format": "url"}        // → Same as URI 🔗
{"type": "string", "format": "uuid"}       // → UUID validation 🆔
{"type": "string", "format": "ipv4"}       // → IP address validation 🌐
{"type": "string", "format": "ipv6"}       // → IPv6 validation 🌐
{"type": "string", "format": "hostname"}   // → Domain name validation 💻
{"type": "string", "format": "password"}   // → Just a string (no validation) 🔐
```

**Pro tip:** Using formats saves you from writing complex regex patterns!

## ⚠️ What to Avoid

These JSON Schema features won't convert to Skema, so don't use them if you need compatibility:

### ❌ Complex Schema Features
- **`allOf`, `oneOf`, `anyOf`** - Schema combinations don't work
- **`$ref`, `$defs`** - No schema references supported
  - **`if/then/else`** - No conditional schemas
- **Union types like `"type": ["string", "number"]`** - Becomes `[type: :any]`

### ❌ Advanced Validations
- **`multipleOf`** - No "must be multiple of X" validation
- **`uniqueItems`** - No "array items must be unique"
- **`additionalProperties`** - Can't control extra object properties
- **`dependencies`** - No field dependencies

### ❌ Meta Information
- **`title`, `description`, `examples`** - Documentation only, not validation
- **`$schema`, `$id`** - Schema metadata

**Don't worry!** The basic features above cover 90% of real-world validation needs. Keep it simple and you'll be fine! 😊
