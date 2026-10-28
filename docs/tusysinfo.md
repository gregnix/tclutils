# tclutils::tusysinfo

Describe the computer: operating system, CPU, memory, model, disks and
monitors, on Linux, macOS and Windows. Counterpart of `tuappinfo`, which
describes the Tcl runtime. Pure Tcl, no Tk.

The module reads files and the registry first and calls a platform program
only where nothing else has the data. A missing program leaves its fields
empty; `collect` does not fail because of it.

| System | Sources |
|--------|---------|
| Linux | `/etc/os-release`, `/proc/cpuinfo`, `/proc/meminfo`, `/sys/class/dmi/id`, `/sys/block`, `/sys/class/drm/*/edid` — no program, no root |
| macOS | `sw_vers`, `uname`, `sysctl`, `system_profiler -json` (takes a few seconds) |
| Windows | registry (package `registry`) for OS, CPU, model and monitor EDID; one PowerShell call (CIM) for memory, disks and the active monitors |

Monitors are read from their EDID through `tclutils::tuedid`.

## Load

```tcl
package require tclutils::tusysinfo 0.1
```

## API

```tcl
::tclutils::tusysinfo::collect ?options?                         ;# -> dict
::tclutils::tusysinfo::report  info ?-title text? ?-anonymize 0|1? ;# -> text
::tclutils::tusysinfo::toJson  info ?-indent n?                  ;# -> JSON
```

Options of `collect`:

| Option | Default | Meaning |
|--------|---------|---------|
| `-sections` | all | any of `os cpu memory machine disks displays` |
| `-serials` | `0` | `1` adds serial numbers (computer, disks, monitors) |
| `-commands` | `1` | `0` uses no platform program (macOS then returns nothing, Windows no memory, disks or monitor filter) |
| `-timeout` | `10000` | limit in ms for one program call |
| `-platform` | this computer | `linux`, `macos`, `windows` |
| `-root` | empty | Linux: read `/etc`, `/proc`, `/sys` below this folder (tests) |

## Result

```text
platform linux
host     decoder
os       {name {Debian GNU/Linux 13 (trixie)} id debian version 13 kernel 6.12.48-amd64 arch x86_64}
cpu      {model {AMD Ryzen 5 5600G} logical 12 cores 6}
memory   {total 16694710272}
machine  {vendor ASUS model ... version ... boardVendor ... board ... bios ... biosDate ...}
disks    {{name nvme0n1 model {Samsung SSD 980} size 1000204886016 type ssd removable 0} ...}
displays {{connector DP-1 manufacturer DEL vendor Dell name {DELL P2722H} productCode A0F1
           year 2022 week 10 widthCm 60 heightCm 34 diagonal 27.2
           preferred {width 1920 height 1080 refresh 60.0} valid 1 present 1} ...}
```

Sizes are bytes; `report` shows disks in GB (as on the label) and memory
in GiB. `type` is `ssd`, `hdd`, `optical` or empty. On macOS
`machine` also has `chip` and `memoryText`, `disks` a `mount`. With
`-serials 1` `machine`, `disks` and `displays` get `serial` (monitors also
`serialText`).

## Usage

```tcl
set info [::tclutils::tusysinfo::collect]
puts [::tclutils::tusysinfo::report $info]
set fh [open sysinfo.json w]
puts $fh [::tclutils::tusysinfo::toJson $info]
close $fh
```

Command line: `tclsh bin/tusysinfo.tcl ?--json? ?--serials? ?--anonymize?`
(`tusysinfo(1)`).

## Notes

- Serial numbers, host names and MAC addresses identify a computer and,
  on an office PC, its user. Serials come only with `-serials 1`;
  `report -anonymize 1` hides the host name and serials. MAC addresses
  are not collected.
- Linux: the computer's serial number (`product_serial`) is readable by
  root only; it stays empty otherwise. Virtual machines often have no DMI
  data and no monitor.
- Monitors carry `present`: 1 connected, 0 not connected, empty when
  unknown. Windows keeps every monitor that was ever connected, often the
  same one under several instances (other port, other driver);
  `tusysinfo` lists each EDID once and takes `present` from
  `Get-PnpDevice -Class Monitor` (status OK). In a remote desktop session
  the physical monitors count as not connected. `report` marks them
  "(not connected)". (`WmiMonitorID` is not used: it reports "not
  supported" on some systems.) Windows 11 still reports
  `ProductName` "Windows 10 …"; a build of 22000 or later is shown as
  Windows 11. SSD or HDD comes from `Get-PhysicalDisk` (an NVMe disk counts
  as SSD).
- Firmware placeholders such as "Default string" or "To be filled by
  O.E.M." are left empty.
- macOS: `system_profiler` is slow (several seconds); `-sections {os cpu
  memory}` avoids it.
- The macOS and Windows parts are tested with constructed program output
  and a simulated registry, not yet on real Macs and Windows PCs.
- Program calls run with `vwait`; in a Tk application the event loop runs
  while waiting.

## Errors

`{TCLUTILS TUSYSINFO OPTION}` unknown option or missing value,
`{TCLUTILS TUSYSINFO SECTION}` unknown section,
`{TCLUTILS TUSYSINFO PLATFORM}` unknown platform.
