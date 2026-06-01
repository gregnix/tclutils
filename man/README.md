# tclutils manpages

Nroff manual pages for **tclutils 0.22.0**.

The pages are maintained as project documentation, not copied from GNU manuals.
They document the Tcl package APIs under `man/mann/` and the available CLI
wrappers under `man/man1/`.

## Layout

```text
man/
├── mann/   Tcl package API pages
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

These pages describe the tclutils subset APIs. They do not claim GNU tool
compatibility.
