# tclutils::tudeploy — Spec (0.1)

Generisches Laufzeit-Auffinden und -Laden von Tcl-Modul-Paketen aus
app-relativen „Deployment-Wurzeln" (`vendor/`, `libs/`, …) plus das Auffinden
gebündelter Ressourcen-Verzeichnisse (für externe Binaries/Decoder).

**Status:** **UMGESETZT** — `lib/tm/tclutils/tudeploy-0.1.tm` liegt im Repo.
Dieses Dokument ist die Referenz zur ausgelieferten 0.1, kein offener Entwurf
mehr. (Bis 2026-07-13 stand hier „Noch kein Code" — wer das las, hielt ein
fertiges Modul fuer eine offene Aufgabe.)

Sprache: Doku/Chat Deutsch, API + Fehler + Beispiele Englisch,
**library-neutral** (keine App-Namen).

---

## 1. Motivation

Drei Stellen in pdf2img machen dasselbe Muster und werden je App neu erfunden:

- `bootstrapTkutils` / `bootstrapQpdf` — Basisverzeichnisse bestimmen
  (Skript-Dir + Exe-Dir), Kandidatenwurzeln `vendor/`, `libs/common/`, `libs/`,
  `lib/tm/` (+ Parent) bilden, existierende auf `tcl::tm::path`, dann
  `package require`.
- `ivWebpDirs` — dieselbe Basis, aber Kandidaten-**Verzeichnisse** für ein
  gebündeltes Binary (Decoder), die dann an `tuexe::find -dirs` gehen.

`tudeploy` zieht genau dieses Muster heraus — wie damals `gsExe` → `tuexe`.
Gewinn: App-Code *und* Build werden schlanker und über alle Apps konsistent.

---

## 2. Öffentliche API (Ensemble `tclutils::tudeploy`)

```
tudeploy baseDirs
        -> list of app base dirs: dir of [info script] + dir of the executable
           (normalised, de-duplicated, existing only)

tudeploy platformTag
        -> "<os><bits>", e.g. "linux64" / "windows64"
           (os from tcl_platform(platform); bits from pointerSize)

tudeploy roots ?options?
        -> ordered list of EXISTING module roots, relative to each base dir
           and (optionally) its parent, following a configurable convention.

tudeploy addModulePaths ?options?
        -> add the roots from `roots` to tcl::tm::path; returns the added list.

tudeploy require {pkg ...} ?options?
        -> addModulePaths, then `package require` each pkg.
           returns 1 if ALL succeed, 0 otherwise (or throws with -fail 1).

tudeploy resourceDirs name ?options?
        -> ordered list of EXISTING candidate dirs for a bundled resource
           <name> (e.g. a decoder), to feed to `tuexe::find -dirs`.
```

### Optionen

| Option | gilt für | Default | Wirkung |
|---|---|---|---|
| `-base {dir ...}` | alle | `[baseDirs]` | Basisverzeichnisse überschreiben |
| `-env {VAR ...}` | roots, resourceDirs | `{}` | Werte (Verzeichnisse) dieser Env-Vars werden **vorangestellt** |
| `-roots {rel ...}` | roots, require, addModulePaths | s. u. | Konvention der relativen Wurzeln überschreiben |
| `-parents 0\|1` | roots, resourceDirs | `1` | Parent-Varianten der Basisdirs einbeziehen |
| `-tag <str>` | resourceDirs | `[platformTag]` | Plattform-Tag überschreiben |
| `-tmadd 0\|1` | require | `1` | vor dem Require Wurzeln auf tm-path legen |
| `-fail 0\|1` | require | `0` | bei fehlendem Paket werfen statt 0 zurückgeben |

### Default-Konventionen

**Modul-Wurzeln** (`roots`), je Basisdir `$b` (und mit `-parents 1` auch
`[file dirname $b]`):

```
$b/vendor
$b/libs/common
$b/libs
$b/lib/tm
```

**Ressourcen-Verzeichnisse** (`resourceDirs <name>`), je Basisdir `$b`
(+ Parent), `$tag` = `[platformTag]`:

```
$b/vendor/<name>/<tag>
$b/vendor/<name>
$b/vendor/<tag>
$b/vendor
$b/bin
$b
```

In beiden Fällen: Reihenfolge bleibt erhalten, nur **existierende** Verzeichnisse
werden zurückgegeben, Duplikate entfernt; `-env`-Werte stehen vorn.

---

## 3. Henne-Ei-Problem (bewusst, dokumentiert)

`tudeploy` liegt selbst in tclutils — die App muss tclutils also erst finden,
bevor sie `package require tclutils::tudeploy` aufrufen kann. Es bleibt daher
ein **minimaler Inline-Stub** in der App (einmalig, ~6 Zeilen), der nur die
Wurzeln auf den tm-path legt; alles Weitere macht das Modul:

```tcl
# minimal inline bootstrap: make tclutils loadable, then delegate
apply {{} {
    set bases [list [file dirname [file normalize [info script]]]]
    catch { lappend bases [file dirname [file normalize [info nameofexecutable]]] }
    foreach b $bases {
        foreach rel {vendor {libs common} libs {lib tm}
                     {.. vendor} {.. libs common} {.. libs}} {
            set d [file join $b {*}$rel]
            if {[file isdirectory $d]} { catch {tcl::tm::path add $d} }
        }
    }
}}
package require tclutils::tudeploy
```

