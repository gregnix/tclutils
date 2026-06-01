# tclutils::tufile -- file type detection by magic signatures
# Tcl 8.6+
#
# Detect a file's type from its header bytes (magic numbers), like the Unix
# "file" command. The signature table is user-extensible (register entries or
# load them from a text file), and the module can flag files whose extension
# does not match their detected type.
#
# A signature is matched as: the bytes at a fixed offset equal a fixed pattern.
# That covers the common single-marker formats and, thanks to the offset,
# container formats whose marker sits at a known position (e.g. ODF's mimetype
# stored at offset 30). It is intentionally simpler than a full libmagic: no
# masks, no value ranges, no nested rules.

package require Tcl 8.6-

namespace eval ::tclutils {}
namespace eval ::tclutils::tufile {
    namespace export detect type mime describe checkExtension \
        register forget signatures reset loadFile
    variable version 0.1
    # name -> dict {offset N bytes <binary> mime M ext {e ...} desc D}
    variable table {}
    variable initialized 0
}

proc ::tclutils::tufile::_hex {h} {
    regsub -all {\s} $h "" h
    return [binary decode hex $h]
}

# Register a signature. Options:
#   -offset N        byte offset of the marker (default 0)
#   -hex HEX         marker bytes as a hex string   (use one of -hex / -ascii)
#   -ascii STRING    marker bytes as ASCII text
#   -mime MIME       media type
#   -ext {e1 e2 ..}  expected lowercase extensions (without the dot)
#   -desc TEXT       human-readable description
proc ::tclutils::tufile::register {name args} {
    variable table
    set offset 0; set bytes ""; set mime ""; set ext {}; set desc ""
    set i 0
    while {$i < [llength $args]} {
        set opt [lindex $args $i]
        incr i
        if {$i >= [llength $args]} {
            return -code error -errorcode {TCLUTILS TUFILE OPTION} \
                "missing value for option \"$opt\""
        }
        set val [lindex $args $i]
        incr i
        switch -- $opt {
            -offset { set offset $val }
            -hex    { set bytes [_hex $val] }
            -ascii  { set bytes $val }
            -mime   { set mime $val }
            -ext    { set ext [lmap e $val {string tolower $e}] }
            -desc   { set desc $val }
            default {
                return -code error -errorcode {TCLUTILS TUFILE OPTION} \
                    "unknown option \"$opt\""
            }
        }
    }
    if {$bytes eq ""} {
        return -code error -errorcode {TCLUTILS TUFILE SIGNATURE} \
            "signature \"$name\" needs a -hex or -ascii marker"
    }
    dict set table $name \
        [dict create offset $offset bytes $bytes mime $mime ext $ext desc $desc]
    return $name
}

proc ::tclutils::tufile::forget {name} {
    variable table
    dict unset table $name
    return
}

# Restore the built-in table, discarding user additions.
proc ::tclutils::tufile::reset {} {
    variable table
    variable initialized
    set table {}
    set initialized 0
    _init
    return
}

proc ::tclutils::tufile::signatures {} {
    variable table
    _init
    return [dict keys $table]
}

