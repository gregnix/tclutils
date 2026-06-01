# tclutils::tuxargs

`tuxargs` provides xargs-like batching and command-prefix application in pure Tcl.

## Package

```tcl
package require tclutils::tuxargs 0.1
```

## Commands

```tcl
::tclutils::tuxargs::batches items ?-n count? ?-skipempty bool?
::tclutils::tuxargs::apply items commandPrefix ?-n count? ?-collect bool? ?-skipempty bool?
::tclutils::tuxargs::command items commandPrefix ?options?
```

## Example

```tcl
set batches [::tclutils::tuxargs::batches $files -n 20]
::tclutils::tuxargs::apply $files {puts} -n 1
```
