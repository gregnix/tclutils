# tclutils::tuprovider -- storage provider interface for the Explorer framework.
# Description: storage provider interface: one API over local files, ZIP, WebDAV, FTP and SFTP
# Category: Archive · filesystem
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
# The local provider adds (0.4):
#
#     hidden  1 if the system hides the entry: on Windows the "hidden"
#             attribute (a leading dot means nothing there), elsewhere a
#             leading dot
#     system  1 for the Windows "system" attribute, else 0
#
# A consumer that finds no "hidden" key falls back to the leading dot.
#
# A provider is an object (tcloo). `tuprovider::open <scheme> ?args?` returns
# one; the Explorer talks to it by method. This mirrors tudav's client model
# (a handle you pass around) rather than a global.

package require Tcl 8.6-
package require TclOO
package require tclutils::common 0.3

namespace eval ::tclutils::tuprovider {
    namespace export open register schemes hiddenFlags localNames
    namespace ensemble create

    # scheme name -> class command
    variable registry {}
    # test hook for hiddenFlags: "" = detect; else unix | windows
    variable platform ""
}

# localNames dir -> every entry of a local directory, once, without . and ..
# "*" alone misses what the system hides: on Windows files with the hidden
# attribute, elsewhere dot names. "-types hidden *" adds exactly those. On
# Windows "*" already matches dot names, so "* .*" (up to 0.4 of 2026-11-13)
# listed them twice and still missed hidden files (found 2026-11-14 on
# Windows 10.0.26300).
proc ::tclutils::tuprovider::localNames {dir} {
    set seen [dict create]
    set out {}
    foreach f [concat [glob -nocomplain -directory $dir -- *] \
                      [glob -nocomplain -directory $dir -types hidden -- *]] {
        set leaf [file tail $f]
        if {$leaf in {. ..} || [dict exists $seen $leaf]} continue
        dict set seen $leaf 1
        lappend out $f
    }
    return $out
}

# hiddenFlags path leaf -> {hidden system} for a local file system entry. On
# Windows the attributes decide, as in the Explorer and the system file
# dialog; elsewhere the leading dot. An attribute that cannot be read counts
# as not set (0.4).
proc ::tclutils::tuprovider::hiddenFlags {path leaf} {
    variable platform
    set p [expr {$platform ne "" ? $platform : $::tcl_platform(platform)}]
    if {$p eq "windows"} {
        set hidden 0
        set system 0
        catch {set hidden [file attributes $path -hidden]}
        catch {set system [file attributes $path -system]}
        return [list [expr {$hidden ? 1 : 0}] [expr {$system ? 1 : 0}]]
    }
    return [list [string match .* $leaf] 0]
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
        foreach f [::tclutils::tuprovider::localNames $path] {
            lappend out [my _localEntry $f [file tail $f]]
        }
        return $out
    }

    # One entry with hidden/system (0.4). size and mtime stay "" when they
    # cannot be read -- a dangling symbolic link made the whole listing fail
    # up to 0.3.
    method _localEntry {f leaf} {
        set type [expr {[file isdirectory $f] ? "dir" : "file"}]
        set size ""
        set mtime ""
        if {$type eq "file"} { catch {set size [file size $f]} }
        catch {set mtime [file mtime $f]}
        set e [my _entry $leaf $f $type $size $mtime]
        lassign [::tclutils::tuprovider::hiddenFlags $f $leaf] hidden system
        dict set e hidden $hidden
        dict set e system $system
        return $e
    }

    method stat {path} {
        if {![file exists $path] && [catch {file lstat $path lst}]} { error "no such path: $path" }
        return [my _localEntry $path [file tail $path]]
    }

    method get    {path}      { return [::tclutils::common::readBinaryFile $path] }
    method head   {path len}  {
        set fh [open $path rb]
        try {
            return [if {$len > 0} {read $fh $len} else {read $fh}]
        } finally {
            close $fh
        }
    }
    # temp file + rename: a failed put leaves the old file (0.3)
    method put    {path data} { ::tclutils::common::replaceFile $path $data -encoding binary; return }
    method delete {path}      { file delete -force -- $path }
    method mkdir  {path}      { file mkdir $path }
    method move   {from to}   { file rename -- $from $to }
    method copy   {from to}   { file copy -- $from $to }
}

# Register the built-in local provider.
::tclutils::tuprovider::register local ::tclutils::tuprovider::Local

package provide tclutils::tuprovider 0.4
