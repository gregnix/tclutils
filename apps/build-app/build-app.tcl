#!/usr/bin/env tclsh
# build-app.tcl -- turn a tclutils/tkutils app into a standalone Tcl 9 zipkit.
#
# MUST be run BY the target basekit, e.g.:
#     ./zipkit-9_0.4-Linux64-intel-tcl  tools/build-app.tcl -kind cli ...
#     ./zipkit-9_0.4-Linux64-intel-tk   tools/build-app.tcl -kind gui ...
# so that the standard library it bundles ([info library] / $tk_library) matches
# the basekit exactly. All the heavy lifting is in tclutils::tuzipfs; this script
# only assembles the VFS, writes main.tcl, and (optionally) probes the app's real
# runtime dependency closure to bundle any external (non-tm) packages.
#
# Options:
#   -out FILE          output executable                                 (required)
#   -basekit FILE      static Tcl/Tk 9 basekit template                  (required)
#   -kind cli|gui      console app (tclsh basekit) or GUI app (wish)      (required)
#   -app DIR           the app's source directory                        (required)
#   -main FILE         entry script (relative to -app, or absolute)      (required)
#   -launch CODE       Tcl to start the app (e.g. {::notesapp::buildApp .});
#                      omit for scripts that run at source time (CLI)
#   -bootstrap none|tkutils   emit _lib/paths.tcl shim for the app family (default:
#                      tkutils when -app is given and -main runs via source)
#   -tm DIR            module tm tree to bundle (repeatable)
#   -include SRC[=DEST] copy extra content into the VFS at DEST (default: SRC's
#                      basename); for shared code an app sources from a sibling
#                      directory, or data files/icons (repeatable)
#   -extlib DIR        external pkgIndex search root for the prober (repeatable)
#   -probe 0|1         probe the real dependency closure (default: 1 for gui)
#   -manifest FILE     bundle exactly the packages listed in FILE (no probing,
#                      no display needed) -- reproducible builds
#   -writemanifest FILE  run the prober AND write the found closure to FILE
#   -stdlibfrom running|DIR   stdlib source; DIR = mounted foreign basekit
#                      (cross-platform builds); default: running interpreter
#   -keep 0|1          keep the temporary VFS dir for inspection (default 0)

package require Tcl 8.6-

# --- locate tclutils::tuzipfs -------------------------------------------------
# Prefer an explicit -tm on the command line; otherwise fall back to a repo-
# relative lib/tm and finally the interpreter's own tm path.
proc findTuzipfs {argv} {
    foreach {k v} $argv {
        if {$k eq "-tm"} { tcl::tm::path add $v }
    }
    set here [file dirname [file normalize [info script]]]
    set cands [list \
        [file join $here .. lib tm] \
        [file join $here .. .. lib tm] \
        [file join $here lib tm]]
    # when build-app itself runs as a zipkit, tuzipfs is bundled here:
    if {[llength [info commands ::zipfs]]} {
        lappend cands [file join [zipfs root] app lib tm]
    }
    foreach cand $cands {
        if {[file isdirectory $cand]} { tcl::tm::path add $cand }
    }
    if {[catch {package require tclutils::tuzipfs 0.2}]} {
        # allow 0.1+ presence check to give a clearer message
        catch {package require tclutils::tuzipfs}
    }
}

# --- tiny option parser (repeatable -tm / -extlib) ----------------------------
proc parseArgs {argv} {
    set opt(-out) ""; set opt(-basekit) ""; set opt(-kind) ""
    set opt(-app) ""; set opt(-main) ""; set opt(-launch) ""
    set opt(-bootstrap) ""; set opt(-probe) ""; set opt(-stdlibfrom) basekit
    set opt(-keep) 0; set opt(-manifest) ""; set opt(-writemanifest) ""
    set opt(-tm) {}; set opt(-extlib) {}; set opt(-include) {}
    if {[llength $argv] % 2} { die "each option needs a value" }
    foreach {k v} $argv {
        switch -- $k {
            -tm      { lappend opt(-tm) $v }
            -extlib  { lappend opt(-extlib) $v }
            -include { lappend opt(-include) $v }
            -out - -basekit - -kind - -app - -main - -launch -
            -bootstrap - -probe - -stdlibfrom - -keep -
            -manifest - -writemanifest { set opt($k) $v }
            default  { die "unknown option \"$k\"" }
        }
    }
    return [array get opt]
}

proc die {msg} { puts stderr "build-app: $msg"; exit 2 }
proc truthy {v} { expr {$v ne "" && [string tolower $v] ni {0 no false off}} }