proc ::tclutils::tufile::_init {} {
    variable initialized
    if {$initialized} return
    set initialized 1
    set R ::tclutils::tufile::register
    $R png   -hex 89504E470D0A1A0A          -mime image/png        -ext png       -desc "PNG image"
    $R jpeg  -hex FFD8FF                     -mime image/jpeg       -ext {jpg jpeg} -desc "JPEG image"
    $R gif87 -ascii GIF87a                   -mime image/gif        -ext gif       -desc "GIF image (87a)"
    $R gif89 -ascii GIF89a                   -mime image/gif        -ext gif       -desc "GIF image (89a)"
    $R bmp   -ascii BM                       -mime image/bmp        -ext bmp       -desc "BMP image"
    $R tiffle -hex 49492A00                  -mime image/tiff       -ext {tif tiff} -desc "TIFF image (little-endian)"
    $R tiffbe -hex 4D4D002A                  -mime image/tiff       -ext {tif tiff} -desc "TIFF image (big-endian)"
    $R webp  -offset 8 -ascii WEBP           -mime image/webp       -ext webp      -desc "WebP image"
    $R pdf   -ascii %PDF-                     -mime application/pdf  -ext pdf       -desc "PDF document"
    $R ps    -ascii %!                        -mime application/postscript -ext {ps eps} -desc "PostScript"
    $R rtf   -ascii "\{\\rtf"                 -mime application/rtf  -ext rtf       -desc "Rich Text Format"
    $R xml   -ascii "<?xml"                   -mime text/xml         -ext xml       -desc "XML document"
    $R gzip  -hex 1F8B                        -mime application/gzip -ext {gz tgz}  -desc "gzip compressed"
    $R bzip2 -ascii BZh                       -mime application/x-bzip2 -ext bz2    -desc "bzip2 compressed"
    $R xz    -hex FD377A585A00                -mime application/x-xz -ext xz        -desc "xz compressed"
    $R zstd  -hex 28B52FFD                    -mime application/zstd -ext zst       -desc "zstandard compressed"
    $R sevenz -hex 377ABCAF271C               -mime application/x-7z-compressed -ext 7z -desc "7-Zip archive"
    $R rar   -hex 526172211A07                -mime application/vnd.rar -ext rar    -desc "RAR archive"
    $R zip   -hex 504B0304                    -mime application/zip  -ext {zip jar} -desc "ZIP archive"
    $R tar   -offset 257 -ascii ustar         -mime application/x-tar -ext tar      -desc "tar archive"
    $R odt   -offset 30 -ascii mimetypeapplication/vnd.oasis.opendocument.text         -mime application/vnd.oasis.opendocument.text         -ext odt -desc "OpenDocument Text"
    $R ods   -offset 30 -ascii mimetypeapplication/vnd.oasis.opendocument.spreadsheet  -mime application/vnd.oasis.opendocument.spreadsheet  -ext ods -desc "OpenDocument Spreadsheet"
    $R odp   -offset 30 -ascii mimetypeapplication/vnd.oasis.opendocument.presentation -mime application/vnd.oasis.opendocument.presentation -ext odp -desc "OpenDocument Presentation"
    $R elf   -hex 7F454C46                    -mime application/x-executable -ext {} -desc "ELF executable"
    $R class -hex CAFEBABE                    -mime application/java-vm -ext class  -desc "Java class file"
    $R wasm  -hex 0061736D                    -mime application/wasm -ext wasm      -desc "WebAssembly binary"
    $R sqlite -ascii "SQLite format 3\x00"    -mime application/vnd.sqlite3 -ext {sqlite db} -desc "SQLite 3 database"
    $R mp3   -ascii ID3                        -mime audio/mpeg       -ext mp3       -desc "MP3 audio (ID3)"
    $R ogg   -ascii OggS                       -mime audio/ogg        -ext ogg       -desc "Ogg media"
    $R flac  -ascii fLaC                       -mime audio/flac       -ext flac      -desc "FLAC audio"
    $R wav   -offset 8 -ascii WAVE             -mime audio/wav        -ext wav       -desc "WAV audio"
    $R avi   -offset 8 -ascii "AVI "           -mime video/x-msvideo  -ext avi       -desc "AVI video"
    $R mp4   -offset 4 -ascii ftyp             -mime video/mp4        -ext {mp4 m4v mov} -desc "ISO Media (MP4/MOV)"
    return
}

proc ::tclutils::tufile::_neededBytes {} {
    variable table
    set need 512
    dict for {name sig} $table {
        set n [expr {[dict get $sig offset] + [string length [dict get $sig bytes]]}]
        if {$n > $need} { set need $n }
    }
    return $need
}

