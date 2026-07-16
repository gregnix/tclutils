# Step by step: build the builder itself

Before you package any app you need the builder `build-app-zipkit-linux`. It
ships ready in the repo (`apps/bin/`), but you can also build it yourself — and
that is the **only** place `tclutils` has to be present at all. Afterwards the
builder is a self-contained single file: no installed Tcl, no installed tclutils
needed any more.

The builder builds itself here — `build-app.tcl` packages `build-app.tcl`.

## Prerequisites

1. A static **tcl basekit**, here `basekit-tcl`.
2. The **tclutils tree** with `apps/build-app/build-app.tcl` and the module
   `tclutils::tuzipfs` (0.2+) under `lib/tm/`.

## Step 1 — Starting point

Work in `apps/bin/` and put just the basekit there:

```bash
cd tclutils/apps/bin
cp /path/to/basekit-tcl .
ls
# basekit-tcl
```

## Step 2 — Bootstrap

The raw script from `../build-app/` is run by the basekit and packages itself.
`-tm ../../lib/tm` bundles the tclutils module tree (with `tuzipfs`) into the
image, which makes the builder independent of the repo.

```bash
./basekit-tcl ../build-app/build-app.tcl -kind cli -out build-app-zipkit-linux \
    -basekit basekit-tcl \
    -app ../build-app -main build-app.tcl \
    -tm ../../lib/tm
```

```
built: build-app-zipkit-linux (3503653 bytes)
```

Why these options:

- `-kind cli` — the builder is a console tool. It runs on the tcl basekit and
  can still build GUI and Windows targets, because it always takes the standard
  library from the respective target `-basekit`.
- `-app ../build-app -main build-app.tcl` — the "app" being packaged is
  `build-app.tcl` itself; it becomes the image's `main.tcl`.
- `-tm ../../lib/tm` — bundles `tuzipfs` (and the rest of tclutils) inside.

## Step 3 — Check

`tuzipfs` is now in the image and `main.tcl` is the builder:

```bash
./basekit-tcl <<'EOF'
zipfs mount [pwd]/build-app-zipkit-linux b
puts "tuzipfs: [file exists //zipfs:/b/lib/tm/tclutils/tuzipfs-0.2.tm]"
EOF
# tuzipfs: 1
```

## Step 4 — Self-test

The fresh builder immediately builds an app — here in a completely empty
environment (`env -i`: no `tclsh`, no installed tclutils):

```bash
env -i ./build-app-zipkit-linux -kind cli -out /tmp/ftc \
    -basekit basekit-tcl -app ../find-tclconfig -main find-tclconfig.tcl
# built: /tmp/ftc (3178040 bytes)
env -i /tmp/ftc | head -3
# TYP   VER   VERZEICHNIS
# ...
```

## One builder for everything

This **one** tcl-basekit builder covers all targets:

- **CLI apps** — `-kind cli` with a tcl basekit as `-basekit`.
- **GUI apps** — `-kind gui` with a *wish* basekit as `-basekit`; the builder
  takes the Tk standard library from that basekit.
- **Windows** — the Windows basekit as `-basekit`; the `.exe` is produced on
  Linux.

So you do **not** need a separate builder per target — only the right basekit
per target.

## Windows build host (optional)

To build on Windows, produce the builder once on the Windows tcl basekit:

```bash
./basekit-tcl ../build-app/build-app.tcl -kind cli -out build-app.exe \
    -basekit basekit-win-tcl.exe \
    -app ../build-app -main build-app.tcl \
    -tm ../../lib/tm
```

The same chain then runs there — with no installation at all.

## Next

With the finished builder, continue with the app examples:
`EXAMPLE-find-tclconfig.md` (CLI) and `EXAMPLE-notes-app.md` (GUI).
