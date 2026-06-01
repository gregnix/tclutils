# tclutils::tuhash -- pure-Tcl cryptographic digests (SHA-256, SHA-1, MD5)
# Tcl 8.6+
#
# These are clean-room implementations of the FIPS 180-4 / RFC 1321 digests so
# the package has no dependency on tcllib or a binary extension. Digests are
# verified against the standard test vectors in tests/tuhash.test.

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tuhash {
    namespace export sha256 sha1 md5 sha256File sha1File md5File
    variable version 0.1

    # Round constants.
    variable SHA256_K {
        0x428a2f98 0x71374491 0xb5c0fbcf 0xe9b5dba5 0x3956c25b 0x59f111f1 0x923f82a4 0xab1c5ed5
        0xd807aa98 0x12835b01 0x243185be 0x550c7dc3 0x72be5d74 0x80deb1fe 0x9bdc06a7 0xc19bf174
        0xe49b69c1 0xefbe4786 0x0fc19dc6 0x240ca1cc 0x2de92c6f 0x4a7484aa 0x5cb0a9dc 0x76f988da
        0x983e5152 0xa831c66d 0xb00327c8 0xbf597fc7 0xc6e00bf3 0xd5a79147 0x06ca6351 0x14292967
        0x27b70a85 0x2e1b2138 0x4d2c6dfc 0x53380d13 0x650a7354 0x766a0abb 0x81c2c92e 0x92722c85
        0xa2bfe8a1 0xa81a664b 0xc24b8b70 0xc76c51a3 0xd192e819 0xd6990624 0xf40e3585 0x106aa070
        0x19a4c116 0x1e376c08 0x2748774c 0x34b0bcb5 0x391c0cb3 0x4ed8aa4a 0x5b9cca4f 0x682e6ff3
        0x748f82ee 0x78a5636f 0x84c87814 0x8cc70208 0x90befffa 0xa4506ceb 0xbef9a3f7 0xc67178f2
    }
    variable MD5_K {
        0xd76aa478 0xe8c7b756 0x242070db 0xc1bdceee 0xf57c0faf 0x4787c62a 0xa8304613 0xfd469501
        0x698098d8 0x8b44f7af 0xffff5bb1 0x895cd7be 0x6b901122 0xfd987193 0xa679438e 0x49b40821
        0xf61e2562 0xc040b340 0x265e5a51 0xe9b6c7aa 0xd62f105d 0x02441453 0xd8a1e681 0xe7d3fbc8
        0x21e1cde6 0xc33707d6 0xf4d50d87 0x455a14ed 0xa9e3e905 0xfcefa3f8 0x676f02d9 0x8d2a4c8a
        0xfffa3942 0x8771f681 0x6d9d6122 0xfde5380c 0xa4beea44 0x4bdecfa9 0xf6bb4b60 0xbebfbc70
        0x289b7ec6 0xeaa127fa 0xd4ef3085 0x04881d05 0xd9d4d039 0xe6db99e5 0x1fa27cf8 0xc4ac5665
        0xf4292244 0x432aff97 0xab9423a7 0xfc93a039 0x655b59c3 0x8f0ccc92 0xffeff47d 0x85845dd1
        0x6fa87e4f 0xfe2ce6e0 0xa3014314 0x4e0811a1 0xf7537e82 0xbd3af235 0x2ad7d2bb 0xeb86d391
    }
    variable MD5_S {
        7 12 17 22 7 12 17 22 7 12 17 22 7 12 17 22
        5  9 14 20 5  9 14 20 5  9 14 20 5  9 14 20
        4 11 16 23 4 11 16 23 4 11 16 23 4 11 16 23
        6 10 15 21 6 10 15 21 6 10 15 21 6 10 15 21
    }
}

proc ::tclutils::tuhash::_rotr32 {x n} {
    return [expr {(($x >> $n) | ($x << (32 - $n))) & 0xFFFFFFFF}]
}
proc ::tclutils::tuhash::_rotl32 {x n} {
    return [expr {(($x << $n) | ($x >> (32 - $n))) & 0xFFFFFFFF}]
}

# Turn a public argument into the byte string the cores operate on. With
# -encoding utf-8 (the default) a text string is encoded the way the system
# tools would in a UTF-8 locale; with -encoding binary the value is treated as
# raw bytes (each character a byte 0-255).
proc ::tclutils::tuhash::_bytes {data encoding} {
    switch -- $encoding {
        binary  { return $data }
        utf-8   { return [encoding convertto utf-8 $data] }
        default {
            return -code error -errorcode {TCLUTILS TUHASH ENCODING} \
                "unsupported -encoding \"$encoding\" (use utf-8 or binary)"
        }
    }
}

