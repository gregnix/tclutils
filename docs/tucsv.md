# tclutils::tucsv

Small CSV helpers written in pure Tcl.

`tuCSV` handles common CSV tasks:

- parse one CSV line into a Tcl list
- join a Tcl list into one CSV line
- parse CSV text into rows
- read/write CSV files
- convert rows into dictionaries using a header row

It is intentionally small and dependency-free. It is not intended to replace a
full CSV/database import framework.

## Load

```tcl
tcl::tm::path add /path/to/tclutils/lib/tm
package require tclutils::tucsv
```

## Parse one line

```tcl
set row [::tclutils::tucsv::parseLine {a,"b,c","d""e"}]
# -> a {b,c} {d"e}
```

Options:

```tcl
-delimiter ,
-quote "
-trim 0
```

## Join one line

```tcl
set line [::tclutils::tucsv::joinLine [list a {b,c} {d"e}]]
# -> a,"b,c","d""e"
```

Options:

```tcl
-delimiter ,
-quote "
-alwaysQuote 0
```

## Parse text

```tcl
set rows [::tclutils::tucsv::parse "name,city\nAlice,Berlin"]
# -> {name city} {Alice Berlin}
```

Quoted fields may contain newlines.

## Convert rows to dicts

```tcl
set rows [::tclutils::tucsv::parse "name;city\nAlice;Berlin" -delimiter {;}]
set dictRows [::tclutils::tucsv::dicts $rows]
# -> {name Alice city Berlin}
```

## Files

```tcl
set rows [::tclutils::tucsv::file data.csv -delimiter {;}]
::tclutils::tucsv::writeFile out.csv $rows
```

## Options (0.37.0)

- A leading UTF-8 BOM is stripped automatically on `parse`.
- `-strict 0` recovers from an unterminated quoted field instead of raising
  `{TCLUTILS TUCSV QUOTE}` (useful for loading messy real-world exports). The
  default `-strict 1` keeps the previous strict behaviour.

## Additional exported commands

Documented for completeness (same module, also covered by the test suite):

```tcl
tucsv::text rows args                          ;# format ROWS (a list of field lists) as CSV text; -delimiter -quote -alwaysQuote -newline
```
