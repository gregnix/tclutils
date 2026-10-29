# tclutils::tusysinfo -- describe the computer: OS, CPU, memory, model, disks, monitors.
# Description: collect operating system and hardware information (OS, CPU, memory, model, disks, monitors)
# Category: System · runtime
# Counterpart of tuappinfo (which describes the Tcl runtime). Reads files and
# the registry first and calls a platform program only where nothing else
# has the data; a missing program leaves its fields empty. Pure Tcl, no Tk.
#
#   Linux    /etc/os-release, /proc/cpuinfo, /proc/meminfo, /sys/class/dmi/id,
#            /sys/block, /sys/class/drm/*/edid (no program, no root)
#   macOS    sw_vers, sysctl, system_profiler -json
#   Windows  registry (package registry), one PowerShell call (CIM) for
#            memory, disks and the active monitors; EDID from the registry
#
# API:
#   tclutils::tusysinfo::collect ?options?          -> dict
#   tclutils::tusysinfo::report  info ?-title text? ?-anonymize 0|1? -> text
#   tclutils::tusysinfo::toJson  info ?-indent n?   -> JSON text
#
# collect options:
#   -sections {os cpu memory machine disks displays}   (default: all)
#   -serials  0|1    include serial numbers (default 0)
#   -commands 0|1    allow platform programs (default 1)
#   -timeout  ms     limit for one program call (default 10000)
#   -platform linux|macos|windows   (default: this computer)
#   -root     dir    Linux: read /etc, /proc, /sys below dir (tests)
#
# Error codes: {TCLUTILS TUSYSINFO OPTION|SECTION|PLATFORM}.
#
# Tcl 8.6-
package require Tcl 8.6-
package require tclutils::tuedid 0.1

namespace eval ::tclutils::tusysinfo {
    namespace export collect report toJson
    variable version 0.1
    variable allSections {os cpu memory machine disks displays}
}

proc ::tclutils::tusysinfo::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TUSYSINFO $reason] $msg
}

proc ::tclutils::tusysinfo::_platform {} {
    switch -- $::tcl_platform(platform) {
        windows { return windows }
    }
    if {$::tcl_platform(os) eq "Darwin"} { return macos }
    return linux
}

# ------------------------------------------------------------
# helpers
# ------------------------------------------------------------

proc ::tclutils::tusysinfo::_read {path} {
    if {![file readable $path] || [file isdirectory $path]} { return "" }
    if {[catch {
        set fh [open $path r]
        fconfigure $fh -encoding utf-8
        set data [read $fh]
        close $fh
    }]} { catch {close $fh}; return "" }
    return [string trim $data]
}

proc ::tclutils::tusysinfo::_readBinary {path} {
    if {![file readable $path]} { return "" }
    if {[catch {
        set fh [open $path rb]
        set data [read $fh]
        close $fh
    }]} { catch {close $fh}; return "" }
    return $data
}

# Run a program with a time limit. Returns {ok output}; ok 0 when the
# program is missing, fails or runs too long.
proc ::tclutils::tusysinfo::_run {cmd timeout} {
    variable runDone
    if {[auto_execok [lindex $cmd 0]] eq ""} { return [list 0 ""] }
    set null [expr {$::tcl_platform(platform) eq "windows" ? "NUL" : "/dev/null"}]
    if {[catch {open |[list {*}$cmd 2> $null] r} ch]} { return [list 0 ""] }
    fconfigure $ch -blocking 0 -encoding utf-8
    set key [string map {: _} $ch]
    set runDone($key) ""
    fileevent $ch readable [list apply {{ch key} {
        variable runDone
        append runDone($key,buf) [read $ch]
        if {[eof $ch]} { set runDone($key) eof }
    } ::tclutils::tusysinfo} $ch $key]
    set runDone($key,buf) ""
    set timer [after $timeout [list set ::tclutils::tusysinfo::runDone($key) timeout]]
    vwait ::tclutils::tusysinfo::runDone($key)
    after cancel $timer
    set state $runDone($key)
    set out $runDone($key,buf)
    unset runDone($key) runDone($key,buf)
    fileevent $ch readable {}
    if {$state eq "timeout"} {
        foreach pid [pid $ch] {
            if {$::tcl_platform(platform) eq "windows"} {
                catch {exec taskkill /F /PID $pid 2> NUL}
            } else {
                catch {exec kill $pid 2> /dev/null}
            }
        }
        catch {close $ch}
        return [list 0 $out]
    }
    fconfigure $ch -blocking 1
    set ok [expr {![catch {close $ch}]}]
    return [list $ok $out]
}

