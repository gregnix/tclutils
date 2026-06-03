source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tuurl
puts "encode -> [::tclutils::tuurl::encode {a b/c?x=1}]"
set q [::tclutils::tuurl::buildQuery [dict create q "hello world" lang de]]
puts "query  -> $q"
puts "parse  -> [::tclutils::tuurl::parseQuery $q]"
