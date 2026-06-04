# tclutils::tutable

Render a text table from headers and rows. Two styles: `markdown` (GitHub pipe
table, the default) and `box` (ASCII `+`/`-`/`|` borders). Per-column alignment
(`l`/`r`/`c`) is supported. Pure Tcl; uses `tclutils::common` for options.

```tcl
tutable::render {Name Age} {{Alice 30} {Bob 7}}
tutable::render {Item Qty} {{Apples 12} {Pears 3}} -align {l r} -style box
```

Rows may be ragged: missing trailing cells render empty. `-style` other than
`markdown`/`box`, or an alignment other than `l`/`r`/`c`, raises
`{TCLUTILS TUTABLE OPT}`. This is a string renderer; for the Unix `column`-style
filter use `tucolumn`.