# KEY=VALUE lines (os-release), quotes removed.
proc ::tclutils::tusysinfo::_keyValues {text {sep =}} {
    set d [dict create]
    foreach line [split $text \n] {
        set i [string first $sep $line]
        if {$i < 1} continue
        set k [string trim [string range $line 0 [expr {$i - 1}]]]
        set v [string trim [string range $line [expr {$i + [string length $sep]}] end]]
        if {[string match {"*"} $v] || [string match {'*'} $v]} {
            set v [string range $v 1 end-1]
        }
        dict set d $k $v
    }
    return $d
}

proc ::tclutils::tusysinfo::_get {d key {default ""}} {
    if {[dict exists $d $key]} { return [dict get $d $key] }
    return $default
}

# Firmware placeholders ("Default string", "To be filled by O.E.M.", ...)
# say nothing; they become empty.
proc ::tclutils::tusysinfo::_clean {d} {
    set junk {{default string} {to be filled by o.e.m.} {system product name}
              {system manufacturer} {system version} {system serial number}
              {not applicable} {not specified} none o.e.m. oem {base board product}
              {type1productconfigid} 0123456789 {x.x}}
    dict map {k v} $d {
        expr {[string tolower [string trim $v]] in $junk ? "" : $v}
    }
}

# ------------------------------------------------------------
# parsers (pure functions, also used by the tests)
# ------------------------------------------------------------

proc ::tclutils::tusysinfo::_parseOsRelease {text} {
    set kv [_keyValues $text]
    set name [_get $kv PRETTY_NAME]
    if {$name eq ""} { set name [string trim "[_get $kv NAME] [_get $kv VERSION]"] }
    return [dict create name $name id [_get $kv ID] version [_get $kv VERSION_ID]]
}

proc ::tclutils::tusysinfo::_parseMeminfo {text} {
    foreach line [split $text \n] {
        if {[regexp {^MemTotal:\s+(\d+)\s*kB} $line -> kb]} {
            return [expr {$kb * 1024}]
        }
    }
    return 0
}

proc ::tclutils::tusysinfo::_parseCpuinfo {text} {
    set model ""; set logical 0; set cores [dict create]
    set phys ""; set core ""
    foreach line [split $text \n] {
        if {![regexp {^([^:]+?)\s*:\s*(.*)$} $line -> k v]} {
            if {$phys ne "" && $core ne ""} { dict set cores $phys,$core 1 }
            set phys ""; set core ""
            continue
        }
        switch -- $k {
            processor    { incr logical }
            "model name" -
            Model        -
            Hardware     { if {$model eq ""} { set model $v } }
            "physical id" { set phys $v }
            "core id"    { set core $v }
        }
    }
    if {$phys ne "" && $core ne ""} { dict set cores $phys,$core 1 }
    return [dict create model $model logical $logical cores [dict size $cores]]
}

proc ::tclutils::tusysinfo::_parseSwVers {text} {
    set kv [_keyValues $text :]
    set name [_get $kv ProductName]
    set ver [_get $kv ProductVersion]
    return [dict create name [string trim "$name $ver"] id macos \
        version $ver build [_get $kv BuildVersion]]
}

# "key: value" lines of `sysctl key key ...`.
proc ::tclutils::tusysinfo::_parseSysctl {text} {
    return [_keyValues $text :]
}

