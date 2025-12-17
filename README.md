# TemplatePro

![TemplatePro Logo](https://github.com/danieleteti/templatepro/blob/master/templatepro_logo.png)

**Modern Template Engine for Delphi** - Inspired by Jinja2, Twig, and Smarty.

[![Version](https://img.shields.io/badge/version-0.9.0-blue.svg)](https://github.com/danieleteti/templatepro)
[![License](https://img.shields.io/badge/license-Apache%202.0-green.svg)](LICENSE)
[![Delphi](https://img.shields.io/badge/Delphi-10.x--12.x-orange.svg)](https://www.embarcadero.com/products/delphi)

![Demo](https://www.danieleteti.it/images/instant_search_demo.gif)

## Features

| Feature | Syntax | Description |
|---------|--------|-------------|
| Variables | `{{:name}}` | Output variable values |
| Loops | `{{for item in list}}...{{endfor}}` | Iterate over collections |
| Conditionals | `{{if}}...{{else}}...{{endif}}` | Conditional rendering |
| Filters | `{{:name\|uppercase}}` | Transform output |
| **Chained Filters** | `{{:val\|trim\|upper}}` | Multiple filters in sequence |
| **Macros** | `{{macro}}/{{>}}` | Reusable template fragments |
| **Expressions** | `{{@price * qty}}` | Inline calculations |
| **Set Variables** | `{{set x := value}}` | Assign variables in template |
| **Template Inheritance** | `{{extends}}/{{block}}` | Layout system |
| **Multi-level Inheritance** | A → B → C chains | Unlimited inheritance depth |
| **Inherited Content** | `{{inherited}}` | Include parent block content |
| Loop Pseudo-vars | `@@first`, `@@last`, `@@index`, `@@odd`, `@@even` | Loop metadata |
| Dynamic Includes | `{{include :varname}}` | Runtime template selection |
| Dataset Support | `{{:dataset.FieldName}}` | Direct dataset field access |

## Quick Start

### Installation

Add `TemplatePro.pas` and its dependencies to your project:

```pascal
uses
  TemplatePro;
```

### Basic Usage

```pascal
var
  Compiler: TTProCompiler;
  Template: ITProCompiledTemplate;
begin
  Compiler := TTProCompiler.Create;
  try
    Template := Compiler.Compile('Hello, {{:name}}!');
    Template.SetData('name', 'World');
    WriteLn(Template.Render);  // Output: Hello, World!
  finally
    Compiler.Free;
  end;
end;
```

## Tag Syntax Overview

Quick reference for tag prefix characters:

| Syntax | Purpose | Example |
|--------|---------|---------|
| `{{:...}}` | Output variable | `{{:username}}` |
| `{{@...}}` | Evaluate expression | `{{@price * qty}}` |
| `{{>...}}` | Invoke macro | `{{>button("OK")}}` |
| `{{#...#}}` | Comment | `{{# note #}}` |

## Syntax Guide

### Variables and Filters

```html
<!-- Basic variable -->
{{:username}}

<!-- With filter -->
{{:username|uppercase}}

<!-- Chained filters (v0.8+) -->
{{:price|numberformat|lpad,10}}

<!-- HTML encoding (safe output) -->
{{:userInput|html}}
```

### Loops

```html
{{for product in products}}
  {{if product.@@first}}<ul>{{endif}}
  <li class="{{if product.@@odd}}odd{{else}}even{{endif}}">
    {{:product.@@index}}. {{:product.name}} - ${{:product.price}}
  </li>
  {{if product.@@last}}</ul>{{endif}}
{{endfor}}
```

### Conditionals

```html
{{if user.isAdmin}}
  <a href="/admin">Admin Panel</a>
{{else}}
  <span>Welcome, {{:user.name}}</span>
{{endif}}

<!-- With expressions -->
{{if @(cart.total > 100)}}
  <p>Free shipping!</p>
{{endif}}
```

### Expressions (v0.8+)

```html
<!-- Inline calculations -->
<p>Total: ${{@price * quantity}}</p>
<p>With tax: ${{@price * quantity * 1.21}}</p>

<!-- In conditions -->
{{if @(age >= 18 and hasLicense)}}
  <p>Can drive</p>
{{endif}}

<!-- String functions -->
<p>{{@Upper(name)}}</p>
```

### Set Variables (v0.8+)

```html
{{set greeting := "Hello"}}
{{set fullPrice := @(price * qty)}}

<p>{{:greeting}}, your total is ${{:fullPrice}}</p>

<!-- With filters -->
{{set formattedName := user.name|uppercase}}
```

### Macros (v0.8+)

Define reusable template fragments:

```html
{{macro button(text, url, style)}}
  <a href="{{:url}}" class="btn btn-{{:style}}">{{:text}}</a>
{{endmacro}}

<!-- Usage -->
{{>button("Click Me", "/action", "primary")}}
{{>button("Cancel", "/", "secondary")}}
```

### Template Inheritance (v0.9+)

**base.html** - The root layout:
```html
<!DOCTYPE html>
<html>
<head>
  {{block "head"}}<title>Default Title</title>{{endblock}}
</head>
<body>
  {{block "content"}}Default content{{endblock}}
  {{block "footer"}}<footer>© 2025</footer>{{endblock}}
</body>
</html>
```

**section.html** - Extends base:
```html
{{extends "base.html"}}
{{block "head"}}
  {{inherited}}
  <link rel="stylesheet" href="section.css">
{{endblock}}
```

**page.html** - Extends section (3-level inheritance):
```html
{{extends "section.html"}}
{{block "head"}}
  {{inherited}}
  <script src="page.js"></script>
{{endblock}}
{{block "content"}}
  <h1>Page Title</h1>
  <p>Page content here...</p>
{{endblock}}
```

**Result:**
```html
<!DOCTYPE html>
<html>
<head>
  <title>Default Title</title>
  <link rel="stylesheet" href="section.css">
  <script src="page.js"></script>
</head>
<body>
  <h1>Page Title</h1>
  <p>Page content here...</p>
  <footer>© 2025</footer>
</body>
</html>
```

### Dynamic Includes

```html
{{set templateName := "header_" + theme + ".tpro"}}
{{include :templateName}}

<!-- With variable mapping -->
{{include "card.tpro" => title=product.name, price=product.cost}}
```

## Built-in Filters

| Filter | Example | Description |
|--------|---------|-------------|
| `uppercase` | `{{:s\|uppercase}}` | Convert to uppercase |
| `lowercase` | `{{:s\|lowercase}}` | Convert to lowercase |
| `capitalize` | `{{:s\|capitalize}}` | Capitalize first letter |
| `lpad,N` | `{{:n\|lpad,5}}` | Left pad to N chars |
| `rpad,N` | `{{:n\|rpad,5}}` | Right pad to N chars |
| `trunc,N` | `{{:s\|trunc,10}}` | Truncate to N chars |
| `contains,S` | `{{if s\|contains,"x"}}` | Check if contains substring |
| `icontains,S` | `{{if s\|icontains,"x"}}` | Case-insensitive contains |
| `datetostr` | `{{:d\|datetostr}}` | Format date |
| `datetostr,F` | `{{:d\|datetostr,"yyyy-mm-dd"}}` | Format date with pattern |
| `datetimetostr` | `{{:d\|datetimetostr}}` | Format datetime |
| `round,N` | `{{:n\|round,-2}}` | Round to N decimals |
| `formatfloat,F` | `{{:n\|formatfloat,"0.00"}}` | Format number |
| `default,V` | `{{:s\|default,N/A}}` | Default if empty |
| `eq,V` | `{{if x\|eq,10}}` | Equality check |
| `ne,V` | `{{if x\|ne,0}}` | Not equal check |
| `gt,V` | `{{if n\|gt,10}}` | Greater than |
| `ge,V` | `{{if n\|ge,10}}` | Greater or equal |
| `lt,V` | `{{if n\|lt,10}}` | Less than |
| `le,V` | `{{if n\|le,10}}` | Less or equal |

## Custom Filters

```pascal
// Define custom filter
function MyFilter(const aValue: TValue; const aParams: TArray<TFilterParameter>): TValue;
begin
  Result := '**' + aValue.AsString + '**';
end;

// Register filter
Template.AddFilter('highlight', MyFilter);

// Use in template: {{:text|highlight}}
```

## Documentation

For complete documentation and more examples, visit:

**[Official Documentation](https://www.danieleteti.it/templatepro/)**

## License

Apache License 2.0 - See [LICENSE](LICENSE) file for details.

## Author

**Daniele Teti** - [danieleteti.it](https://www.danieleteti.it)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
