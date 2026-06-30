# tclutils::tused

`tused` ist ein kleines sed-aehnliches Modul fuer portable Text-Ersetzungen und Zeilenfilter in reinem Tcl.

## Laden

```tcl
package require tclutils::tused
```

## Text ersetzen

```tcl
set out [::tclutils::tused::replace $text {foo} bar]
set out [::tclutils::tused::replace $text {foo} bar -all 1]
```

Optionen:

- `-all 1` ersetzt alle Treffer pro Zeile
- `-nocase 1` sucht ohne Gross-/Kleinschreibung
- `-fixed 1` nutzt einfache Zeichenkettensuche statt Regex

## Zeilen loeschen

```tcl
set out [::tclutils::tused::delete $text {^#}]
```

## Regel-Liste

```tcl
set rules [list \
    [list s foo bar g] \
    [list d {^#}]]

set out [::tclutils::tused::process $text $rules]
```

## Dateien

```tcl
::tclutils::tused::processFile in.txt out.txt $rules
```

Inplace mit Backup:

```tcl
::tclutils::tused::processFile in.txt ignored $rules -inplace 1 -backup .bak
```

## Einfaches Scriptformat

```tcl
set out [::tclutils::tused::script $text {
    s/foo/bar/g
    d/^#/
}]
```

Hinweis: Das Scriptformat ist bewusst klein und noch kein vollstaendiger sed-Ersatz.

## Adressen

Eine Script-Zeile kann eine Adresse vor dem Kommando (`s///` oder `d`) tragen;
das Kommando wirkt dann nur auf die passenden Zeilen:

- `N` — Zeilennummer, 1-basiert (z. B. `2s/foo/bar/`)
- `$` — letzte Zeile (z. B. `$d`)
- `/regex/` — Zeilen, die auf den regulaeren Ausdruck passen
- `addr1,addr2` — Bereich von der ersten passenden Startadresse bis zur naechsten
  passenden Endadresse; Start und Ende duerfen numerisch, `$` oder `/regex/` sein
- `first~step` — jede `step`-te Zeile ab `first` (`1~2` = ungerade Zeilen;
  `0~3` verhaelt sich wie `3~3`); nur als Einzeladresse
- `addr!cmd` — Negation: das Kommando wirkt auf alle Zeilen, die die Adresse
  *nicht* erfuellen; funktioniert auch fuer Bereiche

```tcl
::tclutils::tused::script $text {1~2s/.*/X/}    ;# jede ungerade Zeile
::tclutils::tused::script $text {/^#/!d}        ;# alles ausser Kommentarzeilen
::tclutils::tused::script $text {2,4!d}         ;# alles ausser Zeilen 2..4
```

## Additional exported commands

Documented for completeness (same module, also covered by the test suite):

```tcl
tused::substitute line pattern replacement args ;# apply one sed-style substitution to a single LINE (PATTERN to REPLACEMENT); -all -nocase
```