# Windows CurrentVersion values (dict from the registry). Windows 11 still
# reports ProductName "Windows 10 ..."; the build number tells.
proc ::tclutils::tusysinfo::_parseWinVersion {vals} {
    set name [_get $vals ProductName]
    set build [_get $vals CurrentBuildNumber [_get $vals CurrentBuild]]
    if {[string is integer -strict $build] && $build >= 22000} {
        regsub {^Windows 10} $name {Windows 11} name
    }
    set kernel ""
    if {[_get $vals CurrentMajorVersionNumber] ne ""} {
        set kernel [_get $vals CurrentMajorVersionNumber].[_get $vals CurrentMinorVersionNumber 0].[_get $vals CurrentBuildNumber]
    }
    set ubr [_get $vals UBR]
    if {$ubr ne ""} { append build .$ubr }
    return [dict create name $name id windows \
        version [_get $vals DisplayVersion [_get $vals ReleaseId]] build $build \
        kernel $kernel]
}

# JSON from the one PowerShell call (see _winPowerShell).
proc ::tclutils::tusysinfo::_parseWinCim {json serials} {
    package require tclutils::tujson
    set d [_plain [::tclutils::tujson::parseTyped $json]]
    set mem [_get $d memory 0]
    # Get-PhysicalDisk knows SSD/HDD; Win32_DiskDrive says "Fixed hard disk
    # media" for every internal disk. DeviceId N = \\.\PHYSICALDRIVEN.
    set media [dict create]
    foreach p [_asList [_get $d physical]] {
        set t [string tolower [_get $p MediaType]]
        if {$t ni {ssd hdd}} {
            set t [expr {[string tolower [_get $p BusType]] eq "nvme" ? "ssd" : ""}]
        }
        dict set media [_get $p DeviceId] $t
    }
    set disks {}
    foreach x [_asList [_get $d disks]] {
        set type ""
        if {[regexp {(\d+)$} [_get $x DeviceID] -> n] && [dict exists $media $n]} {
            set type [dict get $media $n]
        } elseif {[string match -nocase *ssd* "[_get $x MediaType] [_get $x Model]"]} {
            set type ssd
        }
        set disk [dict create name [_get $x DeviceID] model [string trim [_get $x Model]] \
            size [_num [_get $x Size]] type $type \
            removable [expr {[string match -nocase *removable* [_get $x MediaType]] ? 1 : 0}]]
        if {$serials} { dict set disk serial [string trim [_get $x SerialNumber]] }
        lappend disks $disk
    }
    # Get-PnpDevice -Class Monitor: every monitor Windows knows; Status OK
    # = connected now, Unknown = not connected (also in a remote session).
    set known {}; set active {}
    foreach m [_asList [_get $d monitors]] {
        set id [string toupper [regsub {_\d+$} [_get $m InstanceName] ""]]
        lappend known $id
        if {[_get $m Status OK] eq "OK"} { lappend active $id }
    }
    return [dict create memory [_num $mem] disks $disks active $active \
        known $known cores [_num [_get $d cores 0]]]
}

proc ::tclutils::tusysinfo::_num {v} {
    if {[string is entier -strict $v] || [string is double -strict $v]} { return $v }
    return 0
}
proc ::tclutils::tusysinfo::_asList {v} {
    # ConvertTo-Json writes a single object instead of a one-element array
    if {$v eq ""} { return {} }
    if {[llength $v] % 2 == 0 && ![catch {dict size $v}] && [_looksLikeObject $v]} {
        return [list $v]
    }
    return $v
}
proc ::tclutils::tusysinfo::_looksLikeObject {v} {
    foreach {k -} $v { if {[string is integer -strict $k] || [llength $k] != 1} { return 0 } }
    return 1
}

# parseTyped -> plain Tcl: objects to dicts, arrays to lists. An array of
# objects stays recognizable as a list of dicts.
proc ::tclutils::tusysinfo::_plain {typed} {
    lassign $typed type v
    switch -- $type {
        object { set d {}; foreach {k x} $v { dict set d $k [_plain $x] }; return $d }
        array  { return [lmap x $v {_plain $x}] }
        null   { return "" }
        default { return $v }
    }
}

