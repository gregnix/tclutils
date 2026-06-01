# tclutils::tutr

Small `tr`-like text transformation helpers.

## API

```tcl
::tclutils::tutr::translate {abc cab} abc xyz
::tclutils::tutr::delete {a1b2c3} 0-9
::tclutils::tutr::squeeze {aaabccc} ac
```

Commands:

- `translate text set1 set2`
- `delete text set1`
- `squeeze text set1`
- `file path set1 set2 ?-delete bool? ?-squeeze bool?`

Character sets support literal characters and simple ranges like `a-z` or `0-9`.
