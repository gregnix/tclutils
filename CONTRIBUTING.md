# Contributing to tclutils

Rules and templates for anyone adding or updating a module. Following them keeps
the library consistent, drop-in, and dual-compatible with Tcl 8.6 and Tcl 9.

## 1. Non-negotiable rules

1. **Pure Tcl, Tcl-core only.** No external dependencies. `tcllib`/`tklib` are
   *not* allowed as a hard `package require` in a module. If you want their
   convenience, use the optional-with-fallback pattern (try/catch around the
   `package require`, pure-Tcl fallback otherwise) — never a mandatory require.
2. **Version line:** `package require Tcl 8.6-` (open-ended). Never bare `8.6`
   (fails on Tcl 9 with a version conflict).
3. **No `global`.** Keep state in proc parameters or `namespace eval` variables.
4. **No builtin command names as proc names**, with the single documented
   exception of `file` (and `text`). If you name a proc `file`, every internal
   call to the builtin must be fully qualified as `::file` (e.g. `::file tail`).
5. **Error codes:** every error uses
   `return -code error -errorcode {TCLUTILS <MOD> <REASON>} "message"`
   where `<MOD>` is the upper-case module name (e.g. `TUNL`) and `<REASON>` is a
   short upper-case token (e.g. `STYLE`, `OPTION`, `VALUE`).
6. **Regex:** the word boundary is `\y`, never `\b` (in Tcl ARE `\b` is a
   backspace). No look-behind (not available in 8.6).
7. **Tcl 9 gotchas:**
   - Never `package require zlib` unconditionally; zlib is a core command on 9.
     Guard it: `if {[package vcompare [info tclversion] 9.0] < 0} {package require zlib}`.
   - Never use `-encoding binary`; it is gone on 9. Use `-encoding iso8859-1`
     together with `-translation binary` for byte-exact I/O.
8. **License/clean-room:** MIT. Do not copy text or code from GNU coreutils,
   grep, sed, diffutils, or other GPL sources. Documentation must be original
   (the man-page header attests this).

## 2. Use the shared helpers

Prefer `tclutils::common` over re-rolling basics:

- `readFile path`, `readBinaryFile path`, `writeFile path data ?mode?`
- `splitLines text`            (drops the trailing empty line from a final `\n`)
- `splitDelimited line delim`  (multi-char delimiters supported)
- `parseOptions defaults args` (defaults is a dict; rejects unknown options)
- `ensureBoolean value name`, `ensurePositiveInteger value what`

## 3. File layout (one module = five files)

```
lib/tm/tclutils/<name>-0.1.tm   the library (the source of truth)
tests/<name>.test               tcltest suite
bin/<name>.tcl                  thin CLI wrapper
docs/<name>.md                  short API + CLI documentation
man/man1/<name>.1               man page (same content as docs, troff)
```

Naming: lower-case, `tu` prefix (`tunl`, `tuseq`, ...). Private/internal procs
are prefixed with `_` and are not exported.

## 4. Public API shape

Provide a text-in/text-out core plus a file convenience, e.g.:

- `::tclutils::<mod>::text text ?options?`   operate on a string
- `::tclutils::<mod>::file path ?options?`    read the file, then call `text`

Conventions:

- Line-oriented modules **preserve a trailing newline** (do not invent or drop one).
- Options come from a `parseOptions` defaults dict; validate values with the
  `ensure*` helpers; reject unknown options.
- Any randomness must accept a `-seed` so output is reproducible and testable;
  use a self-contained generator (do not depend on the interpreter's global
  `rand()` state).

## 5. Verification (required before submitting)

Run the **full suite on both interpreters**, redirecting stdin (some CLIs read it):

```bash
tclsh tests/all.tcl </dev/null            # Tcl 8.6
tclsh9.0 tests/all.tcl </dev/null         # Tcl 9.x  (set LANG=C.UTF-8 if needed)
```

`all.tcl` auto-discovers `tests/*.test`. A change is acceptable only with
**0 failures** on both. Skips must be symmetric and intentional (e.g. a feature
that only exists on one Tcl version).

## 6. Integration checklist (when adding a new module)

1. `lib/tm/tclutils-<ver>.tm` (umbrella): add `package require tclutils::<mod> 0.1`
   and bump `package provide tclutils <newver>`.
2. `CHANGELOG.md`: prepend an entry under a new `## <newver> - <date>` heading.
3. `README.md`: bump the version, the package count, the tm filename in the tree
   listing, and add a "New in <newver>" bullet.
4. `docs/module-status.md`: add a row (Module | Scope status | Notes).
5. `docs/coreutils-mapping.md`: add a row if the module maps to a Unix tool.
6. `man/man1/*.1`: bump the `.TH` version on existing pages if the release
   version changed; add the new page.

