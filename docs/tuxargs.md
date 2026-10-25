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

## Options

```text
-n count         at most count items per batch (default 100)
-skipempty bool  drop empty items first (default 1)
-collect bool    apply/command: collect the results (default 1)
```

## Example

```tcl
set batches [::tclutils::tuxargs::batches $files -n 20]
::tclutils::tuxargs::apply $files {puts} -n 1
```
