# tclutils::tuedid

Read the EDID block of a monitor. A monitor describes itself in 128 bytes
(EDID 1.x): vendor, product code, serial number, week and year of
manufacture, physical size and its preferred video mode; text descriptors
carry the model name and a serial string. Pure Tcl, no Tk.

Where the bytes come from:

| System | Source |
|--------|--------|
| Linux | `/sys/class/drm/card*-*/edid` (readable without root), `xrandr --verbose` (hex) |
| Windows | registry `HKLM\SYSTEM\CurrentControlSet\Enum\DISPLAY\<id>\<instance>\Device Parameters`, value `EDID` |
| macOS | `ioreg -l -w0 -r -c IODisplayConnect` (`IODisplayEDID`, hex) |

`tclutils::tusysinfo` reads them for you; use `tuedid` directly for a
single block.

## Load

```tcl
package require tclutils::tuedid 0.1
```

## API

```tcl
::tclutils::tuedid::parse    bytes   ;# -> dict
::tclutils::tuedid::parseHex text    ;# hex digits; spaces, newlines, ":" ignored
::tclutils::tuedid::vendor   code    ;# "DEL" -> "Dell", unknown -> ""
```

Only the first 128 bytes are read; extension blocks (CEA-861, DisplayID)
are counted in `extensions`, not decoded.

## Result

| Key | Meaning |
|-----|---------|
| `valid` | 1 when the checksum is right; a block with a wrong checksum is still parsed |
| `version` | EDID version, e.g. `1.4` |
| `manufacturer` | three-letter PNP id, e.g. `DEL` |
| `vendor` | name for common ids, else empty |
| `productCode` | product code, four hex digits |
| `serial` | numeric serial number (often 0) |
| `serialText` | serial string from a descriptor, else empty |
| `name` | model name from a descriptor, else empty |
| `text` | other text descriptors |
| `week`, `year` | week and year of manufacture (0 when unknown) |
| `digital` | 1 for a digital input |
| `widthCm`, `heightCm` | physical size; 0 when unknown (projectors) |
| `diagonal` | diagonal in inches, one decimal; 0 when the size is unknown |
| `preferred` | `width`, `height`, `refresh` (Hz) of the first detailed timing, or empty |
| `extensions` | number of extension blocks |

## Example

```tcl
set fh [open /sys/class/drm/card0-DP-1/edid rb]
set d [::tclutils::tuedid::parse [read $fh]]
close $fh
puts "[dict get $d vendor] [dict get $d name], [dict get $d diagonal]\""
# -> Dell DELL P2722H, 27.2"
```

## Errors

`{TCLUTILS TUEDID SHORT}` fewer than 128 bytes, `{TCLUTILS TUEDID HEADER}`
no EDID header, `{TCLUTILS TUEDID HEX}` text that is not hex.
