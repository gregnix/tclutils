#!/usr/bin/env tclsh
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::tujson 0.1

proc usage {} {
    puts stderr "usage: tujson validate ?file.json?"
    puts stderr "       tujson minify   ?file.json?"
    puts stderr "       tujson pretty   ?file.json?"
    puts stderr "       tujson parse    ?file.json?"
    puts stderr "If file is omitted, JSON is read from stdin."
    exit 2
}

proc readInput {file} {
    if {$file eq ""} {
        fconfigure stdin -encoding utf-8
        return [read stdin]
    }
    set fh [open $file r]
    fconfigure $fh -encoding utf-8
    try {
        return [read $fh]
    } finally {
        close $fh
    }
}

if {[llength $argv] < 1 || [llength $argv] > 2} usage
set cmd [lindex $argv 0]
set file [lindex $argv 1]
set json [readInput $file]

switch -- $cmd {
    validate {
        ::tclutils::tujson::validate $json
        puts valid
    }
    minify {
        puts [::tclutils::tujson::minify $json]
    }
    pretty {
        puts [::tclutils::tujson::pretty $json]
    }
    parse {
        puts [::tclutils::tujson::parse $json]
    }
    default usage
}
