# tuico-0.1.tm -- Windows icon (.ico) container, pure Tcl.
#
# Copyright (c) 2026 Gregor
# MIT licensed.
#
# Reads and writes the .ico container format. Payloads are handed in and out as
# raw bytes; this module never rasterises anything, so it needs no Tk and runs
# headless.
#
# Payload formats:
#   PNG  -- what this module writes. Windows accepts PNG-compressed icon
#           entries since Vista, and PNG carries a real alpha channel.
#   BMP  -- the classic (DIB) payload. Recognised on read, reported as such;
#           writing BMP payloads is out of scope.
#
# Relation to tklib's `ico` package: that one reads icons from ICO/EXE/DLL/ICL
# and writes BMP-payload entries, but cannot write a true 32bpp alpha icon from
# a Tk image. This module covers exactly that gap and does nothing else.
#
# Errors use errorCode {TCLUTILS TUICO <REASON>}.

package require Tcl 8.6-

namespace eval ::tclutils::tuico {
    namespace export write info extract
    namespace ensemble create

    # 8-byte PNG signature.
    variable pngSignature "\x89PNG\r\n\x1a\n"
}

# throw --
#   Raise an error with the module's errorCode convention.
proc ::tclutils::tuico::throw {reason message} {
    return -code error -errorcode [list TCLUTILS TUICO $reason] $message
}

# isPng --
#   True if the byte string starts with the PNG signature.
proc ::tclutils::tuico::isPng {bytes} {
    variable pngSignature
    return [expr {[string range $bytes 0 7] eq $pngSignature}]
}

# pngSize --
#   Width and height from a PNG IHDR chunk, as a two-element list.
proc ::tclutils::tuico::pngSize {bytes} {
    if {![isPng $bytes]} {
        throw BADPNG "not a PNG image"
    }
    # IHDR payload starts at offset 16: width and height as big-endian uint32.
    binary scan [string range $bytes 16 23] II width height
    return [list $width $height]
}

# write --
#   Write an .ico file from a list of {size pngData} pairs.
#
#   entries   list of two-element lists: the nominal size in pixels and the
#             PNG payload as a byte string.
#
#   Returns the number of bytes written.
proc ::tclutils::tuico::write {outFile entries} {
    if {[llength $entries] == 0} {
        throw NOENTRIES "no icon entries given"
    }
    if {[llength $entries] > 65535} {
        throw TOOMANY "an .ico file holds at most 65535 entries"
    }

    # Validate before writing anything, so a bad call leaves no partial file.
    set checked {}
    foreach entry $entries {
        if {[llength $entry] != 2} {
            throw BADENTRY "entry must be a {size data} pair, got: $entry"
        }
        lassign $entry size data
        if {![string is integer -strict $size] || $size < 1 || $size > 256} {
            throw BADSIZE "size must be an integer 1..256, got: $size"
        }
        if {![isPng $data]} {
            throw BADPNG "payload for size $size is not a PNG image"
        }
        lassign [pngSize $data] pw ph
        if {$pw != $size || $ph != $size} {
            throw SIZEMISMATCH \
                "payload for size $size is ${pw}x${ph}, expected ${size}x${size}"
        }
        lappend checked [list $size $data]
    }

    set count [llength $checked]

    # ICONDIR: reserved(0) type(1 = icon) count -- all little-endian uint16.
    set header [binary format sss 0 1 $count]

    # Payloads follow the directory; 16 bytes per directory entry.
    set offset [expr {6 + 16 * $count}]
    set directory ""
    set payloads ""

    foreach entry $checked {
        lassign $entry size data
        set length [string length $data]
        # In the directory a dimension of 0 means 256.
        set dim [expr {$size >= 256 ? 0 : $size}]

        append directory [binary format cccc $dim $dim 0 0]
        append directory [binary format ss 1 32]        ;# planes, bits per pixel
        append directory [binary format ii $length $offset]

        append payloads $data
        incr offset $length
    }

    set data $header$directory$payloads

    if {[catch {open $outFile wb} channel]} {
        throw WRITEFAILED "cannot open $outFile for writing: $channel"
    }
    try {
        puts -nonewline $channel $data
    } finally {
        close $channel
    }
    return [string length $data]
}

# readFile --
#   Slurp a file as binary data.
proc ::tclutils::tuico::readFile {path} {
    if {[catch {open $path rb} channel]} {
        throw READFAILED "cannot open $path for reading: $channel"
    }
    try {
        set data [read $channel]
    } finally {
        close $channel
    }
    return $data
}

# info --
#   Describe the entries of an .ico file. Returns a list of dicts with the keys
#   width, height, bpp, format (png|bmp), offset and length.
proc ::tclutils::tuico::info {icoFile} {
    set data [readFile $icoFile]
    if {[string length $data] < 6} {
        throw BADFILE "$icoFile is too short to be an .ico file"
    }
    binary scan $data sss reserved type count
    if {$reserved != 0 || $type != 1} {
        throw BADFILE "$icoFile is not an .ico file (reserved=$reserved type=$type)"
    }

    set result {}
    for {set i 0} {$i < $count} {incr i} {
        set base [expr {6 + 16 * $i}]
        set entry [string range $data $base [expr {$base + 15}]]
        if {[string length $entry] < 16} {
            throw TRUNCATED "$icoFile: directory entry $i is truncated"
        }
        binary scan $entry cucucucussii \
            width height colors res planes bpp length offset

        # 0 in the directory means 256.
        if {$width  == 0} { set width  256 }
        if {$height == 0} { set height 256 }

        set payload [string range $data $offset [expr {$offset + $length - 1}]]
        set format [expr {[isPng $payload] ? "png" : "bmp"}]

        lappend result [dict create \
            width  $width \
            height $height \
            bpp    $bpp \
            format $format \
            offset $offset \
            length $length]
    }
    return $result
}

# extract --
#   Return the raw payload of the entry with the given width. With outFile
#   given, the payload is also written there.
proc ::tclutils::tuico::extract {icoFile size {outFile ""}} {
    set data [readFile $icoFile]
    foreach entry [info $icoFile] {
        if {[dict get $entry width] != $size} {
            continue
        }
        set offset [dict get $entry offset]
        set length [dict get $entry length]
        set payload [string range $data $offset [expr {$offset + $length - 1}]]
        if {$outFile ne ""} {
            if {[catch {open $outFile wb} channel]} {
                throw WRITEFAILED "cannot open $outFile for writing: $channel"
            }
            try {
                puts -nonewline $channel $payload
            } finally {
                close $channel
            }
        }
        return $payload
    }
    throw NOSUCHSIZE "$icoFile has no entry of size $size"
}

package provide tclutils::tuico 0.1
