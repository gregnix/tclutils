# tclutils::tupatch

Apply unified diffs in pure Tcl. This module is the counterpart to
`tclutils::tudiff`.

## Package

```tcl
package require tclutils::tupatch 0.1
```

## API

```tcl
::tclutils::tupatch::parse patchText
::tclutils::tupatch::text sourceText patchText ?-reverse 0|1? ?-strict 0|1?
::tclutils::tupatch::fromFile sourceFile patchText ?-reverse 0|1? ?-strict 0|1?
```

## Options

- `-reverse 0|1`: apply the patch backwards. Default: `0`.
- `-strict 0|1`: verify context and delete lines against the source. Default: `1`.

## Example

```tcl
package require tclutils::tudiff
package require tclutils::tupatch

set old "alpha\nbeta\n"
set new "alpha\nBETA\n"

set patch  [::tclutils::tudiff::unifiedText $old $new]
set result [::tclutils::tupatch::text $old $patch]
```

## Error codes

- `{TCLUTILS TUPATCH CONTEXT}`: context/delete line does not match the source.
- `{TCLUTILS TUPATCH RANGE}`: hunk position is outside the source or overlaps an earlier hunk.
- `{TCLUTILS COMMON OPTION ...}`: invalid option from `common::parseOptions`.

## Notes

`tupatch` uses the same line model as `tudiff`: lines are split and re-joined
with `\n`. The special unified-diff marker `\\ No newline at end of file` is
accepted as metadata but final-newline details are not modeled separately.
