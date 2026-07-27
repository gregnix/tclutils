# tclutils::tuprovider::dav -- WebDAV provider, a thin adapter over tudav.
#
# Brings the existing tudav WebDAV client to the provider interface. It is an
# adapter, not a reimplementation: every method forwards to tudav.
#
# Honest capabilities: tudav offers list / stat / get / put / delete, so this
# provider supports exactly those. It does NOT implement mkdir/move/copy,
# because tudav has no public MKCOL/MOVE/COPY -- so `caps` reports them as
# unsupported (following the read-only-from-Base convention: implement only
# what the backend can actually do).
#
#   set p [tuprovider open dav https://host/dav -user u -password s]
#   $p list /            -> entries under the DAV root
#   $p caps              -> list stat get put delete
#
# Paths are DAV hrefs, relative to the client URL. name is derived from the
# href tail; the tree consumer treats them as opaque paths, exactly as it
# treats local paths.

package require Tcl 8.6-
package require TclOO
package require tclutils::tuprovider
package require tclutils::tudav

oo::class create ::tclutils::tuprovider::Dav {
    superclass ::tclutils::tuprovider::Base
    variable client

    # url plus tudav client options (-user, -password, -headers)
    constructor {url args} {
        set client [::tclutils::tudav::client $url {*}$args]
    }

    destructor {
        catch {::tclutils::tudav::destroy $client}
    }

    # Derive a leaf name from a DAV href ("/a/b/" -> "b", "/a/f.txt" -> "f.txt").
    method _name {href} {
        set h [string trimright $href /]
        set n [lindex [split $h /] end]
        # percent-decoding kept minimal; hrefs are usually already clean
        return $n
    }

    method list {path} {
        set out {}
        # collections = directories
        foreach c [::tclutils::tudav::listCollections $client -path $path] {
            set href [dict get $c href]
            lappend out [my _entry [my _name $href] $href dir]
        }
        # resources = files
        foreach r [::tclutils::tudav::listResources $client -path $path] {
            set href [dict get $r href]
            set e [my _entry [my _name $href] $href file]
            # pass through extra keys the consumer may use, but ignore if not
            if {[dict exists $r contenttype]} {
                dict set e contenttype [dict get $r contenttype]
            }
            lappend out $e
        }
        return $out
    }

    method stat {path} {
        # A cheap existence/type check via a depth-0 propfind. tudav's
        # getProperties returns properties; we use listCollections on the
        # parent is overkill, so probe the path itself.
        if {[catch {::tclutils::tudav::getProperties $client -path $path} props]} {
            error "no such path: $path"
        }
        # getProperties does not itself say collection-or-not reliably across
        # servers; fall back to name only. Type "file" unless a trailing slash
        # marks a collection.
        set type [expr {[string index $path end] eq "/" ? "dir" : "file"}]
        return [my _entry [my _name $path] $path $type]
    }

    method get    {path}      { return [::tclutils::tudav::get $client $path] }
    method put    {path data} { ::tclutils::tudav::put $client $path $data ; return }
    method delete {path}      { ::tclutils::tudav::delete $client $path ; return }
    # mkdir/move/copy deliberately not implemented -- tudav has no public
    # MKCOL/MOVE/COPY. caps() reports them as unsupported.
}

::tclutils::tuprovider::register dav ::tclutils::tuprovider::Dav

package provide tclutils::tuprovider::dav 0.1
