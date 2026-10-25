# tclutils::tusplit

Split files or strings into smaller parts.

## Load

```tcl
package require tclutils::tusplit 0.2
```

## Line splitting

```tcl
set files [::tclutils::tusplit::file input.txt -lines 1000 -outdir parts -prefix part -suffix .txt]
```

## Byte splitting

```tcl
set files [::tclutils::tusplit::file input.bin -bytes 1048576 -outdir parts -prefix chunk]
```

## Commands

- `splitLines text ?options?`
- `splitBytes data ?options?`
- `file path ?options?`
- `lines path n ?options?`
- `bytes path n ?options?`

## Options

```text
-lines n     lines per part (splitLines, file; default 1000)
-bytes n     bytes per part (splitBytes; default 1024); with file it
             switches to byte mode
-prefix p    start of the file name (default x)
-suffix s    end of the file name (default empty)
-digits n    digits of the running number, from 0 (default 2)
-outdir d    target directory, created if missing (default .)
```

Without `-lines` and `-bytes`, `file` splits by 1000 lines. Parts are named
`x00`, `x01`, ... Parts from `splitLines` end without `\n`.

`splitBytes` expects a byte string: every character must be in `\x00`..`\xFF`.
Convert text first, e.g. `encoding convertto utf-8 $text`. A character above
`\xFF` raises `TCLUTILS TUSPLIT BYTES` before any file is written (same under
Tcl 8.6 and 9).

## Errors

```text
-lines and -bytes together (file)   TCLUTILS TUSPLIT MODE
-outdir is a file                   TCLUTILS TUSPLIT OUTDIR
character above \xFF (splitBytes)   TCLUTILS TUSPLIT BYTES
count or -digits below 1            TCLUTILS COMMON INTEGER -name
unknown option / missing value      TCLUTILS COMMON OPTION -name
```