Der Stub ist absichtlich „dumm" (nur tclutils finden). Die kanonische Konvention
lebt in `tudeploy`; der Stub und das Modul müssen sich nur darauf einigen, dass
tclutils unter einer dieser Wurzeln liegt. Die wiederholten **Such-Schleifen pro
Paket** entfallen damit — der Stub bleibt, aber er ist fix und winzig.

---

## 4. Vorher / Nachher in einer App (illustrativ, neutral)

Vorher (pro Paketgruppe eine eigene Bootstrap-Proc mit Suchschleife). Nachher:

```tcl
# GUI-Module laden (1 Aufruf statt zweier Bootstrap-Procs)
if {![tudeploy require {
        tkutils::tkutoolbar tkutils::tkuballoon tkutils::tkumarquee
        tkutils::tkufiletree tkutils::tkuimage
        tclutils::tupagespec tclutils::tuexe}]} {
    error "required GUI modules not found"
}

# gebündelten Decoder finden (resourceDirs + tuexe statt ivWebpDirs)
set dirs [tudeploy resourceDirs webp -env MYAPP_WEBP]
set exe  [tclutils::tuexe::find dwebp -dirs $dirs]
```

(In der konkreten App stehen statt `MYAPP_WEBP` die echten Namen — die bleiben
**in der App**, nicht im Modul.)

---

## 5. Fehler

Einheitlich `{TCLUTILS TUDEPLOY <REASON>}`:

- `OPTION` — unbekannte Option / fehlender Optionswert
- `USAGE`  — fehlendes Pflichtargument (z. B. `resourceDirs` ohne `name`)
- `REQUIRE` — nur mit `-fail 1`, wenn ein Paket nicht ladbar ist
  (Message nennt das/die fehlende(n) Paket(e))

---

## 6. Tests (tcltest, `tudeploy.test`)

Headless, ohne Tk. Über temporäre Verzeichnisbäume:

1. `baseDirs` enthält das Skriptverzeichnis; nur existierende, dedupliziert.
2. `platformTag` == os+bits passend zu `tcl_platform`.
3. `roots`: Baum mit `vendor/`, `libs/common/`, `libs/` anlegen → korrekte
   Reihenfolge, nur existierende; `-env` voran; `-parents 0` ohne Parent.
4. `require`: Dummy-Modul `foo/bar-1.0.tm` (`package provide foo::bar 1.0`) in
   einer Wurzel → `require {foo::bar}` == 1; fehlendes Paket → 0; `-fail 1` wirft
   `{TCLUTILS TUDEPLOY REQUIRE}`.
5. `resourceDirs`: Basis mit `vendor/webp` und `vendor/webp/<tag>` → Liste in
   erwarteter Reihenfolge, `-env` voran, `-tag` überschreibbar.
6. Optionsfehler → `{TCLUTILS TUDEPLOY OPTION}`.

Ziel: alle grün auf 8.6 **und** 9.0.

---

## 7. Doku / Demo / Umbrella

- `docs/tudeploy.md` (single-source), Man-Page via `tools/md2man.tcl`.
- `demo-tudeploy.tcl` — neutrales Mini-Beispiel (Dummy-Pakete im temp-Baum),
  zeigt `roots`, `require`, `resourceDirs`.
- Umbrella-Registrierung in `tclutils-<ver>.tm`, Kategorie-Vorschlag
  **„Deployment / packaging"** (neue Kategorie) oder bestehend
  **„Stream / filesystem"**.
- CHANGELOG-Eintrag; Umbrella-Versionsbump optional (analog tuexe-Aufnahme).

---

## 8. Abgrenzung — was NICHT hineinkommt

- Build-Orchestrierung (Combo-Wahl, sdx-Wrap, VFS-Assembly, zipfs mkimg) bleibt
  im Build-Repo. `tudeploy` ist **Laufzeit**-Discovery, keine Build-Engine.
- Datei-Kopieren / String-Map-Patchen (`copyDir`, `patchFiles`, `resolveDir`)
  bleibt im Build-Skript (trivial, kein passendes Bestandsmodul; `tupatch` macht
  *unified diffs*, nicht String-Maps).
- Decoder-Suche selbst macht weiterhin `tuexe`; `tudeploy` liefert nur die Dirs.

---

## 9. Offene Punkte zur Abnahme

1. **Name**: `tudeploy` vs. `tuboot` vs. `tumodpath`?
2. **Konvention**: Reihenfolge/Umfang der Default-Wurzeln ok, oder weitere
   (z. B. `$b/tm`, `$b/modules`)?
3. **Umbrella-Kategorie**: neue „Deployment/packaging" oder unter „Stream/
   filesystem"?
4. **resourceDirs**: soll es optional auch Dateien (nicht nur Dirs) prüfen, oder
   strikt Verzeichnisliste für `tuexe -dirs` (aktuell so vorgesehen)?
