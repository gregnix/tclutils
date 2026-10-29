# tclutils::tupatch

Apply unified diffs in pure Tcl. This module is the counterpart to
`tclutils::tudiff`.

## Package

```tcl
package require tclutils::tupatch 0.3
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

Both take any Tcl boolean (`0`/`1`, `yes`/`no`, `true`/`false`, `on`/`off`);
anything else raises `{TCLUTILS COMMON BOOLEAN -reverse}` or `-strict`.

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
- `{TCLUTILS COMMON BOOLEAN -reverse}`, `{TCLUTILS COMMON BOOLEAN -strict}`: the
  option value is not a boolean.

## Notes

`tupatch` uses the same line model as `tudiff`: lines are split and re-joined
with `\n`. The line end at the end of the text is kept: a source ending with
`\n` gives a result ending with `\n`. The marker `\\ No newline at end of file`
works as in `diff -u`: after a `+` line the result ends without `\n`, after a
`-` line (and none after `+`) it gets one; `-reverse` swaps both. `parse`
reports the markers as `oldNoNl` and `newNoNl` in each hunk (0.3; 0.2 always
dropped the final `\n`).
