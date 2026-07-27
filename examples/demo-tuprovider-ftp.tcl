source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tuprovider
package require tclutils::tuprovider::ftp

# The ftp backend browses a remote FTP server through the same interface. A live
# demo needs a reachable server, e.g.:
#
#     set p [::tclutils::tuprovider open ftp ftp://ftp.example.org/pub \
#                -user anonymous -password me@example.org]
#     foreach e [$p list /pub] { puts [dict get $e name] }
#
# To keep this demo self-contained and offline, we stub the tcllib ftp layer so
# the adapter's own logic -- caps and the LIST parsing -- can be shown without a
# network. Overriding ftp AFTER requiring the package replaces the real calls.

namespace eval ::ftp {}
proc ::ftp::Open {host user pass args} { return 1 }
proc ::ftp::Close {c} { return }
proc ::ftp::Cd {c path} { return 1 }
proc ::ftp::Pwd {c} { return "/" }
proc ::ftp::List {c path} {
    return {
        "drwxr-xr-x 2 u g 4096 Jan 01 12:00 incoming"
        "-rw-r--r-- 1 u g 8192 Jan 01 12:00 welcome.txt"
        "-rw-r--r-- 1 u g 4096 Jan 01 12:00 index.html"
    }
}
proc ::ftp::FileSize {c path} { return 8192 }

set p [::tclutils::tuprovider open ftp ftp://ftp.example.org/pub]

puts "Capabilities of ftp: [lsort [$p caps]]"
puts "  (list/stat/get/put/delete/mkdir/move -- no copy, honestly reported)"
puts ""
puts "list /pub (dirs and files parsed from the LIST output):"
foreach e [$p list /pub] {
    puts [format "  %-4s %s  (%s bytes)" [dict get $e type] [dict get $e name] [dict get $e size]]
}
