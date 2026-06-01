source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tumd
set md {---
title: Demo
---
# Demo

A **small** Markdown document with [a link](https://example.invalid).

## Code

```tcl
puts hello
```
}
puts "HTML:"
puts [::tclutils::tumd::toHtml $md]
puts "\nTOC:"
puts [::tclutils::tumd::toc $md]
puts "\nFrontmatter:"
puts [lindex [::tclutils::tumd::frontmatter $md] 0]
