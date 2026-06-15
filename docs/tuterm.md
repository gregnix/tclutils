# tclutils::tuterm

ANSI terminal styling (SGR): text attributes and 16- / 256- / 24-bit colors,
with a global enable switch (honouring the `NO_COLOR` convention), an ANSI
stripper, and optional Windows VT-mode initialisation. Pure Tcl, GUI-free.

## Package

```tcl
package require tclutils::tuterm 0.1
```

## Commands

```tcl
::tclutils::tuterm::style ?spec ...?       ;# -> SGR sequence ("" when disabled)
::tclutils::tuterm::wrap  text ?spec ...?   ;# -> styled text + reset
::tclutils::tuterm::off   attr              ;# -> the "off" SGR for one attribute
::tclutils::tuterm::names ?what?            ;# -> available names
::tclutils::tuterm::strip text              ;# -> text with SGR removed
::tclutils::tuterm::enable ?bool?           ;# -> get/set global enable flag
::tclutils::tuterm::auto                    ;# -> set enable from NO_COLOR
::tclutils::tuterm::enableVT                ;# -> Windows VT mode (no-op elsewhere)
::tclutils::tuterm::disableVT
```

## Style specs

Accepted by `style` and `wrap`:

| Spec | Meaning |
|------|---------|
| `reset` | reset all attributes |
| `bold` `dim` `italic` `underline` `blink` `reverse` `invisible` `strike` | turn the attribute **on** |
| `bold:on` / `bold:off` (any attribute) | turn explicitly on/off |
| `fg:<color>` / `bg:<color>` | foreground / background color |

`<color>` is a name (`red`, `bright_cyan`, …), a 256-color index `0..255`, or a
`#rrggbb` truecolor value. `fgcolor:` / `bgcolor:` are accepted as aliases.

## Usage

```tcl
package require tclutils::tuterm
namespace import ::tclutils::tuterm::*

puts [wrap "Important!" bold fg:red]
puts "[style fg:yellow]warning[style reset]"
puts [wrap "ok" fg:#00aa00]          ;# truecolor
puts [wrap "note" fg:208]            ;# 256-color
```

Disable color for pipes / `NO_COLOR`:

```tcl
::tclutils::tuterm::auto             ;# disables if NO_COLOR is set
# or force:
::tclutils::tuterm::enable 0
```

On Windows, enable VT processing once at startup so escapes render:

```tcl
::tclutils::tuterm::enableVT         ;# needs twapi; no-op on other platforms
```

`strip` removes SGR sequences (e.g. before measuring width or logging):

```tcl
string length [::tclutils::tuterm::strip $styled]
```

## Notes

- When disabled, `style` returns `""` and `wrap` returns the plain text, so the
  same code paths work with or without color.
- `enableVT` uses `twapi` if present; it returns 1 on success or on non-Windows
  platforms, 0 only if the Windows call failed.

## Error codes

`-errorcode {TCLUTILS TUTERM <REASON>}` (`STYLE`, `VALUE`, `CATEGORY`).
