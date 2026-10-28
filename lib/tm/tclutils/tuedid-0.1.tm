# tclutils::tuedid -- read the EDID block of a monitor.
# Description: parse a monitor's EDID block: vendor, model, serial, size, preferred mode
# Category: System · runtime
# A monitor reports itself in 128 bytes (EDID 1.x): vendor, product code,
# serial number, week and year of manufacture, physical size and its
# preferred video mode; descriptors carry the model name and a serial
# string. Linux exposes the bytes in /sys/class/drm/*/edid, Windows in the
# registry (Enum\DISPLAY\...\Device Parameters\EDID), macOS through ioreg;
# xrandr --verbose prints them as hex. Pure Tcl, no Tk.
#
# API:
#   tclutils::tuedid::parse    bytes       -> dict
#   tclutils::tuedid::parseHex text        -> dict (hex digits, whitespace ignored)
#   tclutils::tuedid::vendor   code        -> vendor name or ""
#
# Result keys: valid (checksum ok) version manufacturer vendor productCode
# serial serialText name text week year digital widthCm heightCm diagonal
# (inches, 0 when the size is unknown) preferred {width height refresh}
# extensions. Missing values are "" (text) or 0 (numbers).
#
# Error codes: {TCLUTILS TUEDID SHORT} (fewer than 128 bytes),
# {TCLUTILS TUEDID HEADER} (no EDID header), {TCLUTILS TUEDID HEX}.
#
# Tcl 8.6-
package require Tcl 8.6-

namespace eval ::tclutils::tuedid {
    namespace export parse parseHex vendor
    variable version 0.1
    # PNP ids of common monitor and panel makers.
    variable vendors {
        AAC AcerView ACI ASUS ACR Acer AOC AOC APP Apple AUO {AU Optronics} AUS ASUS
        BNQ BenQ BOE BOE CMN Innolux CMO {Chi Mei} DEL Dell ENC Eizo
        FUS Fujitsu GBT Gigabyte GSM LG HPN HP HWP HP IVM Iiyama LEN Lenovo
        HPQ HP LGD {LG Display} MED Medion MEI Panasonic MSI MSI NEC NEC PHL Philips SAM Samsung
        SDC {Samsung Display} SHP Sharp SNY Sony TSB Toshiba VSC ViewSonic
        HSD HannStar CPT {Chunghwa Picture Tubes} IVO InfoVision XMI Xiaomi
        VIZ Vizio WAC Wacom FNI Funai HKC HKC SPT Sceptre
    }
}

proc ::tclutils::tuedid::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TUEDID $reason] $msg
}

proc ::tclutils::tuedid::vendor {code} {
    variable vendors
    if {[dict exists $vendors $code]} { return [dict get $vendors $code] }
    return ""
}

proc ::tclutils::tuedid::parseHex {text} {
    set hex [regsub -all {[\s:]} $text ""]
    if {[string length $hex] % 2 || ![regexp {^[0-9A-Fa-f]*$} $hex]} {
        _err HEX "not a hex string"
    }
    return [parse [binary format H* $hex]]
}

# Text of a display descriptor: up to 13 bytes, ends at LF, padded with spaces.
proc ::tclutils::tuedid::_text {b off} {
    set s ""
    for {set i [expr {$off + 5}]} {$i < $off + 18} {incr i} {
        set c [lindex $b $i]
        if {$c == 0x0A || $c == 0} break
        if {$c >= 0x20 && $c < 0x7F} { append s [format %c $c] }
    }
    return [string trim $s]
}

proc ::tclutils::tuedid::parse {bytes} {
    if {[string length $bytes] < 128} {
        _err SHORT "EDID needs 128 bytes, got [string length $bytes]"
    }
    binary scan $bytes cu128 b
    if {[lrange $b 0 7] ne {0 255 255 255 255 255 255 0}} {
        _err HEADER "no EDID header"
    }
    set sum 0
    foreach v $b { incr sum $v }

    set m [expr {([lindex $b 8] << 8) | [lindex $b 9]}]
    set code ""
    foreach shift {10 5 0} {
        set c [expr {($m >> $shift) & 0x1F}]
        append code [expr {$c >= 1 && $c <= 26 ? [format %c [expr {64 + $c}]] : "?"}]
    }
    set product [expr {[lindex $b 10] | ([lindex $b 11] << 8)}]
    set serial [expr {[lindex $b 12] | ([lindex $b 13] << 8)
                      | ([lindex $b 14] << 16) | ([lindex $b 15] << 24)}]
    set week [lindex $b 16]
    set year [expr {[lindex $b 17] ? 1990 + [lindex $b 17] : 0}]
    set w [lindex $b 21]
    set h [lindex $b 22]
    set diag 0
    if {$w > 0 && $h > 0} {
        set diag [expr {round(sqrt($w*$w + $h*$h) / 2.54 * 10) / 10.0}]
    }
    set d [dict create \
        valid        [expr {$sum % 256 == 0}] \
        version      "[lindex $b 18].[lindex $b 19]" \
        manufacturer $code \
        vendor       [vendor $code] \
        productCode  [format %04X $product] \
        serial       $serial \
        serialText   "" \
        name         "" \
        text         "" \
        week         $week \
        year         $year \
        digital      [expr {([lindex $b 20] & 0x80) ? 1 : 0}] \
        widthCm      $w \
        heightCm     $h \
        diagonal     $diag \
        preferred    {} \
        extensions   [lindex $b 126]]

    foreach off {54 72 90 108} {
        set clock [expr {[lindex $b $off] | ([lindex $b [expr {$off+1}]] << 8)}]
        if {$clock != 0} {
            # detailed timing; the first one is the preferred mode
            if {[dict get $d preferred] ne ""} continue
            set ha [expr {[lindex $b [expr {$off+2}]] | (([lindex $b [expr {$off+4}]] >> 4) << 8)}]
            set hb [expr {[lindex $b [expr {$off+3}]] | (([lindex $b [expr {$off+4}]] & 0xF) << 8)}]
            set va [expr {[lindex $b [expr {$off+5}]] | (([lindex $b [expr {$off+7}]] >> 4) << 8)}]
            set vb [expr {[lindex $b [expr {$off+6}]] | (([lindex $b [expr {$off+7}]] & 0xF) << 8)}]
            set rate 0
            if {($ha + $hb) > 0 && ($va + $vb) > 0} {
                set rate [expr {round($clock * 10000.0 / (($ha + $hb) * ($va + $vb)) * 100) / 100.0}]
            }
            dict set d preferred [dict create width $ha height $va refresh $rate]
            continue
        }
        switch -- [lindex $b [expr {$off+3}]] {
            252 { dict set d name       [_text $b $off] }
            255 { dict set d serialText [_text $b $off] }
            254 {
                set t [_text $b $off]
                if {[dict get $d text] eq ""} { dict set d text $t } else { dict append d text " " $t }
            }
        }
    }
    return $d
}

package provide tclutils::tuedid 0.1
