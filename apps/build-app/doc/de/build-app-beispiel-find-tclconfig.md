# Schritt für Schritt: find-tclconfig als Programm

Dieses Beispiel baut die dep-freie CLI-App `find-tclconfig` zu einer einzelnen
ausführbaren Datei — einem Tcl-9-Zipkit. Weil `find-tclconfig` keine tclutils-
Module braucht, ist es der einfachste Fall; GUI-Apps und externe Pakete kommen
in der `README.md` und in `docs/guide/build-app.md`.

## Voraussetzungen

Zwei Dinge auf der Build-Maschine — sonst nichts, kein installiertes Tcl:

1. Ein **statisches tcl-Basekit** (von BAWT oder magicsplat), hier `basekit-tcl`.
2. Der **Builder** `bin/build-app-zipkit-linux` (liegt im Repo).

Auf der Zielmaschine wird nichts vorausgesetzt.

## Schritt 1 — Dateien bereitlegen

Wir arbeiten im Ordner `apps/bin/`, wo der Builder schon liegt, und legen das
Basekit daneben. Die App-Quelle liegt eine Ebene höher unter `../find-tclconfig`.

```bash
cd apps/bin
cp /pfad/zum/basekit-tcl .        # das statische tcl-Basekit
ls
# basekit-tcl  build-app-zipkit-linux
```

## Schritt 2 — Bauen

Ein Aufruf. `-kind cli`, weil es eine Konsolen-App ohne Tk ist; `-out` ist der
Name der fertigen Exe, `-basekit` die Vorlage, `-app`/`-main` zeigen auf das
Einstiegsskript.

```bash
./build-app-zipkit-linux -kind cli -out find-tclconfig \
    -basekit basekit-tcl \
    -app ../find-tclconfig -main find-tclconfig.tcl
```

```
built: find-tclconfig (3178040 bytes)
```

## Schritt 3 — Prüfen, dass es selbstenthalten ist

Kein `libtcl`-Bezug — Tcl steckt statisch im Basekit:

```bash
ldd find-tclconfig | grep -i tcl || echo "kein libtcl-Dep"
# kein libtcl-Dep
```

## Schritt 4 — Ausführen

Mit `env -i` (komplett leere Umgebung — kein `PATH`, kein installiertes Tcl)
zeigt sich, dass die Exe wirklich alles mitbringt:

```bash
env -i ./find-tclconfig
```

```
TYP   VER   VERZEICHNIS
------------------------------------------------------------------
Tcl   9.0   /usr/lib/x86_64-linux-gnu/tcl9.0
Tk    9.0   /usr/lib/x86_64-linux-gnu/tk9.0

Brauchbare Paare (gleiche Version fuer Tcl und Tk):
------------------------------------------------------------------

  Tcl/Tk 9.0
    ./configure --with-tcl=/usr/lib/x86_64-linux-gnu/tcl9.0 \
                --with-tk=/usr/lib/x86_64-linux-gnu/tk9.0
```

Fertig. Die Datei `find-tclconfig` lässt sich jetzt einzeln weitergeben und läuft
auf jedem Linux-x64 ohne Installation.

## Variante — ohne den gebündelten Builder

Wer lieber das rohe Skript nimmt, führt es von einem Basekit aus. Es findet
`tuzipfs` repo-relativ, das Ergebnis ist identisch:

```bash
./basekit-tcl ../build-app/build-app.tcl -kind cli -out find-tclconfig \
    -basekit basekit-tcl -app ../find-tclconfig -main find-tclconfig.tcl
# built: find-tclconfig (3178040 bytes)
```

Läuft das Skript aus einem *anderen* Verzeichnis (nicht `apps/build-app/`), gibt
man den Modulpfad explizit mit: `-tm ../../lib/tm`.

## Optional — eine Windows-.exe unter Linux bauen

Nur das Basekit wechseln: als `-basekit` das Windows-Basekit angeben. Die
Standardbibliothek zieht der Builder per Default aus genau diesem Basekit, also
passt sie zum Windows-Ziel.

```bash
cp /pfad/zum/basekit-win-tcl.exe .
./build-app-zipkit-linux -kind cli -out find-tclconfig.exe \
    -basekit basekit-win-tcl.exe \
    -app ../find-tclconfig -main find-tclconfig.tcl
# built: find-tclconfig.exe (3873710 bytes)

file find-tclconfig.exe
# find-tclconfig.exe: Zip archive, with extra data prepended  (gueltiges PE + angehaengtes ZIP)
```

Ausführen lässt sich die `.exe` nur unter Windows; gebaut wird sie ohne Windows.

## Was dabei passiert

`build-app` legt einen VFS-Baum an (die App als `main.tcl`, plus die aus dem
Basekit kopierte `tcl_library`) und ruft `zipfs mkimg`, das die Basekit-Bytes
voranstellt und den Baum als ZIP anhängt. Beim Start mountet Tcl 9 dieses
Archiv unter `//zipfs:/app` und führt `main.tcl` aus. Die Details stehen in
`docs/guide/build-app.md`.
