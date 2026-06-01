# tclutils::tugrep

Portable grep-like routines in pure Tcl.

## Load

```tcl
package require tclutils::tugrep
```

## Main commands

```tcl
::tclutils::tugrep::search text pattern ?options?
::tclutils::tugrep::file filename pattern ?options?
::tclutils::tugrep::files fileList pattern ?options?
::tclutils::tugrep::match line pattern ?options?
```

## Options

```text
-nocase 0|1             case-insensitive search
-linenumbers 0|1        return {lineNumber line}
-invert 0|1             return non-matching lines
-fixed 0|1              use literal substring search instead of regexp
-count 0|1              return match count
-fileswithmatches 0|1   return only filenames with matches
-filenames 0|1          prefix matches with filename in multi-file style
```

## Examples

```tcl
set lines [::tclutils::tugrep::file app.log {ERROR}]
```

```tcl
set lines [::tclutils::tugrep::file app.log {error} -nocase 1 -linenumbers 1]
```

```tcl
set count [::tclutils::tugrep::file app.log {ORA-} -count 1]
```

```tcl
set matchingFiles [::tclutils::tugrep::files $files {TODO} -fileswithmatches 1]
```
