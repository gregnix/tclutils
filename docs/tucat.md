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
