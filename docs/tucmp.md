# tclutils::tucmp

`tucmp` vergleicht zwei Datenströme oder Dateien byteweise.

```tcl
package require tclutils::tucmp

set r [::tclutils::tucmp::files a.bin b.bin]
dict get $r equal
```

## Befehle

```tcl
::tclutils::tucmp::data data1 data2
::tclutils::tucmp::files file1 file2
::tclutils::tucmp::equal file1 file2
::tclutils::tucmp::firstDifference file1 file2
```

`data` und `files` liefern ein Dict:

```text
equal  offset  byte1  byte2  size1  size2
```

`offset` ist 0-basiert. Bei identischen Daten ist `offset` gleich `-1`.
