# Changelog

All notable changes to TemplatePro will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.0] - 2025-12

### Added
- **Multi-level template inheritance**: Templates can now extend other templates that themselves extend others, creating unlimited inheritance chains (A → B → C → ...)
- **`{{inherited}}` tag**: Call parent block content within an overridden block (similar to Jinja2's `super()`)
- **Circular inheritance detection**: Compiler now detects and reports circular template inheritance with clear error messages
- **`{{set}}` variable assignment**: Assign values to variables within templates
  ```
  {{set total := @(price * qty)}}
  {{set greeting := "Hello"}}
  ```
- **Dynamic includes**: Include templates using variable names
  ```
  {{include :templateName}}
  ```
- **Include with variable mapping**: Pass variables to included templates
  ```
  {{include "card.tpro" => title=product.name, price=product.cost}}
  ```
- **Cross-platform line ending handling**: New `OutputLineEnding` property for consistent output across platforms

### Fixed
- Expression evaluation with field properties in dataset iteration
- Support for dotted identifiers in expressions during field iteration

## [0.8.0] - 2024

### Added
- **Macro support**: Define reusable template fragments with parameters
  ```
  {{macro button(text, url)}}
    <a href="{{:url}}">{{:text}}</a>
  {{endmacro}}
  {{>button("Click", "/action")}}
  ```
- **Chained filters**: Apply multiple filters in sequence
  ```
  {{:value|trim|uppercase|lpad,10}}
  ```
- **Expression evaluation**: Inline calculations with `{{@expression}}` syntax
  ```
  {{@price * quantity}}
  {{@Upper(name)}}
  {{if @(total > 100)}}...{{endif}}
  ```
- Nullable types support on filter parameters

### Changed
- Simplified nullable type handling (reduced ~100 lines of code)
- Updated JsonDataObjects dependency

### Fixed
- Nullables used in `{{if}}` expressions now work correctly
- NullableTDate rendered using configured FormatSettings
- Memory leak in test code

## [0.7.0] - 2024

### Added
- **Template inheritance**: `{{extends}}` and `{{block}}` tags for layout system
- **Case-insensitive syntax**: Template tags are now case-insensitive
- Loop pseudo-variables: `@@first`, `@@last`, `@@index`, `@@odd`, `@@even` (accessed via `loopvar.@@pseudo`)
- Dataset/Fields direct access: `{{:datasetName.FieldName}}`

### Changed
- Improved for-loop handling for better performance

### Fixed
- Loop over a list property of a simple object
- Multi-nested lists with 3+ levels

## [0.6.0] - 2023

### Added
- Compiled template caching for improved performance
- Binary template serialization (`SaveToFile`/`CreateFromFile`)
- Custom filter registration via `AddFilter`

### Changed
- Improved error messages with line numbers

## [0.5.0] - 2023

### Added
- Filter system with pipe syntax: `{{:value|filtername}}`
- Built-in filters: `uppercase`, `lowercase`, `capitalize`, `trim`, `html`, `lpad`, `rpad`, `dateformat`, `numberformat`, `default`
- Comparison filters: `eq`, `ne`, `gt`, `lt`, `ge`, `le`
- `{{include}}` tag for template composition

## [0.4.0] - 2022

### Added
- JSON object support via JsonDataObjects
- Nested object property access: `{{:obj.prop.subprop}}`
- Array indexing: `{{:list[0].name}}`

## [0.3.0] - 2022

### Added
- `{{else}}` support in conditionals
- Negation with `{{if !condition}}`
- Comments: `{{# this is a comment #}}`

## [0.2.0] - 2021

### Added
- `{{for}}` loop support
- Object list iteration
- Basic conditional `{{if}}`

## [0.1.0] - 2021

### Added
- Initial release
- Basic variable substitution: `{{:varname}}`
- Simple template compilation and rendering

---

## Migration Guide

### From 0.8.x to 0.9.x

No breaking changes. New features are additive:

1. **Multi-level inheritance**: Existing single-level inheritance continues to work
2. **`{{inherited}}`**: Optional - blocks without it completely replace parent content (existing behavior)
3. **`{{set}}`**: New feature, no impact on existing templates

### From 0.7.x to 0.8.x

No breaking changes. To use new features:

1. **Macros**: Define with `{{macro name(params)}}...{{endmacro}}`, call with `{{>name(args)}}`
2. **Chained filters**: Simply add more pipes: `{{:val|f1|f2}}`
3. **Expressions**: Use `{{@expr}}` for calculations or `{{if @(expr)}}` for conditions
