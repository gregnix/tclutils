# tclutils::tuawk

An awk-style record/field processor in pure Tcl. Records map to fields, rules are
`{pattern action}` pairs, with `BEGIN`/`END`. It is not an awk-language
interpreter: patterns are Tcl expressions (or `/regex/` against `$0`) and actions
are Tcl scripts.

## Package

```tcl
package require tclutils::tuawk 0.2
```

## API

- `tuawk::run text rules ?-fs SEP? ?-ofs SEP? ?-ors SEP?` -> collected output
- `tuawk::file path rules ...`                            -> over a file

`rules` is a flat list of pattern/action pairs:

- Pattern: empty matches always; `/regex/` matches `$0`; otherwise a Tcl `expr`
  (e.g. `$3 > 100`, `$NF == 0`). Special `BEGIN` / `END` run before/after records.
- Action: a Tcl script. An empty action means `emit $0`.
- Fields: `$0` (whole record), `$1`..`$NF`, `$NR`. `NR` and `NF` start at 0, so
  they are set in `BEGIN` and in `END` even without any record.
- Variables set in actions persist across records (like awk globals), ideal for
  aggregation with BEGIN/END. All rules of one call run in one private frame
  (a coroutine in a sandbox namespace that is deleted afterwards): `set x`
  always creates a rule variable and never touches a global `x`, under
  Tcl 8.6 and 9 alike. `variable x` is not needed (but still works).
- In an action, `break` skips the remaining rules for the current record (like
  awk `next`); `continue` goes on with the next rule.
- `emit args...` prints (joined by OFS, terminated by ORS).

Options: `-fs` (default whitespace runs; one char = `split`; multiple = regex),
`-ofs` (default `" "`), `-ors` (default `"\n"`).

Errors: unknown option or an option without value `TCLUTILS TUAWK OPTION`;
an odd `rules` list `TCLUTILS TUAWK RULES`. Errors in patterns and actions
pass through unchanged (a field beyond `NF`: `TCL LOOKUP VARNAME n`).

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
