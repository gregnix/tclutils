# tclutils::tutee

`tutee` provides tee-like helpers in pure Tcl.

## Package

```tcl
package require tclutils::tutee 0.1
```

## Commands

```tcl
::tclutils::tutee::write data paths ?-append bool? ?-stdout bool? ?-nonewline bool?
::tclutils::tutee::writeFile inputFile paths ?-append bool? ?-stdout bool?
::tclutils::tutee::copyChannel inChan outChans ?-stdout bool? ?-chunksize n?
```

## Example

```tcl
::tclutils::tutee::write "hello" {a.txt b.txt}
::tclutils::tutee::writeFile input.txt {copy1.txt copy2.txt}
```
