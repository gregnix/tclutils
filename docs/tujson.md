# tclutils::tujson

Small dependency-free JSON helpers in pure Tcl.

## API

```tcl
package require tclutils::tujson

::tclutils::tujson::quote text
::tclutils::tujson::escape text
::tclutils::tujson::minify json
::tclutils::tujson::pretty json ?-indent string?
::tclutils::tujson::validate json
::tclutils::tujson::parse json
::tclutils::tujson::fromJson json
```

`parse` maps JSON objects to Tcl dictionaries and JSON arrays to Tcl lists.
Strings are returned as Tcl strings, numbers as their original numeric text,
`true` as `1`, `false` as `0`, and `null` as the empty string.

## Example

```tcl
set d [::tclutils::tujson::parse {{"name":"Gregor","items":[1,2]}}]
dict get $d name      ;# Gregor
dict get $d items     ;# 1 2
```

## CLI

```bash
tclsh bin/tujson.tcl validate data.json
tclsh bin/tujson.tcl minify data.json
tclsh bin/tujson.tcl pretty data.json
tclsh bin/tujson.tcl parse data.json
```

## Scope

The parser supports standard JSON values: objects, arrays, strings, numbers,
`true`, `false`, and `null`, including common string escapes and Unicode escapes.
It intentionally does not implement JSON5, comments, trailing commas, JSONPath,
or a streaming parser.


## parseTyped

`::tclutils::tujson::parseTyped json` parses JSON into a *typed* tree, unlike
`parse`/`fromJson` which return native Tcl values and lose the object/array/scalar
distinction. Each node is a two-element list `{type value}`:

| type | value |
|------|-------|
| `object`  | dict mapping key -> typed node (insertion order preserved) |
| `array`   | list of typed nodes |
| `string`  | the unescaped string |
| `number`  | the number in its source spelling |
| `boolean` | `true` or `false` |
| `null`    | empty string |

```tcl
% ::tclutils::tujson::parseTyped {{"tags":["x"],"n":1}}
object {tags {array {{string x}}} n {number 1}}
```

## Encoding: toJson

`toJson` is the inverse of `parseTyped`; it serialises a *typed value* back to
JSON text, so `toJson [parseTyped $json]` round-trips `$json`.

A typed value is the tagged form `parseTyped` returns:

| JSON | Typed value |
|------|-------------|
| string `"x"` | `{string x}` |
| number `1`   | `{number 1}` |
| `true`/`false` | `{boolean true}` |
| `null` | `{null {}}` |
| object | `{object {key {typed} ...}}` |
| array  | `{array {{typed} ...}}` |

Build values by hand with the constructors `str`, `num`, `bool`, `null`,
`obj`, `arr`:

```tcl
package require tclutils::tujson
set doc [tujson::obj [list \
    name [tujson::str "Alice"] \
    age  [tujson::num 30] \
    ok   [tujson::bool 1] \
    tags [tujson::arr [list [tujson::str x] [tujson::str y]]] \
    note [tujson::null]]]

tujson::toJson $doc
# {"name":"Alice","age":30,"ok":true,"tags":["x","y"],"note":null}

tujson::toJson $doc -indent 2
# pretty-printed with 2 spaces per level
```

`-indent N` (N > 0) pretty-prints; the default (0) is compact. Strings are
escaped via `quote`; numbers are validated; unknown tags raise
`{TCLUTILS TUJSON TYPE}`.
