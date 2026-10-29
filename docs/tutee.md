# tclutils::tutee

`tutee` provides tee-like helpers in pure Tcl.

## Package

```tcl
package require tclutils::tutee 0.3
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
`-nonewline 1` (unlike the shell `tee`, which adds nothing); it returns
`data`. `writeFile` copies the bytes of `inputFile` unchanged, CR and
encoding included, and returns the number of bytes (0.3; 0.2 read it as text,
wrote LF in the system encoding and returned the text).
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
