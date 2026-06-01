# tclutils::tunumfmt

`numfmt`-like human-readable number formatting in pure Tcl (SI and IEC).

## API
```tcl
::tclutils::tunumfmt::toHuman   number ?-to si|iec? ?-precision N?
::tclutils::tunumfmt::fromHuman string ?-from si|iec|auto?
::tclutils::tunumfmt::text      text   ?-mode to|from? ?...?
::tclutils::tunumfmt::file      path   ?-mode to|from? ?...?
```
`toHuman` scales a number to a unit suffix (SI uses 1000, IEC 1024), e.g. `1500`
becomes `1.5K` and `1536 -to iec` becomes `1.5Ki`. `fromHuman` parses such strings
back; `-from auto` treats a trailing `i` as IEC. Default precision is 1 decimal;
values below the first unit are emitted as integers.

## CLI
```bash
printf '1500\n1048576\n' | tclsh bin/tunumfmt.tcl
tclsh bin/tunumfmt.tcl -mode from sizes.txt
```
