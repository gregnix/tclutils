# Auf Windows bauen (ohne Linux)

Die ganze Werkzeugkette läuft genauso unter Windows — für alle, die kein Linux
haben oder Windows als Hauptsystem nutzen. Es ändern sich nur die Basekits
(`.exe`-Dateien) und die Pfad-/Quoting-Schreibweise. Kein installiertes Tcl, kein
installiertes tclutils auf dem Zielrechner.

Alle Aufrufe funktionieren in `cmd.exe` und in PowerShell. Tcl akzeptiert auch
unter Windows **Vorwärts-Schrägstriche** in Pfaden — das ist am unkompliziertesten;
Backslashes gehen ebenso.

## Voraussetzungen

Statische Windows-Basekits (von BAWT oder magicsplat):

- `zipkit-9_0_4-win64-intel-tcl.exe` — Konsolen-Interpreter, für **CLI**-Apps.
- `zipkit-9_0_4-win64-intel-tk.exe` — GUI-Interpreter **ohne** Konsolenfenster,
  für **GUI**-Apps.

Für den Weg „Builder selbst bootstrappen" zusätzlich den `tclutils`-Baum.

## Der einfachste Weg: fertige build-app.exe

Liegt eine fertige `build-app.exe` vor (mitgeliefert oder einmal gebootstrappt,
siehe unten), braucht man auf dem Build-Rechner **nur** diese Datei und die
Basekits.

CLI-App zu einer Exe (Konsolen-Basekit):

```bat
build-app.exe -kind cli -out find-tclconfig.exe ^
    -basekit zipkit-9_0_4-win64-intel-tcl.exe ^
    -app find-tclconfig -main find-tclconfig.tcl
```
```
built: find-tclconfig.exe (3873710 bytes)
```

GUI-App zu einer Exe (GUI-Basekit, `-launch`, Modulbäume). In `cmd`/PowerShell
werden **doppelte** Anführungszeichen verwendet:

```bat
build-app.exe -kind gui -out notes-app.exe ^
    -basekit zipkit-9_0_4-win64-intel-tk.exe ^
    -app ../tkutils/apps/notes-app -main notes_app.tcl ^
    -launch "::notesapp::buildApp ." ^
    -tm lib/tm -tm ../tkutils/lib/tm ^
    -extlib C:/Tcl/lib
```
```
built: notes-app.exe (7299242 bytes)
```

Das `^` am Zeilenende ist die Zeilenfortsetzung in `cmd.exe` (in PowerShell:
Backtick `` ` ``; alles in eine Zeile geht immer). Starten dann per Doppelklick
oder aus dem Terminal: `find-tclconfig.exe`, `notes-app.exe`.

## build-app.exe selbst bootstrappen (einmalig)

Nur nötig, wenn keine fertige `build-app.exe` vorliegt oder `tuzipfs`
aktualisiert wurde. Der Konsolen-Basekit führt das rohe Skript aus, das sich
selbst verpackt:

```bat
zipkit-9_0_4-win64-intel-tcl.exe apps/build-app/build-app.tcl ^
    -kind cli -out build-app.exe ^
    -basekit zipkit-9_0_4-win64-intel-tcl.exe ^
    -app apps/build-app -main build-app.tcl ^
    -tm lib/tm
```
```
built: build-app.exe (4199323 bytes)
```

Danach ist `build-app.exe` self-contained (kein tclutils mehr nötig).

## Windows-Besonderheiten

- **Kein Xvfb.** Der Prober startet die App beim Bauen einer GUI-Exe kurz — unter
  Windows steht dafür der normale Desktop bereit, es ist nichts weiter zu tun.
  Nur auf einem **headless** Windows-Server (ohne Desktop) baut man GUI-Apps mit
  `-probe 0` und gibt die Modulbäume über `-tm` selbst vor.
- **Konsole vs GUI.** Der `...-tcl.exe`-Basekit öffnet ein Konsolenfenster (gut
  für CLI-Werkzeuge); der `...-tk.exe`-Basekit hat keins (so erscheint bei
  GUI-Apps kein störendes schwarzes Fenster).
- **Anführungszeichen.** Werte mit Leerzeichen wie `-launch "::notesapp::buildApp ."`
  in doppelte Anführungszeichen setzen (cmd und PowerShell).
- **Ausführen.** Doppelklick oder aus `cmd`/PowerShell. Weitergeben = die eine
  Datei kopieren; sie läuft auf jedem Windows-x64 ohne Installation.

## Umgekehrt: Linux-Binaries von Windows aus

Der Windows-Host kann genauso **Linux**-Binaries bauen — als `-basekit` ein
Linux-Basekit angeben. Weil das plattformfremde Probieren nicht geht, dann mit
`-probe 0` bauen (die Abhängigkeiten kennt man aus einem Lauf auf der Zielplattform):

```bat
build-app.exe -kind gui -out notes-app -probe 0 ^
    -basekit zipkit-9_0.4-Linux64-intel-tk ^
    -app ../tkutils/apps/notes-app -main notes_app.tcl ^
    -launch "::notesapp::buildApp ." ^
    -tm lib/tm -tm ../tkutils/lib/tm
```

## Hinweis zur Verifikation

Die in diesem Text gezeigten Windows-Binaries (`build-app.exe`,
`find-tclconfig.exe`, `notes-app.exe`) wurden cross unter Linux erzeugt und als
gültige Windows-Zipkits geprüft (PE-Header `MZ`, angehängtes ZIP mit
`main.tcl`/Stdlib/Modulen); die Größen im Text sind die tatsächlichen. Die
`built: …`-Meldungen sind die plattformunabhängige Ausgabe des Werkzeugs — auf
Windows erscheinen sie identisch.