proc ::tclutils::tuhash::_sha256 {bytes} {
    variable SHA256_K
    set H {0x6a09e667 0xbb67ae85 0x3c6ef372 0xa54ff53a 0x510e527f 0x9b05688c 0x1f83d9ab 0x5be0cd19}
    set ml [expr {[string length $bytes] * 8}]
    append bytes [binary format c 0x80]
    while {[string length $bytes] % 64 != 56} { append bytes [binary format c 0] }
    append bytes [binary format W $ml]
    set n [string length $bytes]
    for {set off 0} {$off < $n} {incr off 64} {
        binary scan [string range $bytes $off [expr {$off + 63}]] Iu16 w
        for {set t 16} {$t < 64} {incr t} {
            set x [lindex $w [expr {$t - 15}]]
            set y [lindex $w [expr {$t - 2}]]
            set s0 [expr {[_rotr32 $x 7] ^ [_rotr32 $x 18] ^ ($x >> 3)}]
            set s1 [expr {[_rotr32 $y 17] ^ [_rotr32 $y 19] ^ ($y >> 10)}]
            lappend w [expr {([lindex $w [expr {$t - 16}]] + $s0 + [lindex $w [expr {$t - 7}]] + $s1) & 0xFFFFFFFF}]
        }
        lassign $H a b c d e f g h
        for {set t 0} {$t < 64} {incr t} {
            set S1 [expr {[_rotr32 $e 6] ^ [_rotr32 $e 11] ^ [_rotr32 $e 25]}]
            set ch [expr {($e & $f) ^ ((~$e & 0xFFFFFFFF) & $g)}]
            set t1 [expr {($h + $S1 + $ch + [lindex $SHA256_K $t] + [lindex $w $t]) & 0xFFFFFFFF}]
            set S0 [expr {[_rotr32 $a 2] ^ [_rotr32 $a 13] ^ [_rotr32 $a 22]}]
            set maj [expr {($a & $b) ^ ($a & $c) ^ ($b & $c)}]
            set t2 [expr {($S0 + $maj) & 0xFFFFFFFF}]
            set h $g; set g $f; set f $e; set e [expr {($d + $t1) & 0xFFFFFFFF}]
            set d $c; set c $b; set b $a; set a [expr {($t1 + $t2) & 0xFFFFFFFF}]
        }
        foreach var {a b c d e f g h} idx {0 1 2 3 4 5 6 7} {
            lset H $idx [expr {([lindex $H $idx] + [set $var]) & 0xFFFFFFFF}]
        }
    }
    set out ""
    foreach v $H { append out [format %08x $v] }
    return $out
}

proc ::tclutils::tuhash::_sha1 {bytes} {
    set h0 0x67452301; set h1 0xEFCDAB89; set h2 0x98BADCFE; set h3 0x10325476; set h4 0xC3D2E1F0
    set ml [expr {[string length $bytes] * 8}]
    append bytes [binary format c 0x80]
    while {[string length $bytes] % 64 != 56} { append bytes [binary format c 0] }
    append bytes [binary format W $ml]
    set n [string length $bytes]
    for {set off 0} {$off < $n} {incr off 64} {
        binary scan [string range $bytes $off [expr {$off + 63}]] Iu16 w
        for {set t 16} {$t < 80} {incr t} {
            set v [expr {[lindex $w [expr {$t - 3}]] ^ [lindex $w [expr {$t - 8}]] ^ \
                         [lindex $w [expr {$t - 14}]] ^ [lindex $w [expr {$t - 16}]]}]
            lappend w [_rotl32 $v 1]
        }
        lassign [list $h0 $h1 $h2 $h3 $h4] a b c d e
        for {set t 0} {$t < 80} {incr t} {
            if {$t < 20} {
                set f [expr {($b & $c) | ((~$b & 0xFFFFFFFF) & $d)}]; set k 0x5A827999
            } elseif {$t < 40} {
                set f [expr {$b ^ $c ^ $d}]; set k 0x6ED9EBA1
            } elseif {$t < 60} {
                set f [expr {($b & $c) | ($b & $d) | ($c & $d)}]; set k 0x8F1BBCDC
            } else {
                set f [expr {$b ^ $c ^ $d}]; set k 0xCA62C1D6
            }
            set tmp [expr {([_rotl32 $a 5] + $f + $e + $k + [lindex $w $t]) & 0xFFFFFFFF}]
            set e $d; set d $c; set c [_rotl32 $b 30]; set b $a; set a $tmp
        }
        set h0 [expr {($h0 + $a) & 0xFFFFFFFF}]; set h1 [expr {($h1 + $b) & 0xFFFFFFFF}]
        set h2 [expr {($h2 + $c) & 0xFFFFFFFF}]; set h3 [expr {($h3 + $d) & 0xFFFFFFFF}]
        set h4 [expr {($h4 + $e) & 0xFFFFFFFF}]
    }
    return [format %08x%08x%08x%08x%08x $h0 $h1 $h2 $h3 $h4]
}

