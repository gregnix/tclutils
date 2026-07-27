# tclutils::tuprovider::ftp -- FTP provider, an adapter over the tcllib ftp client.
#
# Brings a remote FTP server to the provider interface. It is an adapter, not a
# reimplementation: every method forwards to the tcllib ftp package.
#
# Honest capabilities: ftp offers listing, get, put, delete, mkdir and rename
# (used for move), so this provider supports list/stat/get/put/delete/mkdir/move.
# It does NOT implement copy (FTP has no server-side copy); copying is done at
# the application level with get+put, so `caps` reports copy as unsupported
# (following the implement-only-what-the-backend-can-do convention).
#
#   set p [tuprovider open ftp ftp://host/pub -user u -password s]
#   $p list /pub          -> entries under /pub
#   $p caps               -> list stat get put delete mkdir move
#
# Paths are absolute FTP paths. name is derived from the path tail; the tree
# consumer treats them as opaque paths, exactly as it treats local paths.

package require Tcl 8.6-
package require TclOO
package require tclutils::tuprovider
package require ftp

oo::class create ::tclutils::tuprovider::Ftp {
    superclass ::tclutils::tuprovider::Base
    variable conn

    # url (ftp://host[:port][/base]) plus ftp::Open options (-user, -password,
    # -port, -mode passive|active, -timeout ...)
    constructor {url args} {
        # parse a minimal ftp:// url into host / port / base
        set host "" ; set port 21 ; set base "/"
        if {[regexp {^ftp://([^/:]+)(?::(\d+))?(/.*)?$} $url -> h p b]} {
            set host $h
            if {$p ne ""} { set port $p }
            if {$b ne ""} { set base $b }
        } else {
            set host $url
        }
        array set o {-user anonymous -password anonymous@ -mode passive}
        array set o $args
        if {[info exists o(-port)]} { set port $o(-port) }
        set conn [::ftp::Open $host $o(-user) $o(-password) \
                      -port $port -mode $o(-mode)]
        if {$conn < 0} { error "ftp: cannot connect to $host:$port" }
        if {$base ne "/"} { catch {::ftp::Cd $conn $base} }
    }

    destructor {
        catch {::ftp::Close $conn}
    }

    # Derive a leaf name from an FTP path ("/a/b/" -> "b", "/a/f.txt" -> "f.txt").
    method _name {path} {
        set p [string trimright $path /]
        if {$p eq ""} { return "/" }
        return [file tail $p]
    }

    method _entry {name path type size} {
        return [dict create name $name path $path type $type size $size]
    }

    # list: parse the server's LIST output into entry dicts. FTP LIST is not
    # standardized, but the common Unix format is "perms links owner group size
    # month day time/year name" -- the leading char of perms marks a directory.
    method list {path} {
        set out {}
        foreach line [::ftp::List $conn $path] {
            set line [string trim $line]
            if {$line eq ""} continue
            set fields [regexp -all -inline {\S+} $line]
            if {[llength $fields] < 9} continue
            set perms [lindex $fields 0]
            set size  [lindex $fields 4]
            set name  [join [lrange $fields 8 end] " "]
            if {$name eq "." || $name eq ".."} continue
            set type [expr {[string index $perms 0] eq "d" ? "dir" : "file"}]
            set child [expr {$path eq "/" ? "/$name" : "$path/$name"}]
            lappend out [my _entry $name $child $type \
                             [expr {[string is integer -strict $size] ? $size : 0}]]
        }
        return $out
    }

    # stat: FTP has no single stat; derive type by trying to Cd into the path,
    # and size via FileSize for files.
    method stat {path} {
        set here [::ftp::Pwd $conn]
        if {![catch {::ftp::Cd $conn $path}]} {
            ::ftp::Cd $conn $here
            return [my _entry [my _name $path] $path dir 0]
        }
        set size 0
        catch {set size [::ftp::FileSize $conn $path]}
        return [my _entry [my _name $path] $path file \
                    [expr {[string is integer -strict $size] ? $size : 0}]]
    }

    method get {path} {
        set data ""
        if {![::ftp::Get $conn $path -variable data]} {
            error "ftp: cannot get $path"
        }
        return $data
    }

    method put {path data} {
        if {![::ftp::Put $conn -data $data $path]} {
            error "ftp: cannot put $path"
        }
    }

    method delete {path} {
        if {![::ftp::Delete $conn $path]} { error "ftp: cannot delete $path" }
    }

    method mkdir {path} {
        if {![::ftp::MkDir $conn $path]} { error "ftp: cannot mkdir $path" }
    }

    method move {from to} {
        if {![::ftp::Rename $conn $from $to]} {
            error "ftp: cannot move $from -> $to"
        }
    }
}

::tclutils::tuprovider::register ftp ::tclutils::tuprovider::Ftp

package provide tclutils::tuprovider::ftp 0.1
