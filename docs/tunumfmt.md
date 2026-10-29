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
back; `-from auto` treats an `i` right after the unit letter as IEC, so `2Ki`
and `2KiB` are 2048 while `2K` and `2KB` are 2000. Default precision is 1 decimal;
values below the first unit are emitted as integers.

`K` without `i` always means 1000, as in GNU `numfmt --to=si`: 1500 and
1536 both become `1.5K` at precision 1, and `1.5K` reads back as 1500. For
byte counts use `-to iec` (`1536` → `1.5Ki`) or `tusize::human`, which
writes `1.5 KiB` for 1024-based and `1.5 kB` (with `-si 1`) for 1000-based
values. Raise `-precision` when 1500 and 1536 must look different
(`1.50K`, `1.54K`).

## CLI
```bash
printf '1500\n1048576\n' | tclsh bin/tunumfmt.tcl
tclsh bin/tunumfmt.tcl -mode from sizes.txt
```
