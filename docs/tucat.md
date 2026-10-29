# tclutils::tucat

Small `cat`-like helpers.

```tcl
package require tclutils::tucat
puts [::tclutils::tucat::file README.md]
puts [::tclutils::tucat::file README.md -number 1]
```

Commands:

- `text text ?options?`
- `file path ?options?`
- `files paths ?options?`

Options:

- `-number 1` number all lines
- `-nonblank 1` number only non-empty lines

As with `cat -n`, the end of the text after the last `\n` is not a line and
gets no number, and `files` numbers the joined files in one run. Files are
joined as they are: a file without a final `\n` runs into the next one.
Unknown options raise `TCLUTILS COMMON OPTION -name` (0.2; 0.1 numbered an
empty last line, started at 1 for every file and ignored unknown options).