# system_profiler -json SPHardwareDataType SPStorageDataType SPDisplaysDataType
proc ::tclutils::tusysinfo::_parseProfiler {json serials} {
    package require tclutils::tujson
    set typed [::tclutils::tujson::parseTyped $json]
    set top [dict create]
    foreach {k v} [lindex $typed 1] { dict set top $k $v }
    set machine [dict create]
    if {[dict exists $top SPHardwareDataType]} {
        set hw [_plain [lindex [lindex [dict get $top SPHardwareDataType] 1] 0]]
        set machine [dict create vendor Apple \
            model [_get $hw machine_name] version [_get $hw machine_model] \
            modelNumber [_get $hw model_number] bios [_get $hw boot_rom_version] \
            chip [_get $hw chip_type [_get $hw cpu_type]] \
            memoryText [_get $hw physical_memory]]
        if {$serials} { dict set machine serial [_get $hw serial_number] }
    }
    # SPStorageDataType lists volumes; APFS puts several volumes (Macintosh
    # HD, Data, ...) in one container on one drive. One entry per
    # container (disk3 from disk3s1s1), its volumes joined in `volumes`.
    set disks {}
    set order {}
    if {[dict exists $top SPStorageDataType]} {
        foreach x [lindex [dict get $top SPStorageDataType] 1] {
            set s [_plain $x]
            set pd [_get $s physical_drive]
            set cont [_get $s bsd_name [_get $s _name]]
            regexp {^(disk\d+)} $cont -> cont
            if {![info exists byCont($cont)]} {
                set byCont($cont) [dict create name $cont \
                    model [_get $pd device_name] size [_num [_get $s size_in_bytes]] \
                    type [string tolower [_get $pd medium_type]] \
                    removable [expr {[_get $pd is_internal_disk yes] eq "no"}] \
                    volumes {}]
                lappend order $cont
            }
            set vols [dict get $byCont($cont) volumes]
            lappend vols [_get $s _name]
            dict set byCont($cont) volumes $vols
        }
        foreach c $order {
            dict set byCont($c) volumes [join [lsort [dict get $byCont($c) volumes]] ", "]
            lappend disks $byCont($c)
        }
    }
    set displays {}
    if {[dict exists $top SPDisplaysDataType]} {
        foreach gpuT [lindex [dict get $top SPDisplaysDataType] 1] {
            set gpu [_plain $gpuT]
            foreach dsp [_get $gpu spdisplays_ndrvs] {
                set res [_get $dsp _spdisplays_resolution [_get $dsp spdisplays_resolution]]
                set pref {}
                if {[regexp {(\d+)\s*x\s*(\d+)(?:.*?@\s*([\d.]+))?} $res -> w h r]} {
                    set pref [dict create width $w height $h refresh [expr {$r eq "" ? 0 : $r}]]
                }
                # vendor id is the EDID manufacturer code in hex (469 = ACI)
                set mf [_pnp [_get $dsp _spdisplays_display-vendor-id]]
                set week [_get $dsp _spdisplays_display-week 0]
                set year [_get $dsp _spdisplays_display-year 0]
                set disp [dict create connector [_get $gpu sppci_model] \
                    manufacturer $mf vendor [::tclutils::tuedid::vendor $mf] \
                    name [_get $dsp _name] \
                    productCode [string toupper [_get $dsp _spdisplays_display-product-id]] \
                    year [_num $year] week [_num $week] \
                    widthCm 0 heightCm 0 diagonal 0 preferred $pref \
                    present [expr {[_get $dsp spdisplays_online spdisplays_yes] eq "spdisplays_yes"}]]
                if {$serials} {
                    dict set disp serialText [_get $dsp _spdisplays_display-serial-number]
                }
                lappend displays $disp
            }
        }
    }
    return [dict create machine $machine disks $disks displays $displays]
}

# Three-letter PNP id from the 16-bit EDID manufacturer code (hex text).
proc ::tclutils::tusysinfo::_pnp {hex} {
    if {![regexp {^[0-9A-Fa-f]{1,4}$} $hex]} { return "" }
    scan $hex %x m
    set code ""
    foreach shift {10 5 0} {
        set c [expr {($m >> $shift) & 0x1F}]
        if {$c < 1 || $c > 26} { return "" }
        append code [format %c [expr {64 + $c}]]
    }
    return $code
}

# One monitor from EDID bytes; serials only on request.
proc ::tclutils::tusysinfo::_display {connector bytes serials} {
    if {[catch {::tclutils::tuedid::parse $bytes} e]} { return {} }
    set d [dict create connector $connector]
    foreach k {manufacturer vendor name productCode year week widthCm heightCm diagonal preferred valid} {
        dict set d $k [dict get $e $k]
    }
    if {$serials} {
        dict set d serial [dict get $e serial]
        dict set d serialText [dict get $e serialText]
    }
    return $d
}

