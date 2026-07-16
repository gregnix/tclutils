# Schritt für Schritt: notes-app (GUI) als Programm

Dieses Beispiel baut die GUI-App `notes-app` aus dem tkutils-Repo zu einer
einzelnen ausführbaren Datei. Gegenüber dem CLI-Beispiel (`find-tclconfig`)
kommen drei Dinge dazu: ein **wish**-Basekit, das Bündeln der Modulbäume
(`-tm`) und ein Startbefehl (`-launch`). Wer das CLI-Beispiel noch nicht kennt,
sollte mit `BEISPIEL-find-tclconfig.md` anfangen.

## Voraussetzungen

Auf der Build-Maschine — sonst nichts, kein installiertes Tcl:

1. Ein **statisches wish-Basekit** (Tk enthalten), hier `basekit-tk`.
2. Der **Builder** `bin/build-app-zipkit-linux`.
3. Die Modulbäume, die die App braucht: `tclutils/lib/tm` und `tkutils/lib/tm`.

Für den **Prober** (siehe unten) braucht der Build-Host einen X-Display —
headless über `xvfb-run`. Auf der Zielmaschine wird nichts vorausgesetzt.

## Schritt 1 — Dateien bereitlegen

Wir gehen von der üblichen Nebeneinander-Struktur aus: `tclutils/` und
`tkutils/` als Geschwister-Verzeichnisse. Wir arbeiten in `tclutils/apps/bin/`
und legen das wish-Basekit daneben.

```bash
cd tclutils/apps/bin
cp /pfad/zum/basekit-tk .
ls
# basekit-tk  build-app-zipkit-linux
```

Die relativen Pfade von hier aus: die App liegt unter
`../../../tkutils/apps/notes-app`, die Modulbäume unter `../../lib/tm`
(tclutils) und `../../../tkutils/lib/tm`.

## Schritt 2 — Bauen

`xvfb-run -a` stellt dem Build einen virtuellen Display bereit (der Prober
startet die App kurz — dazu unten mehr). Die neuen Optionen gegenüber dem
CLI-Fall:

- `-kind gui` — GUI-App, also wish-Basekit und Event-Loop im `main.tcl`.
- `-launch '::notesapp::buildApp .'` — der Aufruf, der die Oberfläche baut.
  Nötig, weil die App beim `source` nur ihre Prozeduren definiert; ihr
  eingebauter „als Hauptskript?"-Test greift im Zipkit nicht.
- `-tm …` — die Modulbäume, aus denen `tkutils` und `tclutils::tunotes`
  gebündelt werden (zweimal, für beide Repos).
- `-extlib /opt/tcl9/lib` — Suchwurzel für externe pkgIndex-Pakete, falls der
  Prober welche findet (bei notes-app: keine).

```bash
xvfb-run -a ./build-app-zipkit-linux -kind gui -out notes-app \
    -basekit basekit-tk \
    -app ../../../tkutils/apps/notes-app -main notes_app.tcl \
    -launch '::notesapp::buildApp .' \
    -tm ../../lib/tm -tm ../../../tkutils/lib/tm \
    -extlib /opt/tcl9/lib
```

```
built: notes-app (5620756 bytes)
```

`-launch` unbedingt in Anführungszeichen — die geschweiften Klammern quoten in
der Shell nicht, das Leerzeichen würde den Wert sonst zerreißen.

## Schritt 3 — Prüfen, dass es selbstenthalten ist

```bash
ldd notes-app | grep -iE 'tcl|tk9' || echo "kein libtcl/libtk-Dep"
# kein libtcl/libtk-Dep
```

## Schritt 4 — Headless testen (Rauchtest)

Die App hat einen eingebauten SMOKE-Modus: mit gesetzter Variable `SMOKE` baut
sie die Oberfläche, meldet sie und beendet sich. Gut für CI ohne echten Bildschirm.

```bash
SMOKE=1 xvfb-run -a ./notes-app
# SMOKE OK: children=5 title=Notes - Untitled
```

## Schritt 5 — Ausführen

Auf einem Rechner mit Bildschirm einfach starten:

```bash
./notes-app
```

Das Fenster öffnet sich und bleibt offen (der generierte `main.tcl` hält den
Event-Loop mit `vwait forever`; Schließen des Fensters beendet das Programm).
Die Datei `notes-app` lässt sich einzeln weitergeben und läuft auf jedem
Linux-x64 ohne Installation.

## Warum xvfb-run?

Nicht das fertige Programm braucht den Display, sondern der **Prober** *während*
des Baus: er startet die App einmal im Ziel-Basekit, um die real geladenen
Abhängigkeiten zu ermitteln — und eine GUI-App braucht dafür Tk mit einem
Display. Auf einem Rechner mit Bildschirm entfällt `xvfb-run`. Wer die
Abhängigkeiten schon kennt (bei notes-app sind es nur die tm-Bäume), kann den
Prober mit `-probe 0` abschalten und ganz ohne Display bauen:

```bash
./build-app-zipkit-linux -kind gui -out notes-app -probe 0 \
    -basekit basekit-tk \
    -app ../../../tkutils/apps/notes-app -main notes_app.tcl \
    -launch '::notesapp::buildApp .' \
    -tm ../../lib/tm -tm ../../../tkutils/lib/tm
```

## Windows-.exe

Wie beim CLI-Beispiel: als `-basekit` das **Windows-wish-Basekit** angeben, `-out
notes-app.exe`. Die Tk-Standardbibliothek kommt per Default aus genau diesem
Basekit, passt also zum Windows-Ziel. Der Prober läuft dann allerdings auf dem
Windows-Basekit — plattformfremdes Probieren geht nicht, hier baut man mit
`-probe 0` (Abhängigkeiten aus dem Linux-Lauf bekannt).

## Was dabei passiert

`build-app` legt einen VFS-Baum an: die App unter `app/`, die Modulbäume unter
`lib/tm/`, die aus dem Basekit kopierten `tcl_library` und `tk_library`, einen
Bootstrap-Shim `_lib/paths.tcl` und ein generiertes `main.tcl`, das Tk lädt, die
App sourct, `-launch` ausführt und den Event-Loop offenhält. Dann hängt
`zipfs mkimg` diesen Baum an das Basekit. Details in `docs/guide/build-app.md`.
