# build-app (Apps zu eigenständigen Tcl-9-Programmen machen)

Macht aus einer App unter `tclutils/apps/` oder `tkutils/apps/` eine
**einzelne ausführbare Datei** — einen Tcl-9-*Zipkit*: ein statischer Tcl/Tk-9-
Interpreter mit einem angehängten ZIP, das App, Module und Standardbibliothek
enthält. Das Ergebnis läuft ohne installiertes Tcl, ohne tclutils, ohne
zusätzliche Dateien — Kopieren und Starten genügt.

Das Werkzeug ist selbst nur ein dünner Orchestrator; die eigentliche Arbeit
erledigen die Image-Primitive in `tclutils::tuzipfs` (`rcopy`, `copyStdlib`,
`mkimg`). Wie ein Zipkit im Detail funktioniert, steht in
`docs/guide/build-app.md`.

## Wozu

Endanwender sollen ein Programm bekommen, das sie doppelklicken — nicht eine
Tcl-Installation plus Modulpfade plus Startskript. Ein Zipkit packt alles in
eine Datei: kein Entpacken, kein Temp-Verzeichnis, keine Abhängigkeitsprobleme,
und der Anwender muss nicht wissen, dass das Programm in Tcl geschrieben ist.

## Zwei Wege

Es gibt das Werkzeug in zwei Formen, gleiche Optionen:

- **Gebündeltes Zipkit** `apps/bin/build-app-zipkit-linux` — trägt `tuzipfs`
  in sich. Braucht auf der Build-Maschine **nichts** außer sich selbst und den
  Basekits. Das ist der Normalfall.
- **Rohes Skript** `apps/build-app/build-app.tcl` — muss von einem Basekit
  ausgeführt werden und findet `tuzipfs` repo-relativ (oder per `-tm`).

## Voraussetzungen

Statische Tcl/Tk-9-**Basekits** (von BAWT oder magicsplat), je nach Ziel:

- ein `tclsh`-Basekit für CLI-Apps,
- ein `wish`-Basekit für GUI-Apps.

Auf der **Zielmaschine** wird nichts vorausgesetzt.

## Starten

```bash
# CLI-App (Tk-frei) auf das tcl-Basekit
./build-app-zipkit-linux -kind cli \
    -out find-tclconfig -basekit basekit-tcl \
    -app ../find-tclconfig -main find-tclconfig.tcl

# GUI-App auf das wish-Basekit
./build-app-zipkit-linux -kind gui \
    -out notes -basekit basekit-tk \
    -app ../../../tkutils/apps/notes-app -main notes_app.tcl \
    -launch '::notesapp::buildApp .' \
    -tm ../../lib/tm -tm ../../../tkutils/lib/tm \
    -extlib /opt/tcl9/lib
```

`-launch` unbedingt quoten — geschweifte Klammern quoten in der Shell nicht.

## Optionen

| Option | Bedeutung |
|---|---|
| `-out FILE` | Ausgabe-Executable (Pflicht) |
| `-basekit FILE` | statisches Tcl/Tk-9-Basekit als Vorlage (Pflicht) |
| `-kind cli\|gui` | Konsolen-App (tclsh) oder GUI-App (wish) (Pflicht) |
| `-app DIR` | Quellverzeichnis der App (Pflicht) |
| `-main FILE` | Einstiegsskript, relativ zu `-app` (Pflicht) |
| `-launch CODE` | Tcl zum Starten der App (z. B. `{::notesapp::buildApp .}`); leer lassen für Skripte, die beim `source` laufen (CLI) |
| `-tm DIR` | Modul-tm-Baum zum Einbündeln (wiederholbar) |
| `-extlib DIR` | Suchwurzel für externe pkgIndex-Pakete (für den Prober; wiederholbar) |
| `-probe 0\|1` | reale Abhängigkeits-Closure ermitteln (Default: 1 bei `gui`) |
| `-stdlibfrom basekit\|running\|DIR` | Quelle der Standardbibliothek (Default: aus dem Ziel-`-basekit`) |
| `-bootstrap none\|tkutils` | ob ein `_lib/paths.tcl`-Shim erzeugt wird |
| `-keep 0\|1` | temporären VFS-Baum zur Inspektion behalten |

## CLI vs GUI

Für **GUI**-Apps generiert `build-app` ein `main.tcl`, das `Tk` lädt, die App
baut (`-launch`) und den Event-Loop offenhält (`vwait forever` +
`WM_DELETE_WINDOW → exit`) — ein Zipkit bildet den impliziten Mainloop von
`wish` nicht selbst nach. Für **CLI**-Apps, die beim `source` durchlaufen, wird
das Einstiegsskript direkt zum `main.tcl`.

## Cross-Platform

Welche Plattform herauskommt, entscheidet allein das `-basekit`. Ein
Windows-`.exe` lässt sich unter Linux bauen: als `-basekit` das Win-Basekit
angeben. Die Standardbibliothek wird per Default aus genau diesem Basekit
gezogen (`-stdlibfrom basekit`), passt also immer zum Ziel — auch wenn der
Builder selbst auf einem anderen Basekit läuft.

## Der Prober

Statt Abhängigkeiten statisch aus `package require` zu raten (das überschätzt
massiv, weil viele Requires lazy sind), startet `build-app` die App einmal im
Ziel-Basekit und bündelt nur die **wirklich geladenen** externen Pakete. Für
Module aus tclutils/tkutils genügt `-tm`; externe pkgIndex-Pakete (sqlite3,
tdbc, tablelist …) sucht der Prober unter den `-extlib`-Wurzeln.
