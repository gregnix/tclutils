# tclutils::tulint

Static checks for Tcl sources. The module returns findings as data and
prints nothing; `bin/tulint.tcl` is the command line. Pure Tcl, no Tk,
Tcl 8.6+ / 9.x.

The rule names are the identifiers of the book *Tcl/Tk Quality*
(`ENC-1`, `TST-3` ...): each finding names the entry that explains the
error class, the test that finds it and the fix.

## API

```tcl
::tclutils::tulint::check paths ?-rules names|all? ?-exclude patterns?
;# -> list of findings, each {file F line N rule R severity S message M}
::tclutils::tulint::checkFile path ?-rules names|all?
::tclutils::tulint::checkText text ?-file name? ?-rules names|all?
::tclutils::tulint::rules        ;# -> list of {name severity description}
::tclutils::tulint::register name severity description cmd
::tclutils::tulint::unregister name
::tclutils::tulint::summary findings          ;# -> {error N warning N info N}
::tclutils::tulint::format findings ?-format text|json?
```

`check` walks directories and takes `*.tcl`, `*.tm` and `*.test`;
`.git`, `nogit` and every path matching a glob of `-exclude` are skipped.
Files are read as UTF-8; a file that is not valid UTF-8 is the finding
`FILE` (error), and its rules are not run. `checkText` decides by the
`-file` name which rules apply (a `*.test` file, a `pkgIndex.tcl` ...).

Unknown options, a missing value and an unknown rule name are errors
(`{TCLUTILS TULINT OPTION}`, `RULE`); a typo is never ignored.
`format -format json` escapes through `tclutils::tujson`.

## Rules

| Rule | Severity | Finds |
|---|---|---|
| `ENC-1` | warning | non-ASCII characters in a `*.test` file (outside comments): under Tcl 8.6 safe only when the runner starts it with `-encoding utf-8`, as `tutestrun` 0.2 does |
| `ENC-2` | error | `pkgIndex.tcl` sources a file without `-encoding` |
| `ENC-3` | warning | non-ASCII characters outside comments in a `*.tcl` script, `tests/all.tcl` and helper scripts included (`*.tm` modules are read as UTF-8 by `tcl::tm`) |
| `TST-3` | error | the same test name twice in a file; definitions in two branches of one `if` or `switch` are alternatives and do not count |
| `DAT-2` | info | `open` with mode `w`, `wb`, `w+` or `TRUNC` in a `*.tm` or `*.tcl` file: the target is empty at once, a failed write loses the old content; write through `common::replaceFile`. A path word with `tmp` in it counts as a temporary file; `*.test` files are skipped |

`TST-3` reads complete commands (`info complete`), not lines, and
descends into braced bodies (`namespace eval`, `if`, `foreach` ...);
braces inside strings do not confuse it.

## Own rules

A rule is a command called as `{*}cmd file text`; it returns a list of
`{line message}` pairs. Other packages register project conventions
this way:

```tcl
proc ::myproj::noSqlite3 {file text} {
    set out {}; set n 0
    foreach l [split $text \n] {
        incr n
        if {[regexp {package\s+require\s+sqlite3\M} $l]} {
            lappend out [list $n "use tdbc::sqlite3"]
        }
    }
    return $out
}
::tclutils::tulint::register MY-1 warning "sqlite3 instead of tdbc" ::myproj::noSqlite3
```

## Suppressing a finding

`# tulint: ignore RULE ?RULE ...?` on a line of its own applies to the
next line; `;# tulint: ignore RULE` at the end of a line applies to that
line. Only the named rules are suppressed.

## Command line

```
tclsh bin/tulint.tcl ?--rules {ENC-2 TST-3}? ?--exclude pattern? \
    ?--severity error|warning|info? ?--json? ?--list? path ?path ...?
```

Exit code 0 without an error finding, 1 with at least one, 2 for a wrong
call. `--severity` only filters what is printed; the exit code always
counts every error.

## Errors

`{TCLUTILS TULINT OPTION}`, `{TCLUTILS TULINT RULE}`,
`{TCLUTILS TULINT SEVERITY}`. A file that cannot be opened raises the
error of `open`.
