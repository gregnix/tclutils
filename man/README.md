# tclutils manpages

Nroff manual pages for **tclutils 0.68.0**.

`man/mann/*.n` is generated from `docs/*.md`. From the tclutils directory:

```bash
tclsh tools/md2man.tcl docs/<module>.md
```

The `.TH` version is read from `lib/tm/tclutils/<module>-X.Y.tm`. Edit the
Markdown and regenerate the page. The pages are project documentation, not
copied from GNU manuals.

`man/man1/` holds CLI pages for the wrappers that have one. `md2man` writes
that section when the Markdown declares `section: 1` or the run passes
`-section 1`.

Where the rest of the documentation lives:
[`docs/guide/guide-tclutils.md`](../docs/guide/guide-tclutils.md).

## Layout

```text
man/
├── mann/   Tcl package API pages, generated from docs/
└── man1/   CLI command pages
```

## Viewing

```bash
man ./man/mann/tufind.n
man ./man/man1/tufind.1
```

or with a custom path:

```bash
MANPATH=$PWD/man man tufind
```

## Scope

These pages describe the tclutils APIs. They do not claim GNU tool
compatibility.
