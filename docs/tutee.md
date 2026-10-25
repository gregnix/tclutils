# tclutils::tutee

`tutee` provides tee-like helpers in pure Tcl.

## Package

```tcl
package require tclutils::tutee 0.2
```

## Commands

```tcl
::tclutils::tutee::write data paths ?-append bool? ?-stdout bool? ?-nonewline bool?
::tclutils::tutee::writeFile inputFile paths ?-append bool? ?-stdout bool?
::tclutils::tutee::copyChannel inChan outChans ?-stdout bool? ?-chunksize n?
```

## Options

```text
-append bool      append instead of overwrite (write, writeFile; default 0)
-stdout bool      also write to stdout (default 0)
-nonewline bool   write only: no newline at the end (default 0)
-chunksize n      copyChannel only: characters per read (default 8192)
```

`write` writes `data` with `puts`, so a `\n` is appended unless
`-nonewline 1`; it returns `data`. `writeFile` reads `inputFile` as text and
writes the content unchanged, without an extra `\n`; it returns the content.
`copyChannel` returns the number of characters copied (bytes for binary
channels); the caller opens and closes the channels.

`write` (and `writeFile`) open every target before anything is written, without
truncating. Only when all targets are open are they emptied (unless
`-append 1`). If a target cannot be opened, the channels already opened are
closed, files created by this call are removed again, existing files keep their
content, and the error of `open` is raised (e.g. `POSIX ENOENT ...`).

Option errors: `TCLUTILS COMMON BOOLEAN -name`,
`TCLUTILS COMMON INTEGER -chunksize`, `TCLUTILS COMMON OPTION -name`.

## Example

```tcl
::tclutils::tutee::write "hello" {a.txt b.txt}
::tclutils::tutee::writeFile input.txt {copy1.txt copy2.txt}
```
