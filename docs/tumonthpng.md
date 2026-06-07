# tclutils::tumonthpng

Render a month calendar to a PNG image, mirroring the look of the `monthcanvas`
Tk widget (themes, week numbers, weekday header, and today / weekend / holiday /
note / other-month cell states). Pure Tcl: the month grid is computed with the
core `clock` command (no Tk, no `gel::calendar`); drawing uses
`tclutils::tupngdraw`.

## API

```tcl
package require tclutils::tumonthpng

::tclutils::tumonthpng::render year month ?options?   ;# -> PNG bytes
::tclutils::tumonthpng::write  file year month ?options?  ;# -> file
```

Options (defaults): `-theme default` (`default|dark|light`), `-scale 2`,
`-today {}` (ISO `yyyy-mm-dd`; empty = system date), `-holidays {}` (dict
date->name), `-notes {}` (dict date->text), `-firstweekday 1` (1 = Monday),
`-showweeks 1` (ISO week-number column), `-weekdays {Mo Di Mi Do Fr Sa So}`,
`-monthnames {Januar ... Dezember}`, `-title {}` (override the "Month Year"
title). Cell colours follow the chosen theme, ported from monthcanvas.

A selection overlay (for interactive front-ends) is also available:
`-select {}` (list of ISO dates to highlight), `-selectstyle outline` (default),
`-selectcolor {}`, `-selectwidth {}`, `-selectalpha 0.3`.

```tcl
tclutils::tumonthpng::write june.png 2026 6 \
    -today 2026-06-06 \
    -holidays {2026-06-08 "Pfingstmontag"} \
    -notes    {2026-06-15 "Zahnarzt"} \
    -theme default -scale 2
```

## CLI

```bash
tclsh bin/tumonthpng.tcl june.png 2026 6 -theme dark -scale 2 -today 2026-06-06
```

(The CLI exposes `-theme -scale -today -showweeks`; holidays and notes are
library options.)

## Outline fonts (-textcmd, 0.2)

By default labels use the built-in 6x8 bitmap font. Pass `-textcmd CMD` to
draw every centred label yourself: tumonthpng calls
`{*}$CMD img x y w h text color` for the title, weekday header, KW label,
week numbers and day numbers, leaving layout, themes, cell colours and the
note markers to tumonthpng. A renderer that fills real TTF/OTF glyph
outlines via `tupngdraw fillcontours` (e.g. driven by the Glyphs package)
gives proper umlauts and scalable type -- see
examples/generate-month-glyphs-demo.tcl. tumonthpng itself stays
dependency-free; the font backend is the caller's.

## Quarter and year (0.3, ported from monthcanvas)

`renderQuarter year month ?opts?` / `writeQuarter file year month ?opts?` lay
three consecutive months side by side in one image (year rollover handled).
`renderYear year ?opts?` / `writeYear file year ?opts?` tile all twelve months;
`-cols N` sets the column count (default 3). All single-month options
(`-theme`, `-scale`, `-today`, `-holidays`, `-notes`, `-showweeks`, `-textcmd`,
`-weekdays`, `-monthnames`, `-firstweekday`) apply; holidays/notes/today are
matched per date across every month. Each block carries its own "<Month> <year>"
heading. Mirrors monthcanvas drawQuarter/drawYear.

## Notes

The built-in 6x8 bitmap font covers ASCII plus the German umlauts and eszett
(ä ö ü Ä Ö Ü ß), so the default month names (including "März") render correctly;
other non-ASCII characters render as blanks. Pass ASCII `-monthnames`/`-weekdays`
if you need them, or supply a `-textcmd` for real outline glyphs. Week numbers
are ISO-8601 (`%V`); the grid math uses UTC (`-gmt 1`) so output is deterministic
and timezone-free. Holiday computation is the caller's job -- pass a `-holidays`
dict.