# ------------------------------------------------------------
# collectors per platform
# ------------------------------------------------------------

proc ::tclutils::tusysinfo::_linux {sections root serials} {
    set r [dict create]
    if {"os" in $sections} {
        set text [_read $root/etc/os-release]
        if {$text eq ""} { set text [_read $root/usr/lib/os-release] }
        set os [_parseOsRelease $text]
        # Debian testing/sid has no VERSION_ID; /etc/debian_version says
        # "forky/sid"
        if {[dict get $os version] eq ""} {
            set dv [_read $root/etc/debian_version]
            if {$dv ne ""} {
                dict set os version $dv
            } else {
                dict set os version [_get [_keyValues $text] VERSION_CODENAME]
            }
        }
        set kernel [_read $root/proc/sys/kernel/osrelease]
        if {$kernel eq "" && $root eq ""} { set kernel $::tcl_platform(osVersion) }
        dict set os kernel $kernel
        dict set os arch $::tcl_platform(machine)
        dict set r os $os
    }
    if {"cpu" in $sections} {
        dict set r cpu [_parseCpuinfo [_read $root/proc/cpuinfo]]
    }
    if {"memory" in $sections} {
        dict set r memory [dict create total [_parseMeminfo [_read $root/proc/meminfo]]]
    }
    if {"machine" in $sections} {
        set dmi $root/sys/class/dmi/id
        set m [dict create vendor [_read $dmi/sys_vendor] model [_read $dmi/product_name] \
            version [_read $dmi/product_version] boardVendor [_read $dmi/board_vendor] \
            board [_read $dmi/board_name] bios [_read $dmi/bios_version] \
            biosDate [_read $dmi/bios_date]]
        if {$serials} { dict set m serial [_read $dmi/product_serial] }
        dict set r machine [_clean $m]
    }
    if {"disks" in $sections} {
        set disks {}
        foreach dir [lsort [glob -nocomplain -directory $root/sys/block *]] {
            set name [file tail $dir]
            if {[regexp {^(loop|ram|zram|fd)} $name]} continue
            # virtual devices (device mapper: LVM, LUKS) have no device
            # link; RAID (md) stays
            if {![file exists $dir/device] && ![string match md* $name]} continue
            set sectors [_read $dir/size]
            set size [expr {[string is entier -strict $sectors] ? $sectors * 512 : 0}]
            if {$size == 0} continue
            set vendor [_read $dir/device/vendor]
            if {[string match 0x* $vendor]} { set vendor "" }   ;# virtio: PCI id
            set model [string trim "$vendor [_read $dir/device/model]"]
            set rot [_read $dir/queue/rotational]
            set type [expr {[string match sr* $name] ? "optical" :
                       $rot eq "0" ? "ssd" : $rot eq "1" ? "hdd" : ""}]
            set disk [dict create name $name model $model size $size type $type \
                removable [expr {[_read $dir/removable] eq "1"}]]
            if {$serials} { dict set disk serial [_read $dir/device/serial] }
            lappend disks $disk
        }
        dict set r disks $disks
    }
    if {"displays" in $sections} {
        set displays {}
        foreach dir [lsort [glob -nocomplain -directory $root/sys/class/drm card*-*]] {
            if {[_read $dir/status] ni {connected ""}} continue
            set bytes [_readBinary $dir/edid]
            if {[string length $bytes] < 128} continue
            set conn [regsub {^card\d+-} [file tail $dir] ""]
            set d [_display $conn $bytes $serials]
            if {[dict size $d]} { dict set d present 1; lappend displays $d }
        }
        dict set r displays $displays
    }
    return $r
}

