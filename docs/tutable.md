# tclutils::tutable

Render a text table from headers and rows. Two styles: `markdown` (GitHub pipe
table, the default) and `box` (ASCII `+`/`-`/`|` borders). Per-column alignment
(`l`/`r`/`c`) is supported. Pure Tcl; uses `tclutils::common` for options.

```tcl
tutable::render {Name Age} {{Alice 30} {Bob 7}}
tutable::render {Item Qty} {{Apples 12} {Pears 3}} -align {l r} -style box
```

Rows may be ragged: missing trailing cells render empty. A row with more cells
than there are headers raises `{TCLUTILS TUTABLE COLUMNS}`; nothing is dropped
silently. An empty header list raises `{TCLUTILS TUTABLE HEADERS}`. `-style`
other than `markdown`/`box`, or an alignment other than `l`/`r`/`c`, raises
`{TCLUTILS TUTABLE OPT}`.

In `markdown` every column is at least three characters wide, the width of the
separator cell (`:--`, `--:`, `:-:`), so cells and separator line up. `box`
columns keep the width of their longest cell.

This is a string renderer; for the Unix `column`-style filter use `tucolumn`.
