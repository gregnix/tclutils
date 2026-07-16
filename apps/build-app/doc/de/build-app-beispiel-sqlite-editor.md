# Schritt für Schritt: sqlite-editor (mit C-Extension)

Dieses Beispiel baut den `sqlite-editor` — eine GUI-App, die **echte externe
Pakete** braucht: die C-Extension `sqlite3` und den `tablelist`-Widgetsatz.
Gegenüber `notes-app` kommt damit die Rolle des **Probers** und der `-extlib`-
Option ins Spiel, und man sieht, wie eine C-Extension zur Laufzeit aus dem
Zipkit geladen wird. Wer die einfacheren Beispiele noch nicht kennt, sollte mit
`BEISPIEL-find-tclconfig.md` und `BEISPIEL-notes-app.md` anfangen.

## Voraussetzungen

1. Ein **statisches wish-Basekit**, hier `basekit-tk`.
2. Der **Builder** `bin/build-app-zipkit-linux`.
3. Die Modulbäume `tclutils/lib/tm` und `tkutils/lib/tm`.
4. Die **externen Pakete** in einem Verzeichnis, das der Prober durchsucht — die
   `sqlite3`- und `tablelist`-Installation, z. B. die `lib/` deiner Tcl-9-
   Installation oder die BAWT-Paketsammlung. Im Beispiel: `/opt/tcl9/lib`.

Für den Prober braucht der Build-Host einen Display — headless über `xvfb-run`.

## Schritt 1 — Dateien bereitlegen

Wie beim GUI-Beispiel arbeiten wir in `tclutils/apps/bin/` mit `tclutils/` und
`tkutils/` als Geschwister:

```bash
cd tclutils/apps/bin
cp /pfad/zum/basekit-tk .
```

Die App hat mehrere Dateien (`sqledit-core.tcl`, `be-sqlite.tcl`,
`sqledit-form.tcl`, `sqledit-sheet.tcl` …) — `build-app` kopiert den ganzen
App-Ordner mit, darum ist nur der Ordner und das Einstiegsskript anzugeben.

## Schritt 2 — Bauen

Neu gegenüber `notes-app`: `-extlib` zeigt auf die externe Paketinstallation.
`-launch` ruft zusätzlich `::sqledit::requireDeps` auf — das lädt `sqlite3`.

```bash
xvfb-run -a ./build-app-zipkit-linux -kind gui -out sqlite-editor \
    -basekit "$(pwd)/basekit-tk" \
    -app ../../../tkutils/apps/sqlite-editor -main sqlite-editor.tcl \
    -launch '::sqledit::requireDeps; ::sqledit::buildApp .' \
    -tm ../../lib/tm -tm ../../../tkutils/lib/tm \
    -extlib /opt/tcl9/lib
```

Der Prober startet die App einmal und meldet die real geladenen externen Pakete:

```
  probe: external package Tablelist_tile 7.11 -- no own path (covered by another bundle)
  probe: external package file::home 1 -- no own path (covered by another bundle)
  probe: external package mwutil 2.25  <- /opt/tcl9/lib/tablelist7.11
  probe: external package sqlite3 3.53.0  <- /opt/tcl9/lib/sqlite3.53.0
built: sqlite-editor (8279547 bytes)
```

Er hat `sqlite3` und `tablelist7.11` als Paket-Roots erkannt und bündelt genau
diese. (`Tablelist_tile`/`file::home` sind Alias-Pakete ohne eigenen Pfad — sie
stecken schon im `tablelist7.11`-Bundle.)

`-basekit "$(pwd)/basekit-tk"` bewusst als **absoluter** Pfad: der Prober startet
das Basekit per `exec`, und `exec` sucht nicht im aktuellen Verzeichnis.

## Schritt 3 — Was wurde gebündelt?

Der Prober hat es in Schritt 2 schon gemeldet; nachsehen lässt es sich im Image
so (headless über `xvfb-run`, mit `exit`, weil das wish-Basekit sonst in den
Event-Loop geht):

```bash
xvfb-run -a ./basekit-tk <<'EOF'
zipfs mount [pwd]/sqlite-editor s
puts [glob -tails -directory //zipfs:/s/lib/pkgs *]
exit 0
EOF
# tablelist7.11 sqlite3.53.0
```

## Schritt 4 — Selbstenthalten und Rauchtest

Kein Bezug auf `libtcl`, `libtk` oder `libsqlite` — auch die C-Extension steckt
im Image:

```bash
ldd sqlite-editor | grep -iE 'tcl|tk9|sqlite' || echo "kein libtcl/libtk/libsqlite-Dep"
# kein libtcl/libtk/libsqlite-Dep

SMOKE=1 xvfb-run -a ./sqlite-editor
# SMOKE OK: children=6 title=SQLite Editor - (not connected)
```

Dass der Rauchtest durchläuft, ist zugleich der Beweis, dass `requireDeps` die
C-Extension `sqlite3` **aus dem Zipkit** geladen hat.

## Schritt 5 — Ausführen

```bash
./sqlite-editor            # leeres Fenster
./sqlite-editor meine.db   # oder direkt eine Datenbank oeffnen
```

## Wie die C-Extension aus dem Zipkit lädt

Das Betriebssystem kann keine Shared Library direkt aus einem `zipfs` laden.
Tcls `load`-Befehl fängt das ab: er kopiert die `.so` beim ersten Zugriff in ein
temporäres Verzeichnis und lädt sie von dort. Für die App ist das transparent —
`package require sqlite3` funktioniert im Zipkit genau wie sonst.

## Wichtig: C-Extensions sind plattformgebunden

Die gebündelte `libtcl9sqlite3.53.0.so` ist ein **Linux**-Binary. Ein
Windows-Build braucht die **Windows**-Variante (`.dll`) desselben Pakets. Beim
Cross-Bauen heißt das:

- Das `-basekit` bestimmt die Plattform des Interpreters (wie gehabt).
- `-extlib` muss auf die Pakete **der Zielplattform** zeigen — also die
  Windows-`sqlite3`/`tablelist`-Installation, nicht die Linux-Version.
- Plattformfremdes Probieren geht nicht, daher mit `-probe 0` bauen und die
  externen Pakete über `-extlib` (Zielplattform) selbst vorgeben.

Reine Tcl/Tk-Apps (wie `notes-app`) haben dieses Problem nicht — nur Apps mit
C-Extensions. Für `find-tclconfig` und `notes-app` genügt weiterhin ein
Basekit-Wechsel für den Cross-Build.

## Was dabei passiert

`build-app` legt den VFS-Baum an (App-Ordner, Modulbäume, aus dem Basekit
kopierte `tcl_library`/`tk_library`, die per Prober gefundenen externen Pakete
unter `lib/pkgs/`, Bootstrap-Shim, generiertes `main.tcl`) und ruft
`zipfs mkimg`. Details in `docs/guide/build-app.md`.
