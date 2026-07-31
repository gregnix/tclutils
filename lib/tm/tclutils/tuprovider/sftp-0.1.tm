# tclutils::tuprovider::sftp -- SFTP provider, an adapter over the OpenSSH
# `sftp` client run in batch mode (`sftp -b`).
#
# Brings a remote SFTP server to the provider interface. Unlike the ftp provider
# (which wraps tcllib's ftp package), there is no pure-Tcl SFTP client, so this
# adapter shells out to the system `sftp` binary: each operation runs a small
# batch script and the output is parsed. That keeps the dependency to something
# every SSH install already has, and inherits OpenSSH's auth (keys, agent,
# known_hosts) instead of reimplementing it.
#
# Honest capabilities: sftp offers listing, get, put, delete (rm/rmdir), mkdir
# and rename (used for move), so this provider supports
# list/stat/get/put/delete/mkdir/move. It does NOT implement copy (SFTP has no
# server-side copy); copying is done at the application level with get+put, so
# `caps` reports copy as unsupported.
#
#   set p [tuprovider open sftp sftp://user@host/pub -identity ~/.ssh/id_ed25519]
#   $p list /pub      -> entries under /pub
#   $p caps           -> list stat get put delete mkdir move
#
# Options after the URL:
#   -identity FILE   ssh private key (-i)
#   -port N          port (overrides one in the URL)
#   -sshopt {...}    extra -o options passed to sftp, e.g.
#                    {StrictHostKeyChecking=accept-new}
#   -batchcmd CMD    override the sftp executable (default "sftp")
#
# Paths are absolute remote paths. name is derived from the path tail; the tree
# consumer treats them as opaque paths, exactly as it treats local paths.

package require Tcl 8.6-
package require TclOO
package require tclutils::tuprovider

