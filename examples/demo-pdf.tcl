source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tupdf
set tmp [file normalize [file join $::tclutils_example_dir .demo-pdf]]
file delete -force $tmp
file mkdir $tmp
set f [file join $tmp demo.pdf]
set ch [open $f w]
puts $ch {%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R >>
endobj
trailer
<< /Size 4 /Root 1 0 R >>
%%EOF}
close $ch
puts [::tclutils::tupdf::summary $f]
file delete -force $tmp