proc ::tclutils::tuhash::_md5 {bytes} {
    variable MD5_K
    variable MD5_S
    set a0 0x67452301; set b0 0xefcdab89; set c0 0x98badcfe; set d0 0x10325476
    set ml [expr {[string length $bytes] * 8}]
    append bytes [binary format c 0x80]
    while {[string length $bytes] % 64 != 56} { append bytes [binary format c 0] }
    append bytes [binary format w $ml]
    set n [string length $bytes]
    for {set off 0} {$off < $n} {incr off 64} {
        binary scan [string range $bytes $off [expr {$off + 63}]] iu16 M
        lassign [list $a0 $b0 $c0 $d0] A B C D
        for {set i 0} {$i < 64} {incr i} {
            if {$i < 16} {
                set F [expr {($B & $C) | ((~$B & 0xFFFFFFFF) & $D)}]; set g $i
            } elseif {$i < 32} {
                set F [expr {($D & $B) | ((~$D & 0xFFFFFFFF) & $C)}]; set g [expr {(5 * $i + 1) % 16}]
            } elseif {$i < 48} {
                set F [expr {$B ^ $C ^ $D}]; set g [expr {(3 * $i + 5) % 16}]
            } else {
                set F [expr {$C ^ ($B | (~$D & 0xFFFFFFFF))}]; set g [expr {(7 * $i) % 16}]
            }
            set F [expr {($F + $A + [lindex $MD5_K $i] + [lindex $M $g]) & 0xFFFFFFFF}]
            set A $D; set D $C; set C $B
            set B [expr {($B + [_rotl32 $F [lindex $MD5_S $i]]) & 0xFFFFFFFF}]
        }
        set a0 [expr {($a0 + $A) & 0xFFFFFFFF}]; set b0 [expr {($b0 + $B) & 0xFFFFFFFF}]
        set c0 [expr {($c0 + $C) & 0xFFFFFFFF}]; set d0 [expr {($d0 + $D) & 0xFFFFFFFF}]
    }
    set out ""
    foreach v [list $a0 $b0 $c0 $d0] {
        append out [format %02x%02x%02x%02x [expr {$v & 0xff}] \
            [expr {($v >> 8) & 0xff}] [expr {($v >> 16) & 0xff}] [expr {($v >> 24) & 0xff}]]
    }
    return $out
}

# Public string digests. `data ?-encoding utf-8|binary?`
proc ::tclutils::tuhash::sha256 {data args} {
    set opts [::tclutils::common::parseOptions [dict create -encoding utf-8] {*}$args]
    return [_sha256 [_bytes $data [dict get $opts -encoding]]]
}
proc ::tclutils::tuhash::sha1 {data args} {
    set opts [::tclutils::common::parseOptions [dict create -encoding utf-8] {*}$args]
    return [_sha1 [_bytes $data [dict get $opts -encoding]]]
}
proc ::tclutils::tuhash::md5 {data args} {
    set opts [::tclutils::common::parseOptions [dict create -encoding utf-8] {*}$args]
    return [_md5 [_bytes $data [dict get $opts -encoding]]]
}

# File digests -- hash the exact bytes on disk.
proc ::tclutils::tuhash::sha256File {path} { return [_sha256 [::tclutils::common::readBinaryFile $path]] }
proc ::tclutils::tuhash::sha1File   {path} { return [_sha1   [::tclutils::common::readBinaryFile $path]] }
proc ::tclutils::tuhash::md5File    {path} { return [_md5    [::tclutils::common::readBinaryFile $path]] }

package provide tclutils::tuhash 0.1
