# Schritt für Schritt: den Builder selbst bauen

Bevor man Apps verpackt, braucht man den Builder `build-app-zipkit-linux`. Er
liegt fertig im Repo (`apps/bin/`) — aber man kann ihn auch selbst erzeugen, und
das ist die **einzige** Stelle, an der `tclutils` überhaupt vorhanden sein muss.
Danach ist der Builder eine self-contained Einzeldatei: kein installiertes Tcl,
kein installiertes tclutils mehr nötig.

Der Builder baut sich dabei selbst — `build-app.tcl` verpackt `build-app.tcl`.

## Voraussetzungen

1. Ein **statisches tcl-Basekit**, hier `basekit-tcl`.
2. Der **tclutils-Baum** mit `apps/build-app/build-app.tcl` und dem Modul
   `tclutils::tuzipfs` (0.2+) unter `lib/tm/`.

## Schritt 1 — Ausgangslage

Wir arbeiten in `apps/bin/` und legen nur das Basekit hinein:

```bash
cd tclutils/apps/bin
cp /pfad/zum/basekit-tcl .
ls
# basekit-tcl
```

## Schritt 2 — Bootstrap

Das rohe Skript aus `../build-app/` wird vom Basekit ausgeführt und verpackt
sich selbst. `-tm ../../lib/tm` bündelt den tclutils-Modulbaum (mit `tuzipfs`)
ins Image — dadurch wird der Builder unabhängig vom Repo.

```bash
./basekit-tcl ../build-app/build-app.tcl -kind cli -out build-app-zipkit-linux \
    -basekit basekit-tcl \
    -app ../build-app -main build-app.tcl \
    -tm ../../lib/tm
```

```
built: build-app-zipkit-linux (3503653 bytes)
```

Warum so:

- `-kind cli` — der Builder ist ein Konsolenwerkzeug. Er läuft auf dem
  tcl-Basekit und kann trotzdem GUI- und Windows-Ziele bauen, weil er die
  Standardbibliothek immer aus dem jeweiligen Ziel-`-basekit` zieht.
- `-app ../build-app -main build-app.tcl` — die zu verpackende „App" ist
  `build-app.tcl` selbst; sie wird zum `main.tcl` des Images.
- `-tm ../../lib/tm` — bündelt `tuzipfs` (und den Rest von tclutils) mit hinein.

## Schritt 3 — Prüfen

`tuzipfs` liegt jetzt im Image, `main.tcl` ist der Builder:

```bash
./basekit-tcl <<'EOF'
zipfs mount [pwd]/build-app-zipkit-linux b
puts "tuzipfs: [file exists //zipfs:/b/lib/tm/tclutils/tuzipfs-0.2.tm]"
EOF
# tuzipfs: 1
```

## Schritt 4 — Selbsttest

Der frische Builder baut sofort eine App — hier in komplett leerer Umgebung
(`env -i`: kein `tclsh`, kein installiertes tclutils):

```bash
env -i ./build-app-zipkit-linux -kind cli -out /tmp/ftc \
    -basekit basekit-tcl -app ../find-tclconfig -main find-tclconfig.tcl
# built: /tmp/ftc (3178040 bytes)
env -i /tmp/ftc | head -3
# TYP   VER   VERZEICHNIS
# ...
```

## Ein Builder für alles

Dieser **eine** tcl-Basekit-Builder deckt alle Ziele ab:

- **CLI-Apps** — `-kind cli` mit einem tcl-Basekit als `-basekit`.
- **GUI-Apps** — `-kind gui` mit einem *wish*-Basekit als `-basekit`; die
  Tk-Standardbibliothek zieht der Builder aus diesem Basekit.
- **Windows** — als `-basekit` das Windows-Basekit; die `.exe` entsteht unter
  Linux.

Man braucht also **nicht** je Ziel einen eigenen Builder — nur je Ziel das
passende Basekit.

## Windows-Build-Host (optional)

Wer auf Windows baut, erzeugt den Builder einmal analog auf dem Windows-tcl-
Basekit:

```bash
./basekit-tcl ../build-app/build-app.tcl -kind cli -out build-app.exe \
    -basekit basekit-win-tcl.exe \
    -app ../build-app -main build-app.tcl \
    -tm ../../lib/tm
```

Danach läuft dieselbe Kette dort — ohne jede Installation.

## Weiter

Mit dem fertigen Builder geht es zu den App-Beispielen:
`BEISPIEL-find-tclconfig.md` (CLI) und `BEISPIEL-notes-app.md` (GUI).