proc ::tclutils::tusysinfo::_macos {sections serials commands timeout} {
    set r [dict create]
    if {!$commands} { return $r }
    if {"os" in $sections} {
        lassign [_run {sw_vers} $timeout] ok out
        set os [_parseSwVers $out]
        lassign [_run {uname -r} $timeout] ok k
        dict set os kernel [string trim $k]
        dict set os arch $::tcl_platform(machine)
        dict set r os $os
    }
    if {"cpu" in $sections || "memory" in $sections} {
        lassign [_run {sysctl machdep.cpu.brand_string hw.ncpu hw.physicalcpu hw.memsize} $timeout] ok out
        set s [_parseSysctl $out]
        if {"cpu" in $sections} {
            dict set r cpu [dict create model [_get $s machdep.cpu.brand_string] \
                logical [_get $s hw.ncpu 0] cores [_get $s hw.physicalcpu 0]]
        }
        if {"memory" in $sections} {
            dict set r memory [dict create total [_num [_get $s hw.memsize 0]]]
        }
    }
    set types {}
    foreach {sec t} {machine SPHardwareDataType disks SPStorageDataType displays SPDisplaysDataType} {
        if {$sec in $sections} { lappend types $t }
    }
    if {[llength $types]} {
        lassign [_run [list system_profiler -json {*}$types] $timeout] ok out
        if {$ok && [string trim $out] ne ""} {
            set p [_parseProfiler $out $serials]
            foreach sec {machine disks displays} {
                if {$sec in $sections} { dict set r $sec [dict get $p $sec] }
            }
        }
    }
    return $r
}

# Memory, disks and active monitors in one PowerShell start (about a second).
proc ::tclutils::tusysinfo::_winPowerShell {timeout} {
    set script {
        $ErrorActionPreference = 'SilentlyContinue'
        $o = [ordered]@{}
        $o.memory = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
        $o.cores = (Get-CimInstance Win32_Processor | Measure-Object -Property NumberOfCores -Sum).Sum
        $o.disks = @(Get-CimInstance Win32_DiskDrive | Select-Object DeviceID,Model,Size,MediaType,SerialNumber)
        $o.physical = @(Get-PhysicalDisk | Select-Object DeviceId,@{n='MediaType';e={[string]$_.MediaType}},@{n='BusType';e={[string]$_.BusType}})
        $o.monitors = @(Get-PnpDevice -Class Monitor | Select-Object @{n='InstanceName';e={$_.InstanceId}},@{n='Status';e={[string]$_.Status}})
        $o | ConvertTo-Json -Depth 4 -Compress
    }
    lassign [_run [list powershell -NoProfile -NonInteractive -Command $script] $timeout] ok out
    if {!$ok || [string trim $out] eq ""} { return "" }
    return $out
}

proc ::tclutils::tusysinfo::_regValues {key} {
    set d [dict create]
    if {[catch {registry values $key} names]} { return $d }
    foreach n $names {
        if {![catch {registry get $key $n} v]} { dict set d $n $v }
    }
    return $d
}

