# _template — starting point for a build-app-packageable app

Copy one of these skeletons to a new `apps/<name>/` directory and adapt it. Each
file's comments map to the numbered rules in
`docs/guide/build-app-app-conventions.md`, so you can follow the conventions
without re-reading the guide every time.

- `template-gui.tcl` — a minimal Tk GUI app: a `buildApp` entry proc, the
  `argv0` guard, module-path bootstrap, a `requireDeps` stub, a read-only-safe
  config path, and resource loading — the shape every GUI editor here uses.
- `template-cli.tcl` — a minimal console app that runs at source time and reads
  `$argv`; the shape of a dependency-free CLI tool.

Both build and run as-is (the GUI one needs only Tk).

## Try it

From `apps/bin/` with the builder and basekits in place:

```bash
# CLI
./build-app-zipkit-linux -kind cli -out template-cli -basekit basekit-tcl \
    -app ../_template -main template-cli.tcl
env -i ./template-cli alpha beta
# template-cli received 2 argument(s):
#   alpha
#   beta

# GUI (needs a display for the prober; headless via xvfb-run)
xvfb-run -a ./build-app-zipkit-linux -kind gui -out template-gui \
    -basekit "$(pwd)/basekit-tk" \
    -app ../_template -main template-gui.tcl -launch '::template::buildApp .'
SMOKE=1 xvfb-run -a ./template-gui
# SMOKE OK: children=1 title=Template App
```

## Adapting it

1. Copy the file into `apps/<yourname>/`, rename it, and rename the
   `::template` namespace and `buildApp`/`requireDeps` procs.
2. Add your dependencies with `package require` (rule 3); put hard external
   drivers in `requireDeps` (rule 5).
3. Build with the matching options — a GUI app needs
   `-launch '::yourname::buildApp .'` and `-tm <tree>` for its modules; an app
   with external packages needs `-extlib <root>`; shared code from a sibling
   directory needs `-include <dir>=<dest>`.

See `docs/guide/build-app-app-conventions.md` for the full rules and the
rule→option cheat sheet, and `apps/build-app/README.md` for the builder.
