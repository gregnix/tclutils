# tclutils::tuprovider -- storage provider interface for the Explorer framework.
#
# One abstraction over every storage back end: local filesystem, ZIP, WebDAV,
# FTP, ... For a consumer (the directory tree, the file list) everything is
# just a path with children -- where the bytes actually live does not matter.
#
# The interface is deliberately small. It is the set of operations that both
# the local `file` command and the existing tudav WebDAV client already
# support, and no more:
#
#     list    path            -> list of entry dicts (one level, on demand)
#     stat    path            -> one entry dict, or error if absent
#     get     path            -> file contents (bytes)
#     put     path data       -> write contents
#     delete  path            -> remove
#     mkdir   path            -> create a collection/directory
#     move    from to         -> rename/move within the provider
#     copy    from to         -> copy within the provider
#     caps                    -> which of the above are actually supported
#
# An entry dict has these keys (a directory listing is a list of them):
#
#     name    display name (leaf, no path)
#     path    provider path to this entry
#     type    file | dir     (a "collection" in WebDAV terms is a dir)
#     size    bytes, or "" if unknown
#     mtime   epoch seconds, or "" if unknown
#
# Providers may add keys (etag, contenttype, mode, ...); consumers ignore
# unknown keys. name/path/type are mandatory; size/mtime are best-effort so
# a remote provider need not pay for a stat per entry.
#
# A provider is an object (tcloo). `tuprovider::open <scheme> ?args?` returns
# one; the Explorer talks to it by method. This mirrors tudav's client model
# (a handle you pass around) rather than a global.

package require Tcl 8.6-
package require TclOO

namespace eval ::tclutils::tuprovider {
    namespace export open register schemes
    namespace ensemble create

    # scheme name -> class command
    variable registry {}
}

# Register a provider class under a scheme name ("local", "zip", "dav", ...).
proc ::tclutils::tuprovider::register {scheme class} {
    variable registry
    dict set registry $scheme $class
    return
}

proc ::tclutils::tuprovider::schemes {} {
    variable registry
    return [dict keys $registry]
}

# Open a provider for a scheme. Extra args go to the class constructor.
proc ::tclutils::tuprovider::open {scheme args} {
    variable registry
    if {![dict exists $registry $scheme]} {
        error "tuprovider: unknown scheme '$scheme' (have: [schemes])"
    }
    return [[dict get $registry $scheme] new {*}$args]
}

# --------------------------------------------------------------------------
# Base class. Concrete providers inherit and override. The base defines the
# contract and gives every method a default that says "not supported", so a
# read-only provider simply does not override the writing methods and `caps`
# reports the truth automatically.
# --------------------------------------------------------------------------
oo::class create ::tclutils::tuprovider::Base {

    # Which operations this provider really supports. Derived from which
    # methods are overridden away from the base "unsupported" stubs.
    #
    # Convention for read-only providers: inherit from Base (not from a full
    # provider like Local) and implement only list/stat/get. Then caps reports
    # the truth automatically. Taking a capability *away* by overriding it in a
    # subclass is deliberately not supported -- build read-only providers from
    # Base up, not by subtracting from a writable one.
    method caps {} {
        set out {}
        foreach op {list stat get put delete mkdir move copy} {
            if {[my _supported $op]} { lappend out $op }
        }
        return $out
    }

    # A method counts as supported if any class other than Base contributes
    # an implementation to its resolution chain. This is robust across
    # arbitrary inheritance depth: a provider that inherits from Local (and
    # thus gets Local's `list`) reports `list` as supported, because Local --
    # not Base -- defines it. `info object call` returns the resolution chain
    # as {method NAME DEFININGCLASS TYPE} frames.
    method _supported {op} {
        foreach frame [info object call [self] $op] {
            lassign $frame kind name locus type
            if {$kind eq "method" && $locus ne "::tclutils::tuprovider::Base"} {
                return 1
            }
        }
        return 0
    }

    # ---- contract; concrete providers override what they can ----
    method list   {path}        { my _nope list }
    method stat   {path}        { my _nope stat }
    method get    {path}        { my _nope get }
    # head: return at most len bytes from the start of a file. Default reads the
    # whole file via get and truncates; providers that can read a prefix cheaply
    # (Local) override this. Lets a UI preview a large binary without loading it
    # all. len<=0 means "no limit" (same as get).
    method head   {path len}    {
        set d [my get $path]
        if {$len > 0 && [string length $d] > $len} { return [string range $d 0 [expr {$len-1}]] }
        return $d
    }
    method put    {path data}   { my _nope put }
    method delete {path}        { my _nope delete }
    method mkdir  {path}        { my _nope mkdir }
    method move   {from to}     { my _nope move }
    method copy   {from to}     { my _nope copy }

    method _nope {op} {
        error "provider [info object class [self]] does not support '$op'"
    }

    # Small helper so providers build entry dicts uniformly.
    method _entry {name path type {size ""} {mtime ""}} {
        return [dict create name $name path $path type $type \
                            size $size mtime $mtime]
    }
}

# --------------------------------------------------------------------------
# The local filesystem provider -- the reference implementation, and the one
# that replaces the hardwired glob/file calls in tkufiletree::_populate.
# --------------------------------------------------------------------------
oo::class create ::tclutils::tuprovider::Local {
    superclass ::tclutils::tuprovider::Base

    method list {path} {
        set out {}
        foreach f [glob -nocomplain -directory $path -- * .*] {
            set leaf [file tail $f]
            if {$leaf in {. ..}} continue
            set type [expr {[file isdirectory $f] ? "dir" : "file"}]
            set size [expr {$type eq "file" ? [file size $f] : ""}]
            lappend out [my _entry $leaf $f $type $size [file mtime $f]]
        }
        return $out
    }

    method stat {path} {
        if {![file exists $path]} { error "no such path: $path" }
        set type [expr {[file isdirectory $path] ? "dir" : "file"}]
        set size [expr {$type eq "file" ? [file size $path] : ""}]
        return [my _entry [file tail $path] $path $type $size [file mtime $path]]
    }

    method get    {path}      { set fh [open $path rb]; set d [read $fh]; close $fh; return $d }
    method head   {path len}  {
        set fh [open $path rb]
        set d [expr {$len > 0 ? [read $fh $len] : [read $fh]}]
        close $fh ; return $d
    }
    method put    {path data} { set fh [open $path wb]; puts -nonewline $fh $data; close $fh }
    method delete {path}      { file delete -force -- $path }
    method mkdir  {path}      { file mkdir $path }
    method move   {from to}   { file rename -- $from $to }
    method copy   {from to}   { file copy -- $from $to }
}

# Register the built-in local provider.
::tclutils::tuprovider::register local ::tclutils::tuprovider::Local

package provide tclutils::tuprovider 0.1
