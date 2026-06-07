# Add the sibling lib/tm tree to the module path so bin/*.tcl run from a checkout.
tcl::tm::path add [file normalize [file join [file dirname [info script]] .. lib tm]]
