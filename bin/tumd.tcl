#!/usr/bin/env tclsh
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::tumd 0.1
proc usage {} {
    puts stderr "usage: tumd html        ?file.md?   (Markdown -> HTML; stdin if no file)"
    puts stderr "       tumd toc         ?file.md?   (Markdown table-of-contents)"
    puts stderr "       tumd headings    ?file.md?   (level<TAB>text per heading)"
    puts stderr "       tumd frontmatter ?file.md?   (print the YAML front matter)"
    exit 2
}
if {[llength $argv] < 1} usage
set cmd [lindex $argv 0]
set file [lindex $argv 1]
if {$file ne ""} {
    set fh [open $file r]
    fconfigure $fh -encoding utf-8
    set md [read $fh]
    close $fh
} else {
    fconfigure stdin -encoding utf-8
    set md [read stdin]
}
switch -- $cmd {
    html { puts [::tclutils::tumd::toHtml $md] }
    toc  { puts [::tclutils::tumd::toc $md] }
    headings {
        foreach hd [::tclutils::tumd::headings $md] {
            puts "[lindex $hd 0]\t[lindex $hd 1]"
        }
    }
    frontmatter { puts [lindex [::tclutils::tumd::frontmatter $md] 0] }
    default usage
}
