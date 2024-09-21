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