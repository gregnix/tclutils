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

`-nocase` (default 0) must be a boolean. Errors:

```text
unknown option / missing value     TCLUTILS TUFUZZY OPTION
extra positional arguments         TCLUTILS TUFUZZY ARGS
-nocase not a boolean              TCLUTILS COMMON BOOLEAN -nocase
```

## Examples

```tcl
package require tclutils::tufuzzy 0.2
::tclutils::tufuzzy::distance kitten sitting
::tclutils::tufuzzy::bestMatch colour {color flavour}
```
