# tclutils::tudiff

`tclutils::tudiff` provides small, portable, line based diff tools in pure Tcl.

## Load

```tcl
package require tclutils::tudiff
```

## API

```tcl
::tclutils::tudiff::text oldText newText
::tclutils::tudiff::files oldFile newFile
::tclutils::tudiff::unified oldFile newFile ?options?
::tclutils::tudiff::unifiedText oldText newText ?options?
```

`text` and `files` return a list of operations:

```tcl
{equal line}
{delete line}
{insert line}
```

## Line ends: `-eol`

`text`, `files`, `unifiedText`, `unified`, `contextText` and `context` take
`-eol ignore|strict` (0.2):

| value | effect |
|---|---|
| `ignore` (default) | CRLF, CR and LF count as the same, a missing final newline does not count |
| `strict` | lines are compared with their line end; `a\r\n` and `a\n` differ, so does a missing final newline |

With `strict` the ops of `text` and `files` keep each line's end (`{equal a\n}`);
`unified` and `context` show the line without `\n` (a `\r` stays) and add
`\ No newline at end of file` as GNU diff does. `files`, `unified` and `context`
also take `-encoding ENC` (default: the system encoding). `directory` compares
bytes. An unknown `-eol` value is an error `{TCLUTILS TUDIFF OPTION EOL}`.

## Unified diff

```tcl
puts [::tclutils::tudiff::unified old.txt new.txt]
```

Options:

```tcl
-fromlabel label
-tolabel label
```

The first implementation intentionally uses a simple LCS based line diff. It is
stable and portable, but not yet optimized for very large files.


## Robustness: `-maxcells`

`tudiff` currently uses a simple dynamic-programming LCS table. This is fine
for small and medium reference files, but has O(n*m) memory/time behavior.
To avoid accidental large-file blow-ups, `text`, `files`, `unifiedText` and
`unified` accept `-maxcells`:

```tcl
::tclutils::tudiff::text $old $new -maxcells 2000000
::tclutils::tudiff::unified old.txt new.txt -maxcells 5000000
```

If the product of old-line-count and new-line-count exceeds the limit, the
command raises an error with error code:

```tcl
TCLUTILS TUDIFF TOO_LARGE
```

A future version may add a streaming or patience-style algorithm for very large
files.


## Context and directory diff

```tcl
::tclutils::tudiff::contextText $old $new
::tclutils::tudiff::context old.txt new.txt
::tclutils::tudiff::directory olddir newdir
```

`directory` returns records such as `equal`, `different`, `only-old`, and `only-new`.
