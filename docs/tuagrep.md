# tclutils::tuagrep

Approximate grep built on `tclutils::tufuzzy`.

## Commands

```tcl
::tclutils::tuagrep::search text pattern ?options?
::tclutils::tuagrep::file filename pattern ?options?
::tclutils::tuagrep::files fileList pattern ?options?
::tclutils::tuagrep::match line pattern ?options?
```

## Options

```text
-maxdist N
-nocase 0|1
-invert 0|1
-linenumbers 0|1
-count 0|1
-fileswithmatches 0|1
-filenames 0|1
```

A line matches when `tufuzzy::searchDistance pattern line <= -maxdist`.

## Example

```tcl
package require tclutils::tuagrep
::tclutils::tuagrep::search "gamma line\nbeta line" gama -maxdist 1
```
