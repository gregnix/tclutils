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
-maxdist N            non-negative integer (default 1); 0 = exact substring
-nocase 0|1           (default 0)
-invert 0|1           lines without a match (default 0)
-linenumbers 0|1      each match as {number line} (default 0)
-count 0|1            only the number of matches (default 0)
-fileswithmatches 0|1 file/files only: just the paths with a match (default 0)
-filenames 0|1        file only: each match as {path match} (default 0);
                      files always adds the path
```

A line matches when `tufuzzy::searchDistance pattern line <= -maxdist`.

`search` splits the text into lines like `file` reads them: a final `\n` ends
the last line and does not start an empty one; an empty text has no lines. A
text has no file name, so `search` and `match` accept `-filenames` and
`-fileswithmatches` but ignore them.

Errors:

```text
unknown option / missing value     TCLUTILS TUAGREP OPTION
extra positional arguments         TCLUTILS TUAGREP ARGS
-maxdist not an integer >= 0       TCLUTILS TUAGREP MAXDIST
boolean option not a boolean       TCLUTILS COMMON BOOLEAN -name
```

A file that cannot be opened raises the error of `open` (`POSIX ENOENT ...`).

## Example

```tcl
package require tclutils::tuagrep 0.2
::tclutils::tuagrep::search "gamma line\nbeta line" gama -maxdist 1
```
