# tclutils::tujoin

` tclutils::tujoin ` joins two simple delimited text sources on a selected
field. It is inspired by Unix `join`, but intentionally small.

## Load

```tcl
package require tclutils::tujoin 0.1.2
```

## Examples

```tcl
set left  "1;Ada\n2;Linus\n"
set right "1;Berlin\n2;Helsinki\n"

::tclutils::tujoin::texts $left $right -delimiter ";"
# -> 1;Ada;Berlin
# -> 2;Linus;Helsinki
```

## Options

```text
-delimiter d     input field separator (default: tab); several characters
                 form one literal separator; must not be empty
-joiner j        output field separator (default: same as -delimiter)
-leftfield n     key field on the left, 1-based (default 1)
-rightfield n    key field on the right, 1-based (default 1)
-header bool     first line of both sides is a header line (default 0)
-outer mode      none (inner join, default), left, right, full
-anti mode       none (default), left, right, both
```

Field numbers are 1-based. The joined result contains the key once, then the
remaining left fields, then the remaining right fields.

`-outer left|right|full` also keeps the unmatched rows of the named side(s);
the missing side is padded with empty fields (as many as the widest row of
that side has). The default `-outer none` is the inner join.

`-anti left|right|both` emits only the unmatched rows from the left, right,
or both sides: the key plus that side's remaining fields, with no padding for
the missing side. With `-header 1` the header line is not emitted. `-anti`
cannot be combined with `-outer`.

All options apply to `lines`, `texts` and `files` alike, for example
`lines` with `-anti` and `-joiner`:

```tcl
::tclutils::tujoin::lines {1;Ada 3;Grace} {1;Berlin} \
    -delimiter ";" -anti left -joiner ,
# -> 3,Grace
```

## Errors

```text
unknown option / missing value   TCLUTILS COMMON OPTION -name
-leftfield, -rightfield < 1      TCLUTILS COMMON INTEGER -name
-header not a boolean            TCLUTILS COMMON BOOLEAN -header
unknown -outer / -anti value     TCLUTILS COMMON VALUE -outer|-anti
-outer together with -anti       TCLUTILS TUJOIN COMBINE
empty -delimiter                 TCLUTILS COMMON DELIMITER
```

## Additional exported commands

Documented for completeness (same module, also covered by the test suite):

```tcl
tujoin::files leftPath rightPath args          ;# relational join of two files on a key field (file variant of lines)
tujoin::lines leftLines rightLines args        ;# relational join of two line lists on a key field; all options above
```