# --- dependency-closure prober ------------------------------------------------
# Runs the app in a CHILD instance of the basekit (this very executable), with
# the module trees on the tm path and the extlib roots on auto_path, then reports
# every EXTERNAL package that actually loaded (not stdlib, not tclutils/tkutils).
# Returns a list of install directories to bundle.
proc probeExternalDirs {opt} {
    upvar 1 $opt o
    set probe [file join [tempDir] probe-[pid].tcl]
    set fh [open $probe w]
    puts $fh {
        lassign $argv entry launch tmList extList
        foreach d $tmList  { tcl::tm::path add $d }
        foreach d $extList { lappend auto_path $d }
        catch { package require Tk }
        namespace eval ::tkupaths { proc add args {} }
        catch { source $entry }
        if {$launch ne ""} { catch { uplevel #0 $launch } }
        catch { update }
        foreach p [lsort [package names]] {
            if {[catch {package present $p} v]} continue
            if {[regexp {^(Tcl|Tk|Ttk|ttk|tcl|tk|msgcat|http|tcl::)} $p]} continue
            if {[regexp {^(tclutils|tkutils)} $p]} continue
            set ifn [package ifneeded $p $v]
            set dir ""
            if {[regexp {([/A-Za-z]:?[^ \}\]]*/)[^/ \}\]]+\.(tcl|tm|so|dll|dylib)} $ifn -> d]} {
                set dir [string trimright $d /]
            }
            puts "EXT\t$p\t$v\t$dir"
        }
        exit 0
    }
    close $fh
    # run the probe under the TARGET basekit (it has Tk for GUI apps), not the
    # builder's own executable (which may be a Tk-less tcl basekit). Normalize
    # to an absolute path -- exec does not search the current directory, so a
    # bare "-basekit basekit-tk" would otherwise fail silently.
    set self [file normalize $o(-basekit)]
    set entry [file join $o(-app) $o(-main)]
    set res {}
    set failed 0
    if {[catch {
        exec $self $probe $entry $o(-launch) $o(-tm) $o(-extlib) 2>@ stderr
    } out]} {
        # exec returns child stdout in $out even on non-zero exit; but a real
        # launch failure (basekit not found, crash) leaves no EXT lines.
        set failed 1
    }
    if {![string match "*EXT\t*" $out]} {
        puts "  probe: no external packages detected\
              [expr {$failed ? {(probe run failed -- check -basekit path)} : {}}]"
    }
    set roots {}
    set seen {}
    foreach line [split $out \n] {
        if {![string match "EXT\t*" $line]} continue
        lassign [split $line \t] _ p v dir
        if {$dir eq "" || ![file isdirectory $dir]} {
            # meta-package with no file path (e.g. an alias registered by another
            # package's pkgIndex) -- its root is bundled via that sibling package.
            puts "  probe: external package $p $v -- no own path (covered by another bundle)"
            continue
        }
        # reduce to the install root: the package directory directly under an
        # -extlib root, so a file deep in the tree (…/scripts/utils) still maps
        # to the package root (…/tablelist7.11) and is bundled exactly once.
        set root [installRoot $dir $o(-extlib)]
        if {$root eq ""} { set root $dir }
        if {![dict exists $seen $root]} {
            dict set seen $root 1
            lappend roots [list $root "$p $v"]
            puts "  probe: external package $p $v  <- $root"
        }
    }
    file delete -force $probe
    return $roots
}

# The package's install root: <extlib>/<first component> for the first -extlib
# root that contains $path. Empty if $path is under none of them.
proc installRoot {path extlibs} {
    set path [file normalize $path]
    foreach ext $extlibs {
        set ext [file normalize $ext]
        set n [string length $ext]
        if {[string equal -length $n $path $ext] && [string index $path $n] eq "/"} {
            set rel [string range $path [expr {$n + 1}] end]
            set first [lindex [file split $rel] 0]
            if {$first ne ""} { return [file join $ext $first] }
        }
    }
    return ""
}

# --- manifest read/write ------------------------------------------------------
# A manifest records the external package install directories to bundle, by
# BASENAME (portable across machines with the same package layout). Lines are
# "<basename>  # optional note"; blank lines and "#" comments are ignored.