oo::class create ::tclutils::tuprovider::Sftp {
    superclass ::tclutils::tuprovider::Base
    variable host user port base sshcmd identity sshopts

    constructor {url args} {
        set user "" ; set host "" ; set port 22 ; set base "/"
        # sftp://[user@]host[:port][/base]
        if {[regexp {^sftp://(?:([^@/]+)@)?([^/:]+)(?::(\d+))?(/.*)?$} \
                 $url -> u h p b]} {
            set user $u ; set host $h
            if {$p ne ""} { set port $p }
            if {$b ne ""} { set base $b }
        } else {
            set host $url
        }
        # parse options manually so -sshopt can be given more than once and all
        # occurrences are collected (array set would keep only the last one).
        set sshopts {} ; set identity "" ; set sshcmd sftp ; set optPort ""
        foreach {k v} $args {
            switch -- $k {
                -identity { set identity $v }
                -port     { set optPort $v }
                -batchcmd { set sshcmd $v }
                -sshopt   { lappend sshopts $v }
                default   { error "sftp provider: unknown option $k" }
            }
        }
        if {$optPort ne ""} { set port $optPort }
    }

    destructor { }

    # Derive a leaf name from a path ("/a/b/" -> "b", "/a/f.txt" -> "f.txt").
    method _name {path} {
        set p [string trimright $path /]
        if {$p eq ""} { return "/" }
        return [file tail $p]
    }

    method _entry {name path type size} {
        return [dict create name $name path $path type $type size $size]
    }

    # Build the sftp command prefix (binary + connection options), shared by all
    # operations. The remote target is user@host or just host.
    method _base {batchfile} {
        set cmd [list $sshcmd -b $batchfile -P $port]
        if {$identity ne ""} { lappend cmd -i $identity }
        foreach opt $sshopts { lappend cmd -o $opt }
        set target [expr {$user ne "" ? "$user@$host" : $host}]
        lappend cmd $target
        return $cmd
    }

    # Run an sftp batch script (text of sftp commands). Writes the script to a
    # temp batch file and runs `sftp -b FILE ...`, returning merged stdout+stderr.
    # Raises on a non-zero exit (real errors); callers that tolerate warnings use
    # _capture instead.
    method _run {script} {
        return [my _exec $script 1]
    }

    # Like _run but never raises on the exit code -- some sftp builds exit
    # non-zero on benign conditions. Returns whatever output was produced.
    method _capture {script} {
        return [my _exec $script 0]
    }

    method _exec {script raiseOnError} {
        set bf [my _tmp]
        set fh [open $bf w] ; puts $fh $script ; close $fh
        set cmd [my _base $bf]
        set rc [catch {exec {*}$cmd 2>@1} out]
        catch {file delete $bf}
        if {$rc && $raiseOnError} {
            return -code error "sftp failed: $out"
        }
        return $out
    }

    # list: run "ls -l PATH" over sftp and parse the Unix long listing.
    # sftp echoes an "sftp> " prompt per command on some builds; those lines are
    # skipped. The format is "perms links owner group size date name".
    method list {path} {
        set out {}
        set raw [my _capture "ls -l [my _q $path]\n"]
        foreach line [split $raw \n] {
            set line [string trim $line]
            if {$line eq ""} continue
            if {[string match "sftp>*" $line]} continue
            if {[string match "Couldn't*" $line] || [string match "*not found*" $line]} continue
            set fields [regexp -all -inline {\S+} $line]
            if {[llength $fields] < 9} continue
            set perms [lindex $fields 0]
            # a valid long-listing row starts with a perms string like drwxr-xr-x
            if {![regexp {^[-dl][-rwxsStT]{9}} $perms]} continue
            set size  [lindex $fields 4]
            set nameField [join [lrange $fields 8 end] " "]
            # strip a symlink "-> target" suffix if present
            if {[string index $perms 0] eq "l"} {
                set arrow [lsearch -exact $fields "->"]
                if {$arrow >= 0} { set nameField [join [lrange $fields 8 [expr {$arrow-1}]] " "] }
            }
            # sftp's `ls -l` prints the full path in the name column; reduce it
            # to the leaf, then build the child path under the listed directory.
            set name [file tail [string trimright $nameField /]]
            if {$name eq "." || $name eq ".."} continue
            if {$name eq ""} continue
            set type [expr {[string index $perms 0] eq "d" ? "dir" : "file"}]
            set child [expr {$path eq "/" ? "/$name" : "[string trimright $path /]/$name"}]
            lappend out [my _entry $name $child $type \
                             [expr {[string is integer -strict $size] ? $size : 0}]]
        }
        return $out
    }

    # stat: sftp's `ls` has no -d flag, so we cannot list "the path itself"
    # directly. Instead list the PARENT directory and find the matching entry.
    # For the root "/" (no parent), report it as a directory.
    method stat {path} {
        set path [string trimright $path /]
        if {$path eq ""} { return [my _entry "/" "/" dir 0] }
        set parent [file dirname $path]
        set leaf [file tail $path]
        foreach e [my list $parent] {
            if {[dict get $e name] eq $leaf} { return $e }
        }
        error "sftp: cannot stat $path"
    }

    # get: download to a temp file (sftp writes to a local path), read it back.
    method get {path} {
        set tmp [my _tmp]
        try {
            my _run "get [my _q $path] [my _q $tmp]\n"
            set fh [open $tmp rb] ; set data [read $fh] ; close $fh
            return $data
        } finally {
            catch {file delete $tmp}
        }
    }

    # head: download only works whole over plain sftp; the base default (get +
    # truncate) applies. Local disk temp keeps it off the wire twice.
    # (No override: inherit Base::head.)

    method put {path data} {
        set tmp [my _tmp]
        try {
            set fh [open $tmp wb] ; puts -nonewline $fh $data ; close $fh
            my _run "put [my _q $tmp] [my _q $path]\n"
        } finally {
            catch {file delete $tmp}
        }
    }

    method delete {path} {
        # try file remove first; if it is a directory, rmdir
        if {[catch {my _run "rm [my _q $path]\n"}]} {
            my _run "rmdir [my _q $path]\n"
        }
    }

    method mkdir {path} { my _run "mkdir [my _q $path]\n" }

    method move {from to} { my _run "rename [my _q $from] [my _q $to]\n" }

    # quote a remote path for an sftp batch line (sftp uses double quotes).
    method _q {p} { return \"$p\" }

    method _tmp {} {
        set dir [expr {[info exists ::env(TMPDIR)] ? $::env(TMPDIR) : "/tmp"}]
        return [file join $dir "sftp-[pid]-[clock clicks]"]
    }
}

::tclutils::tuprovider::register sftp ::tclutils::tuprovider::Sftp

package provide tclutils::tuprovider::sftp 0.1
