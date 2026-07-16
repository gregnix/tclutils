# Writing an app so build-app can package it

`build-app` packages an app directory into a zipkit. That works cleanly only if
the app follows a few conventions in how it starts, finds its files, and loads
its dependencies. None of these are exotic — they are just the discipline that
lets the same code run from a source checkout *and* from inside a read-only
`//zipfs:/app` mount. This page lists the rules, why each exists, and which
`build-app` option it maps to.

## 1. One entry script, two shapes

The app has a single entry script named with `-main`. There are two shapes:

**CLI — runs at source time.** The script does its work at the top level and
reads `$argv`. `build-app` copies it in as `main.tcl` and it just runs. Nothing
else is needed. (Example: `find-tclconfig`.)

**GUI — defines an entry procedure.** The script defines the app's procedures and
guards its top-level launch so that *sourcing* it does not build the UI:

```tcl
proc ::myapp::buildApp {parent} { ... build widgets ... }

if {[info exists argv0] && [file normalize $argv0] eq [file normalize [info script]]} {
    ::myapp::buildApp .
}
```

Inside a zipkit the generated `main.tcl` **sources** the entry script, so
`[info script]` ≠ `$argv0` and the guard does **not** fire. Therefore the app
must expose a single proc that builds/starts it, and you name it with `-launch`:

```
-launch '::myapp::buildApp .'
```

Rule: **expose one entry proc; do not rely only on the argv0 guard.**

## 2. Locate your own files via `[info script]`

In a zipkit the app lives at `//zipfs:/app/app/…` and the working directory is
unrelated. Find sub-scripts and resources relative to the script, never via the
current directory or an absolute path:

```tcl
set dir [file dirname [file normalize [info script]]]
source [file join $dir mymodule.tcl]
image create photo logo -file [file join $dir res logo.png]
```

Rule: **every self-reference goes through `[file dirname [info script]]`.** Keep
all of the app's own files (sub-scripts, `res/…`) inside the app directory;
`build-app` copies the whole directory.

## 3. Load dependencies with `package require`

Declare every dependency — tclutils/tkutils modules and external packages alike —
with `package require`. Do **not** `load` a shared library by hand-written path,
and do not `source` a package's files directly. Two reasons: the prober discovers
the real dependency set by *running* the app and recording what `package require`
loaded, and the zipkit resolves packages through the module/auto path.

- tclutils/tkutils modules → bundled from the trees you pass with `-tm`.
- External pkgIndex packages (sqlite3, tdbc, tablelist …) → found by the prober
  under the roots you pass with `-extlib`.

Rule: **all dependencies via `package require`.**

## 4. Use the `_lib/paths.tcl` bootstrap

Apps in this repo find tclutils/tkutils at development time by sourcing a shared
bootstrap, relative to the script:

```tcl
source [file join [file dirname [file normalize [info script]]] .. _lib paths.tcl]
```

`build-app` writes a small zipkit-aware shim in its place (it just adds
`//zipfs:/app/lib/tm` to the module path), so the same line works in the image.

Rule: **bootstrap the module path through `_lib/paths.tcl`, not with hard-coded
paths.**

## 5. Gather hard external requires in one proc

For apps that need a native driver, put the `package require` of that driver in a
single proc with a clear error, and call it from `-launch`:

```tcl
proc ::myapp::requireDeps {} {
    if {[catch {package require tdbc::postgres} err]} {
        error "This editor needs the tdbc::postgres package.\n$err"
    }
}
```

```
-launch '::myapp::requireDeps; ::myapp::buildApp .'
```

Rule: **one `requireDeps` proc for hard external drivers**, so failures are
reported clearly and the prober sees the load.

## 6. Treat the app's own location as read-only

The zipkit VFS is read-only. Never write config, logs, or data into the app's own
directory. Use a writable location:

```tcl
set home [file normalize ~]                    ;# portable on 8.6 and 9.0
set confdir [file join $home .config myapp]     ;# ([file home] on Tcl 9 only)
```

Rule: **write only to a user/home directory, never next to the executable.**

## 7. GUI: build the UI and return — don't run the loop yourself

`buildApp` should create the widgets and return. Do **not** call `vwait`,
`tkwait`, or a mainloop inside it — the generated `main.tcl` runs the event loop
(`vwait forever` + `WM_DELETE_WINDOW → exit`) and also adds a `SMOKE` branch for
headless testing. And `buildApp` should build the UI **without** needing a live
external resource (a DB connection, a network service); defer connecting until
the user asks. That keeps startup and the smoke test working.

Rule: **`buildApp` builds widgets and returns; no blocking, no mandatory
connection at build time.**

## 8. Prefer modules over sharing a sibling app directory

If several apps share code, put the shared code in a **module** (a `.tm` in the
tm tree) and `package require` it — then it is bundled via `-tm` like any other
module. Sourcing files from a sibling *app* directory (as the PostgreSQL editor
does with `../sqlite-editor/`) works, but it forces the person building to add
`-include …/sibling=sibling` and to know the layout.

Rule: **shared code belongs in a module; a shared sibling directory needs
`-include` and should be documented.**

## 9. General Tcl 9 hygiene

- `package require Tcl 8.6-` (the dash form, so it also satisfies 9.x).
- Build paths with `[file join …]`; do not hand-assemble with `/` or `\`.
- Anything platform-specific (a C-extension, a native driver) is bundled per
  platform and, for a native client library, must be present on the target —
  see the sqlite-editor and postgresql-editor examples.

## Rule → option cheat sheet

| The app… | build it with |
|---|---|
| defines a `buildApp`/entry proc (GUI) | `-launch '::app::buildApp .'` |
| runs at source time (CLI) | no `-launch` |
| needs tclutils/tkutils modules | `-tm <tree>` (repeatable) |
| needs external pkgIndex packages | `-extlib <root>` (repeatable) |
| sources code from a sibling directory | `-include <dir>=<dest>` |
| is a GUI app | `-kind gui` (wish basekit) |
| is a console app | `-kind cli` (tcl basekit) |

An app that follows §1–§9 typically packages with just `-kind`, `-app`, `-main`,
`-launch`, and its `-tm` trees.
