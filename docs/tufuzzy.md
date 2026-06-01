# tclutils::tufuzzy

Fuzzy matching primitives in pure Tcl.

## Commands

```tcl
::tclutils::tufuzzy::distance a b ?-nocase 0|1?
::tclutils::tufuzzy::searchDistance pattern text ?-nocase 0|1?
::tclutils::tufuzzy::similarity a b ?-nocase 0|1?
::tclutils::tufuzzy::subsequence pattern text ?-nocase 0|1?
::tclutils::tufuzzy::bestMatch pattern candidates ?-nocase 0|1?
```

`distance` computes Levenshtein edit distance. `searchDistance` computes the
minimum edit distance from a pattern to any substring of a text. `subsequence`
implements fzf-style ordered subsequence matching.

## Examples

```tcl
package require tclutils::tufuzzy
::tclutils::tufuzzy::distance kitten sitting
::tclutils::tufuzzy::bestMatch colour {color flavour}
```
