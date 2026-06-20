# tclutils::tummdb

Pure-Tcl reader for the MaxMind DB (`.mmdb`) binary format.

`tummdb` resolves IPv4 and IPv6 addresses to their data records in GeoLite2,
GeoIP2 and DB-IP databases. It reads version 2.0 of the binary format and
builds on `tclutils::tubin` for all binary primitives.

## Package

```tcl
package require tclutils::tubin 0.2
package require tclutils::tummdb 0.1
```

## Open and close

```tcl
set h [::tclutils::tummdb::open /path/to/GeoLite2-City.mmdb]
# ... lookups ...
::tclutils::tummdb::close $h
```

`open` loads the file into memory and returns a handle. It throws
`TCLUTILS TUMMDB FORMAT` if the file is not a valid MaxMind DB.

## Metadata

```tcl
set m [::tclutils::tummdb::metadata $h]
dict get $m database_type    ;# e.g. GeoLite2-City
dict get $m ip_version       ;# 4 or 6
dict get $m record_size      ;# 24, 28, or 32
```

## Lookup

```tcl
set r [::tclutils::tummdb::lookup $h 81.2.69.142]
puts [dict get $r country iso_code]   ;# GB
puts [dict get $r city names en]      ;# London
puts [dict get $r location latitude]  ;# 51.5142
```

`lookup` returns the decoded record as a nested structure (maps become
dictionaries, arrays become lists, localized names live under a `names`
sub-dictionary), or the empty string if the address is not in the database.

## Error codes

| Error code | Meaning |
| --- | --- |
| `TCLUTILS TUMMDB FORMAT` | File is not a valid MaxMind DB |
| `TCLUTILS TUMMDB HANDLE` | Unknown handle passed to a command |
| `TCLUTILS TUMMDB RECORDSIZE` | Unsupported tree record size |
| `TCLUTILS TUMMDB TYPE` | Unsupported data type in the record |

## Notes

The whole database is held in memory while open. The interpretation of record
fields (which keys exist) is defined by the database, not by this reader.
`open` and `close` are intentionally not exported (they would clash with the
Tcl built-ins on `namespace import`); call them fully qualified.
