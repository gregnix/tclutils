# tclutils::tubookmark

Read and write the **Netscape bookmark file format** — the HTML interchange
format browsers use to import/export bookmarks. A bookmark is a dict
`{title url folder folders tags adddate}`; `folders` is the list of folder
names from the top (`{}` = top level), `folder` the same joined with `/` (for
display; ambiguous when a name holds `/`), and `tags` is a list. Entity (un)escaping reuses `tclutils::tuxml`.

Two keys appear only when the file has them: `description`, the `<DD>` text
after a link, and `toolbar`, the `folders` path of the folder marked
`PERSONAL_TOOLBAR_FOLDER="true"` that holds the bookmark. `serialize` writes
both back. Folder dates (`ADD_DATE`, `LAST_MODIFIED` on `<H3>`) and a `<DD>`
after a folder are not kept.

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
`TAGS` is split at commas. Attribute values may stand in double or single
quotes or unquoted (`HREF='…'`, `ADD_DATE=1700000000`).

`serialize` keeps folders and links in the order of the list (a folder
appears where its first bookmark is) and takes the folder path from
`folders`, else splits `folder` at `/`; a folder name with `/` stays one
folder. Up to 0.2 folders were sorted, written before the links, and a `/`
in a name made two folders.

`serialize` escapes `&`, `<`, `>` in titles and folder names, and additionally
`"` (as `&quot;`) in the `HREF`, `TAGS` and `ADD_DATE` attribute values. Every
header line starts at column 0.
