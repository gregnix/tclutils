# CLI wrappers

tclutils ships 30 thin CLI wrapper scripts in `bin/`. They call the
package APIs directly, so the library stays usable from normal Tcl code
while also offering convenient command-line entry points. Each wrapper
sources `bin/_bootstrap.tcl` to find the library on the module path.

## Implemented wrappers

- `tuagrep.tcl`
- `tuawk.tcl`
- `tucal.tcl`
- `tucat.tcl`
- `tucmp.tcl`
- `tucode.tcl`
- `tucolumn.tcl`
- `tuexpand.tcl`
- `tufile.tcl`
- `tufind.tcl`
- `tugrep.tcl`
- `tuhead.tcl`
- `tujson.tcl`
- `tumd.tcl`
- `tunl.tcl`
- `tunumfmt.tcl`
- `tuodf.tcl`
- `tupatch.tcl`
- `tupdf.tcl`
- `tupr.tcl`
- `turev.tcl`
- `tuseq.tcl`
- `tushuf.tcl`
- `tusort.tcl`
- `tutac.tcl`
- `tutail.tcl`
- `tutsort.tcl`
- `tuuniq.tcl`
- `tuwc.tcl`
- `tuzipfs.tcl`

Run a wrapper with `tclsh bin/<name>.tcl --help` (where supported) or
with its usual filter arguments.