## 7. Templates

### 7.1 Module — `lib/tm/tclutils/<name>-0.1.tm`

```tcl
# tclutils::<name> -- one-line summary
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::<name> {
    namespace export text file
    variable version 0.1
}

proc ::tclutils::<name>::_options {args} {
    set defaults [dict create -example 0]
    set opts [::tclutils::common::parseOptions $defaults {*}$args]
    # validate, e.g.:
    # ::tclutils::common::ensureBoolean [dict get $opts -example] -example
    return $opts
}

# Operate on a string. Preserve a trailing newline for line-oriented tools.
proc ::tclutils::<name>::text {text args} {
    set opts [_options {*}$args]
    set trailing 0
    set lines [split $text \n]
    if {$text ne "" && [string index $text end] eq "\n"} {
        set lines [lrange $lines 0 end-1]
        set trailing 1
    }
    set out {}
    foreach line $lines {
        lappend out $line   ;# ... transform ...
    }
    set result [join $out \n]
    if {$trailing} { append result \n }
    return $result
}

proc ::tclutils::<name>::file {path args} {
    return [text [::tclutils::common::readFile $path] {*}$args]
}

package provide tclutils::<name> 0.1
```

### 7.2 Test — `tests/<name>.test`

```tcl
package require tcltest
namespace import ::tcltest::*
set root [file dirname [file dirname [file normalize [info script]]]]
tcl::tm::path add [file join $root lib tm]
package require tclutils::<name> 0.1

test <name>-1.1 {basic behaviour} {
    ::tclutils::<name>::text "a\nb"
} "a\nb"

test <name>-1.2 {trailing newline preserved} {
    ::tclutils::<name>::text "a\n"
} "a\n"

test <name>-1.3 {error code on bad option} {
    catch {::tclutils::<name>::text x -example bogus} m o
    dict get $o -errorcode
} {TCLUTILS <MOD> EXAMPLE}

cleanupTests
```

### 7.3 CLI — `bin/<name>.tcl`

```tcl
#!/usr/bin/env tclsh
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::<name> 0.1
proc usage {} { puts stderr "usage: <name> ?-example 0|1? ?file?"; exit 2 }
set opts {}; set files {}; set i 0
while {$i < [llength $argv]} {
    set a [lindex $argv $i]
    if {$a in {-example}} {
        incr i; if {$i >= [llength $argv]} usage
        lappend opts $a [lindex $argv $i]
    } elseif {[string match -* $a]} { usage } else { lappend files $a }
    incr i
}
if {[llength $files]} {
    set s [::tclutils::<name>::file [lindex $files 0] {*}$opts]
} else {
    set s [::tclutils::<name>::text [read stdin] {*}$opts]
}
# clean output: exactly one trailing newline, nothing for empty output
puts -nonewline $s
if {$s ne "" && [string index $s end] ne "\n"} { puts "" }
```

### 7.4 Documentation — `docs/<name>.md`

```markdown
# tclutils::<name>

One-line summary (which Unix tool it mirrors, if any).

## API
\`\`\`tcl
::tclutils::<name>::text text ?options?
::tclutils::<name>::file path ?options?
\`\`\`
Options: `-example 0|1` (default 0), ...

## CLI
\`\`\`bash
tclsh bin/<name>.tcl file.txt
\`\`\`
```

### 7.5 Man page — `man/man1/<name>.1`

```troff
'\"
'\" Copyright (c) 2026 Gregor Ebbing
'\" SPDX-License-Identifier: MIT
'\"
'\" Original documentation for the tclutils library.
'\" Not copied or derived from GNU coreutils, GNU grep, GNU sed,
'\" GNU diffutils, or other GPL-licensed manual sources.
'\"
.TH <name> 1 <ver> tclutils "Tcl Utility Command"
.SH NAME
<name> \- thin CLI wrapper for tclutils::<name>
.SH SYNOPSIS
.nf
<name> ?-example 0|1? ?file?
.fi
.SH DESCRIPTION
.PP
The <name> command is a thin wrapper around the Tcl package tclutils::<name>.
The primary API remains the Tcl library; see <name>(n) for procedures, options,
and semantics.
.PP
.nf
tclsh bin/<name>.tcl ...
.fi
```

## 8. Updating an existing module

- Keep the public API backward compatible; if you must break it, say so in the
  CHANGELOG and bump the release version accordingly.
- Add tests for the new behaviour and for any bug you fix (regression test).
- Re-run the full suite on both interpreters; 0 failures is the gate.
- If behaviour or options changed, update `docs/<name>.md` and the man page.