proc writeManifest {file rootsWithNotes} {
    set fh [open $file w]
    fconfigure $fh -encoding utf-8
    puts $fh "# build-app dependency manifest"
    puts $fh "# external package install directories, resolved under -extlib at build time"
    puts $fh "# regenerate: build-app -writemanifest <file> ...   use: build-app -manifest <file> ..."
    foreach pair $rootsWithNotes {
        lassign $pair root note
        puts $fh [format "%-24s # %s" [file tail $root] $note]
    }
    close $fh
    return $file
}

proc readManifest {file} {
    set fh [open $file r]
    fconfigure $fh -encoding utf-8
    set data [read $fh]
    close $fh
    set out {}
    foreach line [split $data \n] {
        set hash [string first # $line]
        if {$hash >= 0} { set line [string range $line 0 [expr {$hash - 1}]] }
        set line [string trim $line]
        if {$line ne ""} { lappend out [lindex $line 0] }
    }
    return $out
}

# Find the package directory named $base under the -extlib roots.
proc resolvePkgDir {base extlibs} {
    foreach ext $extlibs {
        set cand [file join $ext $base]
        if {[file isdirectory $cand]} { return $cand }
    }
    return ""
}

proc tempDir {} {
    set d [file join /tmp build-app-[pid]]
    file mkdir $d
    return $d
}

# --- main ---------------------------------------------------------------------
findTuzipfs $argv
if {![namespace exists ::tclutils::tuzipfs]} {
    die "tclutils::tuzipfs not found -- add its lib/tm via -tm or run in the repo"
}
namespace import ::tclutils::tuzipfs::rcopy

array set o [parseArgs $argv]
foreach req {-out -basekit -kind -app -main} {
    if {$o($req) eq ""} { die "$req is required" }
}
if {$o(-kind) ni {cli gui}} { die "-kind must be cli or gui" }
if {![file exists $o(-basekit)]} { die "basekit not found: $o(-basekit)" }
set entryPath [file join $o(-app) $o(-main)]
if {![file exists $entryPath]} { die "entry not found: $entryPath" }

# defaults keyed off -kind / -launch
if {$o(-probe) eq ""} { set o(-probe) [expr {$o(-kind) eq "gui"}] }
if {$o(-bootstrap) eq ""} {
    set o(-bootstrap) [expr {$o(-launch) ne "" ? "tkutils" : "none"}]
}

set vfs [file join [tempDir] [file rootname [file tail $o(-out)]].vfs]
file delete -force $vfs
file mkdir $vfs

# 1) stdlib (mkimg replaces the basekit's attached archive). By default the
#    stdlib is taken from the TARGET basekit itself -- mount it read-only and
#    copy tcl_library (+tk_library) out. This guarantees an exact version match
#    and makes cross-platform builds work with any builder (a headless tcl
#    basekit can build GUI/Windows targets). -stdlibfrom running|DIR override.
set sfrom $o(-stdlibfrom)
set wantTk [expr {$o(-kind) eq "gui"}]
if {$sfrom in {"" basekit}} {
    set mp [::tclutils::tuzipfs::mount $o(-basekit)]
    try {
        ::tclutils::tuzipfs::copyStdlib $vfs -tk $wantTk -from $mp
    } finally {
        ::tclutils::tuzipfs::unmount $mp
    }
} else {
    ::tclutils::tuzipfs::copyStdlib $vfs -tk $wantTk -from $sfrom
}

# 2) module tm trees
if {[llength $o(-tm)]} {
    file mkdir [file join $vfs lib tm]
    foreach d $o(-tm) {
        if {![file isdirectory $d]} { die "-tm dir not found: $d" }
        foreach e [glob -nocomplain -directory $d *] {
            rcopy $e [file join $vfs lib tm [file tail $e]]
        }
    }
}

# 3) external packages. Three ways to decide what to bundle under lib/pkgs:
#      -manifest FILE     read the list from FILE (no probing, no display needed)
#      -writemanifest F   run the prober AND write the found list to F
#      (default)          run the prober
#    A manifest is a plain list of install-directory basenames (one per line,
#    "#" comments allowed), resolved under the -extlib roots at build time. It is
#    the same closure the prober finds, just recorded so a build is reproducible
#    without running the app.
set extBundled 0
proc bundlePkgDir {vfs dir} {
    file mkdir [file join $vfs lib pkgs]
    rcopy $dir [file join $vfs lib pkgs [file tail $dir]]
}

if {$o(-manifest) ne ""} {
    # read mode: bundle exactly the directories named in the manifest
    foreach base [readManifest $o(-manifest)] {
        set dir [resolvePkgDir $base $o(-extlib)]
        if {$dir eq ""} { die "manifest: package dir \"$base\" not found under any -extlib root" }
        bundlePkgDir $vfs $dir
        set extBundled 1
        puts "  manifest: bundling $base  <- $dir"
    }
} elseif {[truthy $o(-probe)] && [llength $o(-extlib)]} {
    set found [probeExternalDirs o]
    foreach pair $found {
        bundlePkgDir $vfs [lindex $pair 0]
        set extBundled 1
    }
    if {$o(-writemanifest) ne ""} {
        writeManifest $o(-writemanifest) $found
        puts "  wrote manifest: $o(-writemanifest) ([llength $found] package dir(s))"
    }
}

# 4) application code + bootstrap shim + main.tcl
#
# First, process -include so we know which extra directories were bundled: a
# DEST that is (or lives under) a "pkgs" directory holds Tcl packages, and its
# pkgs root must go on auto_path or `package require` will not find them. build
# used to write the auto_path line only for prober/-manifest bundles, so manual
# `-include SRC=pkgs/Foo` copied the package but left it unreachable -- a silent
# trap that only surfaces at runtime with "can't find package Foo". We collect
# the pkgs roots here and emit auto_path entries for them below.
set extIncludeRoots {}
foreach spec $o(-include) {
    set eq [string first = $spec]
    if {$eq >= 0} {
        set src [string range $spec 0 [expr {$eq - 1}]]
        set dst [string range $spec [expr {$eq + 1}] end]
    } else {
        set src $spec
        set dst [file tail $spec]
    }
    if {![file exists $src]} { die "-include source not found: $src" }
    rcopy $src [file join $vfs $dst]
    # if DEST is <root>/pkgs/<pkg> or exactly <root>/pkgs, the auto_path root is
    # everything up to and including "pkgs".
    set parts [file split $dst]
    set pi [lsearch -exact $parts pkgs]
    if {$pi >= 0} {
        set root [file join {*}[lrange $parts 0 $pi]]
        if {$root ni $extIncludeRoots} { lappend extIncludeRoots $root }
    }
}
# auto_path lines to emit in the bootstrap: the extlib "lib/pkgs" (when the
# prober/-manifest bundled it) plus every pkgs root from -include.
set autoPathDirs {}
if {$extBundled} { lappend autoPathDirs //zipfs:/app/lib/pkgs }
foreach r $extIncludeRoots { lappend autoPathDirs //zipfs:/app/$r }

if {$o(-launch) eq "" && $o(-bootstrap) eq "none"} {
    # CLI-simple: the entry runs at source time -> it IS main.tcl
    file copy $entryPath [file join $vfs main.tcl]
} else {
    # App-family: app under app/, shim under _lib/, generated main.tcl at root
    file mkdir [file join $vfs app]
    foreach e [glob -nocomplain -directory $o(-app) *] {
        set tail [file tail $e]
        if {[string match *.test $tail] || $tail in {tests README.md LICENSE}} continue
        rcopy $e [file join $vfs app $tail]
    }
    if {$o(-bootstrap) eq "tkutils"} {
        file mkdir [file join $vfs _lib]
        set sh [open [file join $vfs _lib paths.tcl] w]
        puts $sh {# zipkit bootstrap shim: bundled modules live under //zipfs:/app/lib/tm}
        puts $sh {tcl::tm::path add //zipfs:/app/lib/tm}
        foreach d $autoPathDirs { puts $sh "lappend auto_path $d" }
        close $sh
    }
    set m [open [file join $vfs main.tcl] w]
    if {$o(-kind) eq "gui"} { puts $m {package require Tk} }
    puts $m {tcl::tm::path add //zipfs:/app/lib/tm}
    foreach d $autoPathDirs { puts $m "lappend auto_path $d" }
    puts $m "source //zipfs:/app/app/[file tail $o(-main)]"
    if {$o(-launch) ne ""} { puts $m $o(-launch) }
    if {$o(-kind) eq "gui"} {
        puts $m {if {[info exists env(SMOKE)]} { update; puts "SMOKE OK: children=[llength [winfo children .]] title=[wm title .]"; exit 0 }}
        puts $m {wm protocol . WM_DELETE_WINDOW {exit 0}}
        puts $m {vwait forever}
    }
    close $m
}

# 5) build the image
::tclutils::tuzipfs::mkimg $o(-out) $vfs -strip $vfs -basekit $o(-basekit)
catch {file attributes $o(-out) -permissions 0755}
puts "built: $o(-out) ([file size $o(-out)] bytes)"
if {[truthy $o(-keep)]} { puts "vfs kept: $vfs" } else { file delete -force $vfs }
