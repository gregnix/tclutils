# tclutils::tuawk

An awk-style record/field processor in pure Tcl. Records map to fields, rules are
`{pattern action}` pairs, with `BEGIN`/`END`. It is not an awk-language
interpreter: patterns are Tcl expressions (or `/regex/` against `$0`) and actions
are Tcl scripts.

## Package

```tcl
package require tclutils::tuawk 0.1
```

## API

- `tuawk::run text rules ?-fs SEP? ?-ofs SEP? ?-ors SEP?` -> collected output
- `tuawk::file path rules ...`                            -> over a file

`rules` is a flat list of pattern/action pairs:

- Pattern: empty matches always; `/regex/` matches `$0`; otherwise a Tcl `expr`
  (e.g. `$3 > 100`, `$NF == 0`). Special `BEGIN` / `END` run before/after records.
- Action: a Tcl script. An empty action means `emit $0`.
- Fields: `$0` (whole record), `$1`..`$NF`, `$NR`. Variables set in actions persist
  across records (like awk globals), ideal for aggregation with BEGIN/END.
- `emit args...` prints (joined by OFS, terminated by ORS).

Options: `-fs` (default whitespace runs; one char = `split`; multiple = regex),
`-ofs` (default `" "`), `-ors` (default `"\n"`).

```tcl
tuawk::run "a b c\nd e f" {{} {emit $2}}              ;# -> "b\ne\n"
tuawk::run $data {BEGIN {set s 0} {} {set s [expr {$s+$1}]} END {emit "sum: $s"}}
```

## CLI

```bash
tclsh bin/tuawk.tcl -fs : '{$3 >= 1000} {emit $1 $3}' /etc/passwd
cat log | tclsh bin/tuawk.tcl '/ERROR/ {emit $NR $0}'
```

## Scope

Records are lines; no custom record separator. A field access beyond `NF` is an
error, not a silent empty value (intentional). For full awk programs use `exec awk`.
