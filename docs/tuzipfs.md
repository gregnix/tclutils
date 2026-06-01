# tclutils::tuzipfs

`tclutils::tuzipfs` is a small Tcl 9 `zipfs` convenience wrapper.  The package
loads under Tcl 8.6 as well, but commands that need `zipfs` throw a clear
`TCLUTILS TUZIPFS UNAVAILABLE` error.

## Commands

```tcl
package require tclutils::tuzipfs

::tclutils::tuzipfs::available
::tclutils::tuzipfs::requireAvailable
::tclutils::tuzipfs::root
::tclutils::tuzipfs::mounts
::tclutils::tuzipfs::mount archive.zip ?mountName?
::tclutils::tuzipfs::unmount mountpoint
::tclutils::tuzipfs::listFiles mountpoint ?-glob pattern? ?-recursive boolean?
::tclutils::tuzipfs::find mountpoint ?options?
::tclutils::tuzipfs::exists zipfsPath
::tclutils::tuzipfs::readFile zipfsPath
::tclutils::tuzipfs::withMounted archive.zip mountVar body ?-mount mountName?
```

## Example

```tcl
tcl::tm::path add lib/tm
package require tclutils::tuzipfs

if {[::tclutils::tuzipfs::available]} {
    ::tclutils::tuzipfs::withMounted document.odt mp {
        puts [::tclutils::tuzipfs::listFiles $mp -glob *.xml]
        puts [::tclutils::tuzipfs::readFile [file join $mp content.xml]]
    }
}
```

## Notes

`zipfs` is part of Tcl 9.  For Tcl 8.6 or for byte-level ZIP creation and ODF
container control, use `tclutils::tuzip` instead.
