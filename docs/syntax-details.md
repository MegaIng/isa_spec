# Syntax Details
This document serves as an overview of the few non-special purpose parsing elements used through the spec and assembly files.


## Value
Distinct from an [expression](#expression), used on the right side of settings. Can be one of `identifier`, `string`, `integer`, `list` or `mapping`,. Can normally not contain computations. Generally, valid JSON and valid Python-literals are also valid values here, but the syntax here is a lot more lax. (with the notable exceptions of floating point values not (yet) being supported)

## Identifier
Follows standard rules, with the addition that `.` is allowed almost always (and doesn't really separate identifiers as it does in most other languages). Standard rules means: Start with a letter or `_`, followed up by any number of letter, digits, `_` or `.`.

## integer
Sequence of decimal digits, or one of `0b`, `0o`, `0x` followed by digits of the corresponding base (**b**inary, **o**ctal, he**x**), case-insensitive.

If it's a signed literal, can also be prefixed by `+` or `-`.

## string
Delimited with a single quote on each side, either `'`, `"` or `` ` ``. Most contexts do not care about which quote is used. Within the quote, backslash escape sequences can be used. These follow standard C-like string syntax. Octal and hex escapes are supported.

## list
Delimited with either `()`, `[]`, `{}`. Most contexts do not care about which bracket pair is used, but they do have to match. Within it, a sequences of [values](#value) are seperated by commas. A trailing comma is allowed.

## mapping
Delimited with either `()`, `[]`, `{}`. Most contexts do not care about which bracket pair is used, but they do have to match. Within it, a sequences of pairs are seperated by commas. A trailing comma is allowed. A pair consists of two values, seperated by `:`. This corresponds to JSON-style object literals.

## expression
Used as values in [Virtual fields](./intro.md#virtual-fields) and [Asserts](./intro.md#asserts). 
> **Note**: Expression evaluation is done in 64 bits. All expressions evalute to a 64 bit signed integer. Size checks and conversions are only performed once the expression is used in a [virtual field](./intro.md#virtual-fields) declaration or the [bitpattern](./intro.md#bitpatterns). 

Possible expression types are:
### - numbers
Any [integer](#integer).
### - current address
Denoted by `$`. Evaluates to the address the first byte of this instruction would be placed at.
### - (virtual) field
Denoted by `%<field_name>` where `field_name` is the [identifier](#identifier) of a field or virtual field that has been declared before.
### - operations
Operations take one or more expressions as arguments and evaluate to the result of the operation on those arguments.

|Name|Operands|Syntax|Precedence|Notes|
|-|-|-|-|-|
|Bit extraction|`a, lo, hi`|`a[hi:lo]`| `0`|`hi` is the **inclusive** upper bound, `lo` the inclusive lower bound. (Important: `hi` is declared first, then `lo`). TODO: What if `hi < lo`.|
|Multiplication|`a, b`|`a * b`| `1`||
|Integer division|`a, b`|`a / b`| `1`| Rounds towards `0`. TODO: What if `b = 0`, crashes currently.|
|Modulo|`a, b`|`a % b`| `1`| TODO: What if `b = 0`, crashes currently.|
|Addition|`a, b`|`a + b`| `2`||
|Subtraction|`a, b`|`a - b`| `2`||
|Left shift|`a, b`|`a << b`| `2`| TODO: What if `b < 0` or `b > 63`|
|Right shift|`a, b`|`a >> b`| `2`| TODO: What if `b < 0` or `b > 63`|
|Bitwise or|`a, b`|`a \| b`| `2`||
|Bitwise and|`a, b`|`a & b`| `2`||
|Bitwise xor|`a, b`|`a ^ b`| `2`||

Precedence determines the order in which operations are evaluated. Operations with the same precedence will be evaluated left to right. Otherwise the operations with **lower** precedence are evaluated first. Parenthesis (`(`, `)`) can be used to change the order of evaluation, as the expression inside the parenthesis will be evaluated first.

### - functions
Functions are denoted as `<function_name>(<argument_expressions>)`. There are currently two functions:

|Name|Operands|Notes|
|-|-|-|
|`log2`|`a`|Rounds down. If `a` is negative or zero, `log2(a)` is `-1`.|
|`asr`|`a, b`|What if `b < 0` or `b > 63`?|

It is **not** possible to define custom functions that can be used in expressions.

### Examples:
- `0b11010[3:1]` evaluates to `0b101`
- `-3 / 2` evaluates to `-1`
-  `%a + %b * %c` is the same as `%a + (%b * %c)`, since `*` has a lower precedence than `+`.
-  `%a / %b * %c` is the same as `(%a / %b) * %c`, since `/` and `*` have the same precedence.