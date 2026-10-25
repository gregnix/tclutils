# tclutils::tutsort

`tsort`-like topological sort in pure Tcl.

## API
```tcl
package require tclutils::tutsort 0.2
::tclutils::tutsort::pairs tokenList
::tclutils::tutsort::text  text
::tclutils::tutsort::file  path
```
Tokens are read in pairs: each pair `u v` means "u must come before v". A self-pair
`u u` declares an isolated node with no ordering. Nodes that become free are emitted
in first-seen order (stable). A cycle raises `TCLUTILS TUTSORT CYCLE` with the message
`input contains a cycle involving: ...`, which names only the nodes that lie on
a cycle (in first-seen order), not nodes that merely follow a cycle; an odd
token count raises `TCLUTILS TUTSORT ODD`.

## CLI
```bash
printf 'a b\nb c\n' | tclsh bin/tutsort.tcl
```
