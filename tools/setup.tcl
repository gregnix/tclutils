# setup.tcl -- macht die tclutils/tkutils-Libraries fuer Tcl auffindbar.
#
# Diese Datei darf an zwei Stellen liegen:
#   a) direkt im Verzeichnis, das die Library-Ordner enthaelt, z. B.
#        ~/lib/tcltk/setup.tcl   neben   tclutils-0.28.0/  tkutils-0.4.0/
#   b) innerhalb einer Library, z. B.
#        ~/lib/tcltk/tclutils-0.28.0/tools/setup.tcl
#
# In beiden Faellen wird das Wurzelverzeichnis mit den Library-Ordnern gesucht,
# indem von DIESER Datei aus nach oben gegangen wird, bis tclutils-* / tkutils-*
# gefunden werden. Es werden keine absoluten Pfade fest verdrahtet.
#
# Benutzung in der eigenen App:
#   source /pfad/zu/setup.tcl
#   package require tclutils::tubin
#   package require tkutils::tkcsv

apply {{} {
    # Startpunkt: Verzeichnis dieser Datei. Nach oben laufen, bis ein
    # Verzeichnis gefunden wird, das tclutils-* oder tkutils-* enthaelt.
    set dir [file dirname [file normalize [info script]]]
    set base $dir
    for {set i 0} {$i < 6} {incr i} {
        if {[llength [glob -nocomplain -directory $dir -type d tclutils-* tkutils-*]] > 0} {
            set base $dir
            break
        }
        set parent [file dirname $dir]
        if {$parent eq $dir} break
        set dir $parent
    }

    foreach lib {tclutils tkutils} {
        foreach d [lsort -decreasing -dictionary \
                [glob -nocomplain -directory $base -type d ${lib}-*]] {
            set tm [file join $d lib tm]
            if {[file isdirectory $tm]} {
                tcl::tm::path add $tm
                break   ;# nur die hoechste Version pro Library
            }
        }
    }
}}
