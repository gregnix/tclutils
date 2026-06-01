# tclutils::tuxml

Small XML text helper in pure Tcl 8.6+.

This module is not a validating XML parser. It provides writer/helper routines
for scripts that need to generate simple XML safely:

- `escape text ?-quotes boolean?`
- `unescape text`
- `declaration ?encoding?`
- `attrs dict`
- `tag name ?attrs?`
- `element name attrs content`
- `textElement name attrs text`

## Example

```tcl
package require tclutils::tuxml

puts [::tclutils::tuxml::declaration]
puts [::tclutils::tuxml::textElement title {} {A < B & C}]
```

## Notes

Use `textElement` when content is plain text. Use `element` only when the
content is already XML markup.
