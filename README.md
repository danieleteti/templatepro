# TemplatePro - Template Engine for Delphi

![TemplatePro Logo](https://github.com/danieleteti/templatepro/blob/master/templatepro_logo.png)

**TemplatePro** is a modern template engine for Delphi and Object Pascal, inspired by Jinja2, Twig, and Smarty. If you're looking for a Jinja-like or Mustache-like template engine for Delphi, TemplatePro is the solution.

[![Version](https://img.shields.io/badge/version-0.9.0-blue.svg)](https://github.com/danieleteti/templatepro)
[![License](https://img.shields.io/badge/license-Apache%202.0-green.svg)](LICENSE)
[![Delphi](https://img.shields.io/badge/Delphi-10%20Seattle+-orange.svg)](https://www.embarcadero.com/products/delphi)

## What is TemplatePro?

TemplatePro is a template engine library for Embarcadero Delphi and RAD Studio. It allows you to separate presentation logic from business logic by using template files with a clean, readable syntax.

**Use it for:**
- HTML page generation
- Email templates (HTML and plain text)
- Report generation
- Code generation
- Any text-based output

**Supported Delphi versions:** 10 Seattle and later (VCL and FireMonkey).

## Features

- Variables, loops, conditionals
- Filters (built-in and custom)
- Macros for reusable fragments
- Inline expressions
- Template inheritance (multi-level)
- TDataSet support
- Compiled templates for performance

## Quick Start

```pascal
var lCompiler := TTProCompiler.Create;
try
  var lTemplate := lCompiler.Compile('''
    <h1>{{:title}}</h1>
    <p>Hello {{:username}}!</p>
    ''');
  lTemplate.SetData('title', 'Welcome');
  lTemplate.SetData('username', 'Daniele');
  ShowMessage(lTemplate.Render);
finally
  lCompiler.Free;
end;
```

Output:
```html
<h1>Welcome</h1>
<p>Hello Daniele!</p>
```

## Documentation

For complete documentation, examples, and tutorials:

**[https://www.danieleteti.it/templatepro/](https://www.danieleteti.it/templatepro/)**

## License

Apache License 2.0 - See [LICENSE](LICENSE) file.

## Author

**Daniele Teti** - [danieleteti.it](https://www.danieleteti.it)

---

*Keywords: Delphi template engine, Object Pascal templates, Delphi HTML generator, Delphi email templates, RAD Studio template engine*
