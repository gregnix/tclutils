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

## Additional exported commands

Documented for completeness (same module, also covered by the test suite):

```tcl
tused::substitute line pattern replacement args ;# apply one sed-style substitution to a single LINE (PATTERN to REPLACEMENT); -all -nocase
```