proc ::tclutils::tufile::_readHeader {path} {
    set fh [open $path rb]
    try {
        fconfigure $fh -translation binary -encoding iso8859-1
        return [read $fh [_neededBytes]]
    } finally {
        close $fh
    }
}

proc ::tclutils::tufile::_matches {header sig} {
    set off [dict get $sig offset]
    set pat [dict get $sig bytes]
    set end [expr {$off + [string length $pat] - 1}]
    if {$off < 0 || $end >= [string length $header]} { return 0 }
    return [expr {[string range $header $off $end] eq $pat}]
}

# Detect the file type. Returns the matching signature as a dict with the
# signature name added under "name", or an empty dict if nothing matched.
# When several signatures match, the most specific (longest marker) wins.
proc ::tclutils::tufile::detect {path} {
    variable table
    _init
    set header [_readHeader $path]
    set bestName ""
    set bestLen -1
    dict for {name sig} $table {
        if {[_matches $header $sig]} {
            set len [string length [dict get $sig bytes]]
            if {$len > $bestLen} { set bestName $name; set bestLen $len }
        }
    }
    if {$bestName eq ""} { return {} }
    return [dict merge [dict create name $bestName] [dict get $table $bestName]]
}

# Short type name ("png", "pdf", ...) or "" if unknown.
proc ::tclutils::tufile::type {path} {
    set d [detect $path]
    return [expr {[dict exists $d name] ? [dict get $d name] : ""}]
}

# MIME type or "" if unknown.
proc ::tclutils::tufile::mime {path} {
    set d [detect $path]
    return [expr {[dict exists $d mime] ? [dict get $d mime] : ""}]
}

# Human-readable description; "data" if the type is not recognized.
proc ::tclutils::tufile::describe {path} {
    set d [detect $path]
    if {[dict exists $d desc] && [dict get $d desc] ne ""} {
        return [dict get $d desc]
    }
    return "data"
}

# Compare the file's extension against its detected type. Returns a dict:
#   path detected declared expected status
# status: ok | mismatch | noext | unknown (type not detected) |
#         unknownext (detected type declares no extensions)
proc ::tclutils::tufile::checkExtension {path} {
    variable table
    _init
    set declared [string tolower [string trimleft [file extension $path] .]]
    set name [type $path]
    if {$name eq ""} {
        set status unknown
        set expected {}
    } else {
        set expected [dict get $table $name ext]
        if {$declared eq ""} {
            set status noext
        } elseif {$expected eq ""} {
            set status unknownext
        } elseif {$declared in $expected} {
            set status ok
        } else {
            set status mismatch
        }
    }
    return [dict create path $path detected $name declared $declared \
        expected $expected status $status]
}

# Load signatures from a text file. One signature per line; "#" starts a
# comment; fields separated by "|":
#   name | offset | hex-or-@ascii | mime | ext1,ext2 | description
# A marker beginning with "@" is taken as ASCII text, otherwise as hex.
proc ::tclutils::tufile::loadFile {path} {
    _init
    set fh [open $path r]
    try {
        fconfigure $fh -encoding utf-8
        set count 0
        foreach line [split [read $fh] \n] {
            set line [string trim $line]
            if {$line eq "" || [string index $line 0] eq "#"} continue
            set f [lmap x [split $line |] {string trim $x}]
            if {[llength $f] < 3} {
                return -code error -errorcode {TCLUTILS TUFILE LOAD} \
                    "bad signature line: $line"
            }
            lassign $f name offset marker mime exts desc
            set exts [lmap e [split $exts ,] {string trim $e}]
            if {[string index $marker 0] eq "@"} {
                set markerOpt [list -ascii [string range $marker 1 end]]
            } else {
                set markerOpt [list -hex $marker]
            }
            register $name -offset $offset {*}$markerOpt \
                -mime $mime -ext $exts -desc $desc
            incr count
        }
        return $count
    } finally {
        close $fh
    }
}

package provide tclutils::tufile 0.1
