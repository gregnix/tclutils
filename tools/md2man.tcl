#!/usr/bin/env tclsh
# ============================================================
# md2man.tcl -- generate man pages (man/mann/<mod>.n) from docs/<mod>.md
# so doc and man are maintained ONCE (in Markdown).
#
# Uses the docir pipeline:  mdstack::parser -> docir::md::fromAst -> docir::roff
# docir + mdstack are located as sibling repos (or via $DOCIR_DIR). The script
# is repo-agnostic: drop it into tools/ of tclutils OR tkutils and run.
#
# Usage:
#   tclsh tools/md2man.tcl                 # docs/<mod>.md -> man/mann/<mod>.n
#                                          # (only docs that match a module .tm)
#   tclsh tools/md2man.tcl -all            # convert every docs/*.md
#   tclsh tools/md2man.tcl docs/foo.md     # one file -> man/mann/foo.n
#   tclsh tools/md2man.tcl <indir> <outdir>
#
# Section (man/mann/*.n vs man/man1/*.1):
#   default n (Tcl library/command API). A CLI tool's doc can declare
#     ---\n  section: 1\n  ---   (YAML frontmatter)  -> man/man1/<mod>.1
#   or force with  -section 1.
#   DOCIR_DIR=/path/to/docir tclsh tools/md2man.tcl
#
# The .TH line is filled as:  .TH <mod> n <version> <repo>
# (version read from lib/tm/<repo>/<mod>-X.Y.tm when present).
# ============================================================

package require Tcl 8.6-

set scriptDir [file dirname [file normalize [info script]]]
set repoRoot  [file dirname $scriptDir]
set repo      [file tail $repoRoot]

# ---- locate docir (+ mdstack) and load the pipeline ------------------------
proc locateDocir {repoRoot} {
    set cands {}
    if {[info exists ::env(DOCIR_DIR)]} { lappend cands $::env(DOCIR_DIR) }
    lappend cands \
        [file join $repoRoot .. docir] \
        [file join $repoRoot .. .. docir]
    if {[info exists ::env(HOME)]} { lappend cands [file join $::env(HOME) lib tcltk docir] }
    foreach c $cands {
        if {[file isfile [file join $c lib repos-path.tcl]]} { return [file normalize $c] }
    }
    return ""
}

set docir [locateDocir $repoRoot]
if {$docir eq ""} {
    puts stderr "error: docir not found. Set DOCIR_DIR or place docir as a sibling repo."
    exit 2
}
source [file join $docir lib repos-path.tcl]
::docir::reposPath::add
catch {tcl::tm::path add [file join $docir lib tm]}
foreach pkg {mdstack::parser docir docir::mdSource docir::roff} {
    if {[catch {package require $pkg} err]} {
        puts stderr "error: cannot load $pkg ($err)\n  (docir=$docir; needs mdstack as a sibling too)"
        exit 2
    }
}

# ---- helpers ---------------------------------------------------------------
proc readFile {p} { set f [open $p r]; fconfigure $f -encoding utf-8; set d [read $f]; close $f; return $d }
proc writeFile {p s} { file mkdir [file dirname $p]; set f [open $p w]; fconfigure $f -encoding utf-8; puts -nonewline $f $s; close $f }
# read a key from a leading YAML frontmatter block (--- ... ---), else ""
proc frontmatterKey {mdText key} {
    if {![regexp -- {\A---\s*\n(.*?)\n---\s*\n} $mdText -> fm]} { return "" }
    if {[regexp -line -- "^${key}:\\s*(\\S.*?)\\s*\$" $fm -> val]} { return $val }
    return ""
}
proc frontmatterSection {mdText} { return [frontmatterKey $mdText section] }

