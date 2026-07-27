# tclutils::tuprovider::zip -- read-only ZIP provider over tuzip.
#
# A ZIP archive is a flat list of entries ("a/b/c.txt"); there are no real
# directories, only implied ones. This provider synthesises the tree: given a
# path, it returns the immediate children -- both files and the directories
# implied by longer paths.
#
# Read-only by design (Weg C): inherits from Base and implements only
# list / stat / get. caps() therefore reports exactly {list stat get}; any
# write attempt fails cleanly. tuzip 0.1 can create archives, but changing an
# entry inside an existing archive is out of scope here.
#
#   set p [tuprovider open zip /path/to/archive.zip]
#   $p list /            -> top-level entries
#   $p list /sub         -> children of the "sub" directory
#   $p get  /sub/f.txt   -> file contents
#   $p caps              -> list stat get
#
# Paths use "/" and a leading slash for the archive root. Internally they map
# to tuzip member names (no leading slash, trailing slash for dirs).

package require Tcl 8.6-
package require TclOO
package require tclutils::tuprovider
package require tclutils::tuzip

oo::class create ::tclutils::tuprovider::Zip {
    superclass ::tclutils::tuprovider::Base
    variable zipfile
    variable sizes      ;# member name -> uncompressed size

    constructor {file} {
        set zipfile $file
        if {![file exists $zipfile]} { error "no such zip: $zipfile" }
        # Read the central directory once; cache sizes. Member names are the
        # flat entry list, e.g. "a/", "a/b.txt", "c.txt".
        set sizes [dict create]
        foreach e [::tclutils::tuzip::entries $zipfile] {
            dict set sizes [dict get $e name] [dict get $e uncompressedSize]
        }
    }

    # ---- path <-> member mapping -------------------------------------------
    # Provider path "/sub/f.txt" -> member "sub/f.txt"; "/" -> "".
    method _member {path} {
        return [string trimleft $path /]
    }

    # ---- list: immediate children of a directory path ----------------------
    method list {path} {
        set prefix [my _member $path]
        if {$prefix ne "" && [string index $prefix end] ne "/"} {
            append prefix /
        }
        set plen [string length $prefix]
        set seen [dict create]     ;# child leaf -> type, deduplicated
        foreach member [dict keys $sizes] {
            # only entries under this prefix
            if {![string equal -length $plen $prefix $member]} continue
            set rest [string range $member $plen end]
            if {$rest eq ""} continue                 ;# the dir entry itself
            set slash [string first / $rest]
            if {$slash < 0} {
                # a file directly in this directory
                dict set seen $rest file
            } else {
                # a subdirectory (implied by a longer path)
                set sub [string range $rest 0 [expr {$slash-1}]]
                # do not overwrite a file of the same name with dir
                if {![dict exists $seen $sub]} { dict set seen $sub dir }
            }
        }
        set out {}
        dict for {leaf type} $seen {
            set childpath [expr {$path eq "/" ? "/$leaf" : "$path/$leaf"}]
            set size [expr {$type eq "file"
                            ? [my _size [my _member $childpath]] : ""}]
            lappend out [my _entry $leaf $childpath $type $size]
        }
        return $out
    }

    method _size {member} {
        return [expr {[dict exists $sizes $member] ? [dict get $sizes $member] : ""}]
    }

    # ---- stat: one entry, or error -----------------------------------------
    method stat {path} {
        if {$path eq "/"} { return [my _entry / / dir] }
        set member [my _member $path]
        # exact file match?
        if {[dict exists $sizes $member]} {
            return [my _entry [file tail $member] $path file \
                              [dict get $sizes $member]]
        }
        # directory? true if any member starts with "member/"
        set dpfx "$member/"
        set dlen [string length $dpfx]
        foreach m [dict keys $sizes] {
            if {[string equal -length $dlen $dpfx $m]} {
                return [my _entry [file tail $member] $path dir]
            }
        }
        error "no such path: $path"
    }

    # ---- get: file contents ------------------------------------------------
    method get {path} {
        return [::tclutils::tuzip::readMember $zipfile [my _member $path]]
    }

    # mkdir/put/delete/move/copy deliberately absent -- read-only provider.
}

::tclutils::tuprovider::register zip ::tclutils::tuprovider::Zip

package provide tclutils::tuprovider::zip 0.1