proc ::tclutils::tusysinfo::_windows {sections serials commands timeout} {
    set r [dict create]
    package require registry
    set cim ""
    if {$commands && ("memory" in $sections || "disks" in $sections || "displays" in $sections)} {
        set json [_winPowerShell $timeout]
        if {$json ne ""} { catch {set cim [_parseWinCim $json $serials]} }
    }
    if {"os" in $sections} {
        set os [_parseWinVersion [_regValues {HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion}]]
        if {[dict get $os kernel] eq ""} { dict set os kernel $::tcl_platform(osVersion) }
        dict set os arch $::tcl_platform(machine)
        dict set r os $os
    }
    if {"cpu" in $sections} {
        set base {HKEY_LOCAL_MACHINE\HARDWARE\DESCRIPTION\System\CentralProcessor}
        set v [_regValues $base\\0]
        set n 0
        catch {set n [llength [registry keys $base]]}
        dict set r cpu [dict create model [string trim [_get $v ProcessorNameString]] \
            logical $n cores [expr {$cim eq "" ? 0 : [dict get $cim cores]}]]
    }
    if {"memory" in $sections} {
        dict set r memory [dict create total [expr {$cim eq "" ? 0 : [dict get $cim memory]}]]
    }
    if {"machine" in $sections} {
        set b [_regValues {HKEY_LOCAL_MACHINE\HARDWARE\DESCRIPTION\System\BIOS}]
        dict set r machine [_clean [dict create vendor [_get $b SystemManufacturer] \
            model [_get $b SystemProductName] version [_get $b SystemVersion] \
            boardVendor [_get $b BaseBoardManufacturer] board [_get $b BaseBoardProduct] \
            bios [_get $b BIOSVersion] biosDate [_get $b BIOSReleaseDate]]]
    }
    if {"disks" in $sections} {
        dict set r disks [expr {$cim eq "" ? {} : [dict get $cim disks]}]
    }
    if {"displays" in $sections} {
        set active [expr {$cim eq "" ? {} : [dict get $cim active]}]
        set known  [expr {$cim eq "" ? {} : [dict get $cim known]}]
        set displays {}
        set order {}
        set base {HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\DISPLAY}
        if {![catch {registry keys $base} ids]} {
            foreach id $ids {
                if {[catch {registry keys $base\\$id} insts]} continue
                foreach inst $insts {
                    set k "$base\\$id\\$inst\\Device Parameters"
                    if {[catch {registry get $k EDID} bytes]} continue
                    set inst [string toupper "DISPLAY\\$id\\$inst"]
                    # The registry keeps every monitor that was connected
                    # once, often the same one under several instances
                    # (other port, other driver): one entry per EDID.
                    # present: 1 connected, 0 not connected, "" unknown
                    # (Get-PnpDevice gave no list). WmiMonitorID is not
                    # used: "not supported" on some systems.
                    if {![info exists mon($bytes)]} {
                        set d [_display $id $bytes $serials]
                        if {![dict size $d]} continue
                        dict set d present [expr {[llength $known] ? 0 : ""}]
                        set mon($bytes) $d
                        lappend order $bytes
                    }
                    if {$inst in $active} { dict set mon($bytes) present 1 }
                }
            }
        }
        foreach b $order { lappend displays $mon($b) }
        dict set r displays $displays
    }
    return $r
}

# ------------------------------------------------------------
# public API
# ------------------------------------------------------------

proc ::tclutils::tusysinfo::collect {args} {
    variable allSections
    array set o [list -sections $allSections -serials 0 -commands 1 \
        -timeout 10000 -platform [_platform] -root ""]
    foreach {k v} $args {
        if {![info exists o($k)]} {
            _err OPTION "unknown option \"$k\": must be -sections, -serials, -commands, -timeout, -platform or -root"
        }
        set o($k) $v
    }
    if {[llength $args] % 2} { _err OPTION "missing value for option \"[lindex $args end]\"" }
    foreach s $o(-sections) {
        if {$s ni $allSections} {
            _err SECTION "unknown section \"$s\": must be [join $allSections {, }]"
        }
    }
    foreach b {-serials -commands} {
        if {![string is boolean -strict $o($b)]} { _err OPTION "$b requires a boolean value" }
    }
    set info [dict create platform $o(-platform) host [info hostname]]
    switch -- $o(-platform) {
        linux   { set r [_linux $o(-sections) $o(-root) $o(-serials)] }
        macos   { set r [_macos $o(-sections) $o(-serials) $o(-commands) $o(-timeout)] }
        windows { set r [_windows $o(-sections) $o(-serials) $o(-commands) $o(-timeout)] }
        default { _err PLATFORM "unknown platform \"$o(-platform)\": must be linux, macos or windows" }
    }
    if {$o(-root) ne ""} { dict set info host "" }
    return [dict merge $info $r]
}

# Disk sizes in decimal units (as on the label), memory in binary units.
proc ::tclutils::tusysinfo::_bytes {n {binary 0}} {
    if {![string is double -strict $n] || $n <= 0} { return "" }
    set units [expr {$binary ? {TiB 1099511627776 GiB 1073741824 MiB 1048576}
                              : {TB 1e12 GB 1e9 MB 1e6}}]
    foreach {u f} $units {
        if {$n >= $f} { return "[format %.1f [expr {double($n) / $f}]] $u" }
    }
    return "$n B"
}

