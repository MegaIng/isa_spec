# isa files
Isa files consist of three parts: settings, field types, and instruction. The first two are optional, but if present, they have to be in this order. They are all introduced via header lines in the format `[<section name>]`, e.g. `[fields]`

Settings
--------------------------
Either meta information or global settings that affect how instructions are encoded. They all have to be in the format `<name> = <value>`. See [Syntax Details](./syntax-details.md#value) for details on how values can be structured in general, however, each setting will only accept a specified subset of this syntax.

### - `name` and `variant`
These are meta information giving a name for the isa spec, as well as a variation marker to list e.g. the implemented extensions. `name` can be either a raw identifier or a string, `variant` has to be an identifier.
### - `endianness`
Either `big` or `little`, with the latter being the default. Instruction bit patterns are interpreted as a single n-bit integer, so with the default `little` the rightmost 8-bit are outputted first.
### - `line_comments`
A list of strings representing the tokens that mark the start of a comment that goes to the end of the line. Defaults to `[";", "//"]`, which is the same set of line comments supported in the `.isa` file itself.
### - `block_comments`
A mapping of strings to strings representing the pairs of tokens that mark the start and end of multiline comments. Defaults to `{"/*": "*/"}`, i.e., C-style, which are also supported in the `.isa` file itself. Note that in case of ambiguity, `block_comments` starts are preferred over `line_comments`.

Fields
--------------------------
This section is a sequence of field type definitions, separated by at least one completely blank line. Each field type definition consists of a name alone on the first line, followed by a list of field values, each on a new line.

A field value is either an [identifier](./syntax-details.md#identifier) or [string](./syntax-details.md#string) followed by a simple bit pattern. The simple bit patterns have to only consist of `0` and `1` and all have to the same length.

The strings are not allowed to contain whitespace, but they are allowed to be completely empty. (TODO: strings not yet implemented)

When matching an instruction, field values are scanned linearly from top to bottom and the first matching one is used. (TODO: doesn't quite match behavior, change the behavior)

Instructions
-------------------------

This section defines a list of instructions, separated by at least one completely blank line. Each instruction contains at least a syntax line and a bit pattern, but can also contain virtual fields, asserts, and a single description line.

### Syntax Line
This line defines the syntax matched when trying to figure out if this instruction is a candidate for [instruction selection](#instruction-selection). Except for whitespaces and field placeholders, it has to match exactly.

All whitespaces (e.g., space, tab, vertical tab) are normalized into a space. A single whitespace character means that any amount of whitespace is allowed when matching the assembly, but is not required. Two spaces directly next to each other means that whitespace is required at this location.

TODO: Add example here

Field definitions are introduced by `%` (`%%` can be used to match a literal `%`), followed by a field [name](./syntax-details.md#identifier), then optionally by an annotation and finally a required field type.

The annotation is seperated from the field name by a `:` (no spaces allowed) and can either be `S<N>` or `U<N>`, defaulting to `U64` if not given. The exact behavior is described [here](TODO), but essentially this should describe if the value of the field is zero- or sign-extended and *to* what width it gets extended, not what width it gets extended from.

The field type finally has to be put into parentheses `()` and can be one of the custom field types defined [above](#fields) or one of the 2 builtins, `label` and `immediate`. Multiple field types can also be seperated by `|` (read as 'or') in which case they are tried in order and the first matching one is used.

TODO: Add examples here

### Bitpatterns

### Description

### Virtual fields

### Asserts

