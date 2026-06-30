# tclutils::tujoin

` tclutils::tujoin ` joins two simple delimited text sources on a selected
field. It is inspired by Unix `join`, but intentionally small.

## Load

```tcl
package require tclutils::tujoin
```

## Examples

```tcl
set left  "1;Ada\n2;Linus\n"
set right "1;Berlin\n2;Helsinki\n"

::tclutils::tujoin::texts $left $right -delimiter ";"
# -> 1;Ada;Berlin
# -> 2;Linus;Helsinki
```

Options:

```tcl
-delimiter ";"
-leftfield 1
-rightfield 1
-joiner ";"
-header 0
```

Field numbers are 1-based. The joined result contains the key once, then the
remaining left fields, then the remaining right fields.
## 0.24.0

Outer joins are available through `-outer left`, `-outer right`, and `-outer full`. The default remains the existing inner join behavior (`-outer none`). Anti-joins are available through `-anti left`, `-anti right`, and `-anti both`: they emit only the unmatched rows from the left, right, or both sides (the key plus that side's remaining fields, with no padding for the missing side). `-anti` cannot be combined with `-outer`.


## Additional exported commands

Documented for completeness (same module, also covered by the test suite):

```tcl
tujoin::files leftPath rightPath args          ;# relational join of two files on a key field (file variant of lines)
tujoin::lines leftLines rightLines args        ;# relational join of two line lists on a key field; -leftfield -rightfield -delimiter -header -outer
```
