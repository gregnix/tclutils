# tclutils::tuhead

Head-like helpers.

```tcl
package require tclutils::tuhead
puts [::tclutils::tuhead::file README.md 20]
```

Commands:

- `text text ?count?` -- the first `count` lines (default 10)
- `file path ?count? ?-encoding enc?` -- the same for a file (default utf-8)

As with `head -n`, the result keeps the line ends: every line ends with `\n`,
except the last line of the input when it has none. `text` and `file` give
the same result (0.2; 0.1 `text` took the empty rest after a final `\n` as a
line, `file` dropped every line end). A count that is not an integer >= 0
raises `TCLUTILS TUHEAD COUNT`. Print with `puts -nonewline`.
