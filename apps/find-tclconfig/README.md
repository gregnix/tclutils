# find-tclconfig (Tcl/Tk-Konfiguration finden und paaren)

Findet alle `tclConfig.sh` / `tkConfig.sh` auf dem System, liest ihre Version und
gibt fertige `configure`-Zeilen aus — aber nur für Paare, die **wirklich
zusammengehören**. Ein reines Kommandozeilen-Werkzeug ohne Abhängigkeiten: Es
läuft überall, wo ein `tclsh` liegt (Linux, macOS, Windows), und braucht weder
tclutils noch Tk. Das ist Absicht — man benutzt es, *bevor* man baut, auf einem
System, auf dem sonst noch nichts eingerichtet ist.

## Wozu

Wer eine TEA-Erweiterung ohne `--with-tcl` / `--with-tk` konfiguriert, überlässt
die Wahl einer Suchheuristik. Auf einem System mit mehreren Installationen greift
die auch mal daneben: Tcl aus dem einen Baum, Tk aus einem anderen. Übersetzt
wird trotzdem — der Fehler fällt erst später um, an einer Stelle, die keinen Sinn
ergibt. Genau diese „Mischling"-Falle deckt das Werkzeug auf; es paart **nie**
über Installationsbäume hinweg.

## Starten

```bash
tclsh find-tclconfig.tcl [zusätzliche-suchpfade ...]
```

Ohne Argumente werden die üblichen Orte durchsucht (`/usr/lib`, `/usr/local`,
`/opt`, Homebrew/MacPorts/Framework unter macOS, Distributions- und BAWT-Bäume
unter Windows, `$HOME/lib`). Weitere Verzeichnisse lassen sich als Argumente
anhängen.

## Ausgabe lesen

```
TYP   VER   VERZEICHNIS
------------------------------------------------------------------
Tcl   ->    /usr/lib/tcl8.6
Tk    ->    /usr/lib/tk8.6
Tcl   8.6   /usr/lib/x86_64-linux-gnu/tcl8.6
Tk    8.6   /usr/lib/x86_64-linux-gnu/tk8.6
Tcl   9.0   /usr/lib/x86_64-linux-gnu/tcl9.0
Tk    9.0   /usr/lib/x86_64-linux-gnu/tk9.0

Brauchbare Paare (gleiche Version fuer Tcl und Tk):
------------------------------------------------------------------

  Tcl/Tk 9.0
    ./configure --with-tcl=/usr/lib/x86_64-linux-gnu/tcl9.0 \
                --with-tk=/usr/lib/x86_64-linux-gnu/tk9.0
```

Die Zeilen mit **`->`** in der Versionsspalte sind versionslose Weiterleitungen
(Debian legt neben `tcl8.6/tclConfig.sh` ein nacktes `/usr/lib/tclConfig.sh` an).
Welche Generation dahintersteckt, sieht man ihnen nicht an — und die für Tcl und
die für Tk müssen nicht dieselbe sein. **Die nimmt man nicht.** Genau sie sind
die Ursache der meisten Fehlgriffe.

## Was das Werkzeug garantiert

- **Gleiche Version.** Ein Paar entsteht nur, wenn Tcl und Tk dieselbe Version
  melden.
- **Same-Dir.** Tcl und Tk im selben Verzeichnis (so legt es Windows / BAWT ab)
  werden gepaart.
- **Geschwister.** `.../tcl8.6/` und `.../tk8.6/` nebeneinander (so legt es Debian
  ab) werden gepaart.
- **Nie quer über Bäume.** Zwei getrennte Installationsbäume, die beide „8.6"
  sagen, werden **nicht** gemischt — auch wenn dort ein passendes Tk läge. Dann
  meldet das Werkzeug ehrlich „kein Tk daneben" statt zu raten.

## Windows

Derselbe `tclsh`-Aufruf liefert dasselbe Ergebnis. Zu beachten: Ein Build **mit
Visual Studio** benutzt gar kein `configure`, sondern `win\makefile.vc` und
`nmake` — dort spielt `tclConfig.sh` keine Rolle. Erst der MinGW-/MSYS2-Weg führt
wieder über `configure`.

## Bezug zum Handbuch

Das Handbuch *Tcl/Tk aus dem Quellcode bauen* (Kapitel „TEA") verweist auf dieses
Werkzeug. Es ist bewusst eigenständig gehalten, damit es ohne weitere Einrichtung
läuft — nur `tclsh`, sonst nichts.

## Tests

```bash
tclsh tests/find-tclconfig.test
```

Die Suite legt eine synthetische Fixture aus `tclConfig.sh` / `tkConfig.sh` an
und prüft die vier Fälle (Same-Dir, Geschwister, versionslose Weiterleitung,
Quer-über-Bäume). Rein Tcl, läuft unverändert auf 8.6 und 9.0. Verifiziert auf
Tcl 8.6.14 und 9.0.4: 5/5.

## Lizenz

MIT — siehe [LICENSE](LICENSE).