proc ::tclutils::tusysinfo::report {info args} {
    array set o {-title "System Information" -anonymize 0}
    foreach {k v} $args {
        if {![info exists o($k)]} { _err OPTION "unknown option \"$k\": must be -title or -anonymize" }
        set o($k) $v
    }
    set L [list "==== $o(-title) ====" "Platform: [_get $info platform]"]
    set host [_get $info host]
    if {$host ne ""} {
        if {$o(-anonymize)} { set host "<host>" }
        lappend L "Host: $host"
    }
    set labels {
        os      {"Operating System" name Name version Version build Build kernel Kernel arch Architecture}
        cpu     {CPU model Model logical "Logical CPUs" cores Cores}
        machine {Machine vendor Vendor model Model version Version modelNumber "Model number" chip Chip boardVendor "Board vendor" board Board bios BIOS biosDate "BIOS date" serial Serial}
    }
    foreach sec {os cpu memory machine} {
        if {![dict exists $info $sec]} continue
        set d [dict get $info $sec]
        if {$sec eq "memory"} {
            lappend L "" "--- Memory ---" "Total: [_bytes [_get $d total 0] 1]"
            continue
        }
        set spec [dict get $labels $sec]
        set lines {}
        foreach {k label} [lrange $spec 1 end] {
            set v [_get $d $k]
            if {$v eq "" || $v eq "0"} continue
            if {$k eq "serial" && $o(-anonymize)} { set v <serial> }
            lappend lines "$label: $v"
        }
        if {![llength $lines]} { set lines [list "(not available)"] }
        lappend L "" "--- [lindex $spec 0] ---" {*}$lines
    }
    if {[dict exists $info disks]} {
        lappend L "" "--- Disks ---"
        foreach x [dict get $info disks] {
            set line [format "  %-10s %-30s %10s  %s" [_get $x name] [_get $x model] \
                [_bytes [_get $x size]] [_get $x type]]
            if {[_get $x removable] eq "1"} { append line " removable" }
            if {[_get $x volumes] ne ""} { append line "  ([_get $x volumes])" }
            lappend L [string trimright $line]
        }
        if {![llength [dict get $info disks]]} { lappend L "  (none found)" }
    }
    if {[dict exists $info displays]} {
        lappend L "" "--- Displays ---"
        foreach x [dict get $info displays] {
            set who [string trim "[_get $x vendor [_get $x manufacturer]] [_get $x name]"]
            set line [format "  %-10s %s" [_get $x connector] $who]
            if {[_get $x diagonal 0] > 0} { append line "  [_get $x diagonal]\"" }
            set p [_get $x preferred]
            if {$p ne ""} {
                append line "  [dict get $p width]x[dict get $p height]"
                if {[dict get $p refresh] > 0} { append line " @ [dict get $p refresh] Hz" }
            }
            if {[_get $x year 0] > 0} { append line "  [_get $x year]" }
            if {[_get $x serialText] ne "" && !$o(-anonymize)} { append line "  SN [_get $x serialText]" }
            if {[_get $x present] eq "0"} { append line "  (not connected)" }
            lappend L [string trimright $line]
        }
        if {![llength [dict get $info displays]]} { lappend L "  (none found)" }
    }
    return [join $L \n]
}

# JSON with numbers where the field is numeric.
proc ::tclutils::tusysinfo::toJson {info args} {
    package require tclutils::tujson
    set indent 2
    foreach {k v} $args {
        if {$k ne "-indent"} { _err OPTION "unknown option \"$k\": must be -indent" }
        set indent $v
    }
    return [::tclutils::tujson::toJson [_typed $info ""] -indent $indent]
}

proc ::tclutils::tusysinfo::_typed {v key} {
    set numeric {total size logical cores widthCm heightCm diagonal week year
                 width height refresh valid removable dpi depth present}
    switch -- $key {
        "" - os - cpu - memory - machine - preferred - screen {
            set pairs {}
            foreach {k x} $v { lappend pairs $k [_typed $x $k] }
            return [::tclutils::tujson::obj $pairs]
        }
        disks - displays {
            return [::tclutils::tujson::arr [lmap x $v {_typed $x item}]]
        }
        item {
            set pairs {}
            foreach {k x} $v { lappend pairs $k [_typed $x $k] }
            return [::tclutils::tujson::obj $pairs]
        }
    }
    if {$key in $numeric && [string is double -strict $v]} {
        return [::tclutils::tujson::num $v]
    }
    return [::tclutils::tujson::str $v]
}

package provide tclutils::tusysinfo 0.1