# module version from lib/tm/<repo>/<mod>-X.Y.tm (highest), else ""
proc moduleVersion {repoRoot repo mod} {
    set vers {}
    foreach f [glob -nocomplain [file join $repoRoot lib tm $repo $mod-*.tm]] {
        if {[regexp -- {-([0-9]+\.[0-9]+(?:\.[0-9]+)?)\.tm$} [file tail $f] -> v]} { lappend vers $v }
    }
    if {[llength $vers] == 0} { return "" }
    return [lindex [lsort -decreasing -dictionary $vers] 0]
}

proc moduleExists {repoRoot repo mod} {
    return [expr {[llength [glob -nocomplain [file join $repoRoot lib tm $repo $mod-*.tm]]] > 0}]
}

# md -> roff(.n), with a proper .TH injected
proc mdToMan {mdText name section version part} {
    set ast [mdstack::parser::parse $mdText]
    set ir  [docir::md::fromAst $ast]
    # set/overwrite the doc_header meta so roff emits .TH name section version part
    set done 0
    set out {}
    foreach node $ir {
        if {!$done && [dict exists $node type] && [dict get $node type] eq "doc_header"} {
            dict set node meta [dict create name $name section $section version $version part $part]
            set done 1
        }
        lappend out $node
    }
    if {!$done} {
        set hdr [dict create type doc_header content {} \
            meta [dict create name $name section $section version $version part $part]]
        set out [linsert $out 0 $hdr]
    }
    return [docir::roff::render $out]
}

# ---- argument handling -----------------------------------------------------
set all 0
set forcedSection ""
set positional {}
for {set i 0} {$i < [llength $argv]} {incr i} {
    set a [lindex $argv $i]
    switch -- $a {
        -all { set all 1 }
        -section { incr i; set forcedSection [lindex $argv $i] }
        -h - -help { puts "usage: md2man.tcl \[-all\] \[-section n|1\] \[indir|file.md\] \[outdir\]"; exit 0 }
        default { lappend positional $a }
    }
}

set inArg  [lindex $positional 0]
set outArg [lindex $positional 1]

# build the list of md files
set mdFiles {}
if {$inArg ne "" && [file isfile $inArg]} {
    set mdFiles [list $inArg]
    set all 1   ;# explicit single file: always convert
} else {
    set inDir [expr {$inArg ne "" ? $inArg : [file join $repoRoot docs]}]
    set mdFiles [lsort [glob -nocomplain [file join $inDir *.md]]]
}

if {[llength $mdFiles] == 0} { puts "no .md files found"; exit 0 }

puts "md2man: $repo   docir=$docir"
    puts "mode:   [expr {$all ? "all docs" : "module docs only"}]   (section via -section/frontmatter, default n)"
puts [string repeat - 60]
set n 0; set skipped 0
foreach md $mdFiles {
    set mod [file rootname [file tail $md]]
    if {!$all && ![moduleExists $repoRoot $repo $mod]} { incr skipped; continue }
    set mdText [readFile $md]
    set ver [moduleVersion $repoRoot $repo $mod]
    if {$ver eq ""} { set ver [frontmatterKey $mdText version] }
    # section: -section flag wins, else frontmatter "section:", else "n"
    set section $forcedSection
    if {$section eq ""} { set section [frontmatterSection $mdText] }
    if {$section eq ""} { set section n }
    if {[catch {set roff [mdToMan $mdText $mod $section $ver $repo]} err]} {
        puts [format "  %-22s FAIL: %s" $mod $err]; continue
    }
    # man/mann for section n, man/man1 for section 1, etc.; explicit outdir wins
    set targetDir [expr {$outArg ne "" ? $outArg : [file join $repoRoot man man$section]}]
    set outFile [file join $targetDir $mod.$section]
    writeFile $outFile $roff
    puts [format "  %-22s -> %s  (.TH %s %s %s %s)" \
        $mod [file join man man$section $mod.$section] $mod $section $ver $repo]
    incr n
}
puts [string repeat - 60]
puts "wrote $n man page(s); skipped $skipped non-module doc(s)."
