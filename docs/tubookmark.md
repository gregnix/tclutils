# tclutils::tubookmark

Read and write the **Netscape bookmark file format** — the HTML interchange
format browsers use to import/export bookmarks. A bookmark is a dict
`{title url folder tags adddate}`; `folder` is a `/`-joined path ("" = top
level) and `tags` is a list. Entity (un)escaping reuses `tclutils::tuxml`.

## API

```tcl
set bms [::tclutils::tubookmark::parse $html]          ;# -> list of dicts
set html [::tclutils::tubookmark::serialize $bms -title "My Bookmarks"]
```

Commands:

- `parse html` → flat list of bookmark dicts (folder paths reconstructed from
  the nested `<H3>`/`<DL>` structure).
- `serialize bookmarks ?-title T?` → Netscape bookmark HTML, grouping bookmarks
  into nested folders by their `folder` path.

`parse` reads the document tag by tag, so the standard export layout (one
`<DT>` per line) and compact files (several links, or `<H3>`/`<DL>` and links,
on one line) give the same result; every `<A>…</A>` is one bookmark. Entities
in the title and in the `HREF`, `TAGS` and `ADD_DATE` values are unescaped;
`TAGS` is split at commas.

`serialize` escapes `&`, `<`, `>` in titles and folder names, and additionally
`"` (as `&quot;`) in the `HREF`, `TAGS` and `ADD_DATE` attribute values. Every
header line starts at column 0.
