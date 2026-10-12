# tclutils::tutask -- tasks on coroutines: await with timeout, cancel with
#                     cleanup, task groups, a thread pool and a sandbox.
# Description: tasks on coroutines with await, timeout, cancel, groups, thread pool and sandbox.
# Category: System · runtime
#
# A task is a coroutine owned by an object. Inside a task, await suspends
# until an operation reports back; meanwhile the event loop runs. Every
# operation follows one contract:
#
#   starter cb   -> cancel command (a command prefix, may be "")
#   later:       {*}$cb ok value
#           or   {*}$cb error message ?options?
#
#   set t [::tclutils::tutask::spawn apply {{} {
#       set out [::tclutils::tutask::await \
#                    [::tclutils::tutask::pipe {ls -l}] -timeout 5000]
#       return [llength [split $out \n]]
#   }}]
#   $t wait          ;# outside a task: blocks in vwait; inside: awaits
#   $t destroy
#
# Rules that the code keeps, and that callers can rely on:
#   - cancel resumes the task with a cancel request, so try/finally in the
#     task body runs. Only if a body never awaits again is it killed hard.
#   - await -timeout and cancelling an await both call the operation's
#     cancel command: nothing keeps running unnoticed.
#   - a late result (after timeout or cancel) is dropped, never delivered to
#     the wrong await.
#   - errors keep their -errorcode across task, thread and interp borders.
#   - an error nobody collected is reported through bgerror when the task
#     object is destroyed.
#
# Pool needs the Thread package and loads it on first use; everything else
# is Tcl core. Sandbox code runs in the calling thread, bounded by command
# and time limits.
#
# Namespace: ::tclutils::tutask   Package: tclutils::tutask 0.1
# Errors:    {TCLUTILS TUTASK <REASON>}, REASON one of CANCELLED TIMEOUT
#            NOTASK NOTDONE OPTION NOTHREAD EMPTY PROTOCOL INIT INSIDE,
#            {TCLUTILS TUTASK LIMIT COMMANDS|TIME}

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tutask {
    namespace export spawn await sleep timer pipe onwrite current run \
        group pool sandbox stats tasks
    variable version 0.1
    variable seq 0
    # await bookkeeping, keyed by an integer per await:
    #   pend(key)    coroutine that waits
    #   cancel(key)  cancel command of the operation
    #   res(key)     result that arrived, waiting for its resume
    #   tmo(key)     timeout timer id     rsm(key) resume timer id
    variable pend
    variable cancel
    variable res
    variable tmo
    variable rsm
    variable taskOf     ;# coroutine -> task object
    variable live       ;# task object -> 1
    variable pipes      ;# channel -> callback prefix
    variable pipebuf    ;# channel -> collected output
    variable pools      ;# pool object -> 1
    variable boxes      ;# sandbox object -> 1
    variable block      ;# results of blocking waits outside a task
    variable poolres    ;# results from pool workers, key "pool,job"
}

proc ::tclutils::tutask::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TUTASK {*}$reason] $msg
}

proc ::tclutils::tutask::_cancelled {} {
    return -code error -errorcode {TCLUTILS TUTASK CANCELLED} "task cancelled"
}

# ---------------------------------------------------------------------------
# await
# ---------------------------------------------------------------------------

# Suspend the current coroutine until the operation reports. Returns the
# value or raises the reported error with its own -errorcode.
proc ::tclutils::tutask::await {starter args} {
    variable seq
    variable pend
    variable cancel
    variable tmo
    variable taskOf
    set opts [::tclutils::common::parseOptions {-timeout 0} {*}$args]
    set ms [dict get $opts -timeout]
    if {![string is integer -strict $ms] || $ms < 0} {
        _err OPTION "-timeout must be a non-negative integer (ms)"
    }
    set co [info coroutine]
    if {$co eq ""} {
        _err NOTASK "await outside a task or coroutine"
    }
    set task ""
    if {[info exists taskOf($co)]} {
        set task $taskOf($co)
        if {[$task _cancelRequested]} { _cancelled }
    }
    set key [incr seq]
    set pend($key) $co
    set cancel($key) ""
    if {$ms > 0} {
        set tmo($key) [after $ms [list ::tclutils::tutask::_settle $key timeout]]
    }
    if {$task ne ""} { $task _awaiting $key }
    if {[catch {{*}$starter [list ::tclutils::tutask::_settle $key]} cc copts]} {
        _forget $key
        if {$task ne ""} { $task _awaiting "" }
        return -options $copts $cc
    }
    # The operation may already have finished (synchronous callback):
    # then its resume is scheduled and the cancel command is moot.
    set cancel($key) $cc
    set msg [yield]
    set cc $cancel($key)
    _forget $key
    if {$task ne ""} { $task _awaiting "" }
    switch -- [lindex $msg 0] {
        ok {
            return [lindex $msg 1]
        }
        error {
            lassign $msg - m o
            set ec NONE
            if {[dict exists $o -errorcode]} { set ec [dict get $o -errorcode] }
            if {[dict exists $o -errorinfo]} {
                return -code error -errorcode $ec -errorinfo [dict get $o -errorinfo] $m
            }
            return -code error -errorcode $ec $m
        }
        timeout {
            catch {uplevel #0 $cc}
            _err TIMEOUT "timeout after $ms ms"
        }
        cancel {
            _cancelled
        }
        default {
            _err PROTOCOL "coroutine $co resumed with \"$msg\" while awaiting"
        }
    }
}

proc ::tclutils::tutask::_forget {key} {
    variable pend
    variable cancel
    variable res
    variable tmo
    variable rsm
    foreach a {tmo rsm} {
        upvar 0 $a arr
        if {[info exists arr($key)]} {
            after cancel $arr($key)
            unset arr($key)
        }
    }
    unset -nocomplain pend($key) cancel($key) res($key)
}

# The callback every operation gets. Only the first report per await
# counts; the coroutine is resumed from the event loop, never from inside
# the starter (it would still be running).
proc ::tclutils::tutask::_settle {key status args} {
    variable pend
    variable res
    variable tmo
    variable rsm
    if {![info exists pend($key)] || [info exists res($key)]} { return }
    set res($key) [list $status {*}$args]
    if {$status ne "timeout" && [info exists tmo($key)]} {
        after cancel $tmo($key)
        unset tmo($key)
    }
    set rsm($key) [after 0 [list ::tclutils::tutask::_resume $key]]
    return
}

proc ::tclutils::tutask::_resume {key} {
    variable pend
    variable res
    variable rsm
    unset -nocomplain rsm($key)
    if {![info exists pend($key)] || ![info exists res($key)]} { return }
    set co $pend($key)
    set msg $res($key)
    unset res($key)
    if {[llength [info commands $co]]} { $co $msg }
    return
}

# Cancel path: stop the operation, then resume the coroutine at once with a
# cancel request. A result that already arrived is dropped. Returns 1 if an
# await was interrupted.
proc ::tclutils::tutask::_interrupt {key} {
    variable pend
    variable cancel
    variable res
    variable rsm
    if {![info exists pend($key)]} { return 0 }
    set co $pend($key)
    if {[info exists rsm($key)]} {
        after cancel $rsm($key)
        unset rsm($key)
    }
    unset -nocomplain res($key)
    if {[info exists cancel($key)] && $cancel($key) ne ""} {
        catch {uplevel #0 $cancel($key)}
        set cancel($key) ""
    }
    if {[llength [info commands $co]]} { $co [list cancel] }
    return 1
}

# ---------------------------------------------------------------------------
# Operations
# ---------------------------------------------------------------------------

# Done after ms milliseconds with value.
proc ::tclutils::tutask::timer {ms {value ""}} {
    if {![string is integer -strict $ms] || $ms < 0} {
        _err OPTION "timer: ms must be a non-negative integer"
    }
    return [list ::tclutils::tutask::_timerStart $ms $value]
}

proc ::tclutils::tutask::_timerStart {ms value cb} {
    set id [after $ms [list {*}$cb ok $value]]
    return [list after cancel $id]
}

# Inside a task: pause for ms milliseconds without blocking the event loop.
proc ::tclutils::tutask::sleep {ms} {
    await [timer $ms]
    return
}

# Done when the (global or fully qualified) variable is written; the value
# is the new content. For GUI waits: a button sets the variable.
proc ::tclutils::tutask::onwrite {varName} {
    if {![string match ::* $varName]} { set varName ::$varName }
    return [list ::tclutils::tutask::_onwriteStart $varName]
}

proc ::tclutils::tutask::_onwriteStart {var cb} {
    set tr [list ::tclutils::tutask::_onwriteFire $var $cb]
    trace add variable $var write $tr
    return [list trace remove variable $var write $tr]
}

proc ::tclutils::tutask::_onwriteFire {var cb args} {
    trace remove variable $var write [list ::tclutils::tutask::_onwriteFire $var $cb]
    set v ""
    catch {set v [set $var]}
    {*}$cb ok $v
}

# Run a command pipeline without blocking; the value is everything it
# wrote (stdout and stderr together). A non-zero exit is an error with
# Tcl's {CHILDSTATUS pid code}. Cancel kills the processes.
#   -encoding enc   channel encoding (default: system)
#   -profile p      Tcl 9 only, e.g. replace (default: Tcl's strict)
proc ::tclutils::tutask::pipe {cmdlist args} {
    set opts [::tclutils::common::parseOptions {-encoding "" -profile ""} {*}$args]
    if {![llength $cmdlist]} { _err OPTION "pipe: empty command" }
    if {[dict get $opts -profile] ne ""
            && [package vcompare [info tclversion] 9.0] < 0} {
        _err OPTION "pipe: -profile needs Tcl 9"
    }
    return [list ::tclutils::tutask::_pipeStart $cmdlist $opts]
}

proc ::tclutils::tutask::_pipeStart {cmdlist opts cb} {
    variable pipes
    variable pipebuf
    set ch [open |[concat $cmdlist [list 2>@1]] r]
    set cfg [list -blocking 0 -translation auto]
    if {[dict get $opts -encoding] ne ""} { lappend cfg -encoding [dict get $opts -encoding] }
    if {[dict get $opts -profile] ne ""} { lappend cfg -profile [dict get $opts -profile] }
    if {[catch {chan configure $ch {*}$cfg} m o]} {
        catch {close $ch}
        return -options $o $m
    }
    set pipes($ch) $cb
    set pipebuf($ch) ""
    chan event $ch readable [list ::tclutils::tutask::_pipeRead $ch]
    return [list ::tclutils::tutask::_pipeKill $ch]
}

proc ::tclutils::tutask::_pipeRead {ch} {
    variable pipes
    variable pipebuf
    if {![info exists pipes($ch)]} { return }
    set cb $pipes($ch)
    if {[catch {append pipebuf($ch) [read $ch]} m o]} {
        # Tcl 9, strict profile: bytes that do not fit the encoding.
        _pipeKill $ch
        {*}$cb error $m $o
        return
    }
    if {![eof $ch]} { return }
    chan event $ch readable {}
    set out $pipebuf($ch)
    unset pipes($ch) pipebuf($ch)
    # Blocking for close, otherwise there is no exit status.
    chan configure $ch -blocking 1
    if {[catch {close $ch} m o]} {
        {*}$cb error "$m" $o
    } else {
        {*}$cb ok $out
    }
}

proc ::tclutils::tutask::_pipeKill {ch} {
    variable pipes
    variable pipebuf
    if {![info exists pipes($ch)]} { return }
    unset pipes($ch) pipebuf($ch)
    catch {chan event $ch readable {}}
    set pids {}
    catch {set pids [pid $ch]}
    foreach p $pids {
        if {$::tcl_platform(platform) eq "windows"} {
            catch {exec taskkill /PID $p /T /F}
        } else {
            catch {exec kill $p}
        }
    }
    catch {chan configure $ch -blocking 1}
    catch {close $ch}
    return
}

# ---------------------------------------------------------------------------
# Task
# ---------------------------------------------------------------------------

oo::class create ::tclutils::tutask::Task {
    variable co state value opts cancelReq waiters ondone awaitKey \
        observed detach

    constructor {detachFlag cmd argv} {
        set co [self namespace]::co
        set state running
        set value ""
        set opts {}
        set cancelReq 0
        set waiters {}
        set ondone {}
        set awaitKey ""
        set observed 0
        set detach $detachFlag
        set ::tclutils::tutask::live([self]) 1
        set ::tclutils::tutask::taskOf($co) [self]
        coroutine $co [namespace which my] _Run $cmd $argv
    }

    method _Run {cmd argv} {
        set c [catch {uplevel #0 [list {*}$cmd {*}$argv]} r o]
        my _Finish $c $r $o
        return
    }

    method _Finish {c r o} {
        unset -nocomplain ::tclutils::tutask::taskOf($co)
        set ec ""
        if {[dict exists $o -errorcode]} { set ec [dict get $o -errorcode] }
        if {$c == 1 && $ec ne {TCLUTILS TUTASK CANCELLED}} {
            set state error
            set value $r
            set opts $o
        } elseif {$cancelReq || $c == 1} {
            set state cancelled
            set value ""
        } elseif {$c == 0 || $c == 2} {
            set state ok
            set value $r
        } else {
            set state error
            set value "task ended with return code $c"
            set opts [dict create -code 1 -errorcode {TCLUTILS TUTASK PROTOCOL} \
                -errorinfo $value]
        }
        set outcome [my _Outcome]
        foreach w $waiters { after 0 [list {*}$w {*}$outcome] }
        set waiters {}
        foreach cb $ondone { after 0 [list {*}$cb [self]] }
        set ondone {}
        if {$detach} {
            after 0 [list ::tclutils::tutask::_destroyIf [self]]
        }
        return
    }

    method _Outcome {} {
        switch -- $state {
            ok        { return [list ok $value] }
            error     { return [list error $value $opts] }
            cancelled {
                return [list error "task cancelled" \
                    {-code 1 -errorcode {TCLUTILS TUTASK CANCELLED}}]
            }
        }
        return {}
    }

    method _cancelRequested {} { return $cancelReq }
    method _awaiting {key} { set awaitKey $key }

    method state {} { return $state }

    # Value of a finished task; raises its error or CANCELLED.
    method result {} {
        set observed 1
        switch -- $state {
            running {
                ::tclutils::tutask::_err NOTDONE "task [self] is still running"
            }
            ok { return $value }
            cancelled { ::tclutils::tutask::_cancelled }
        }
        set ec NONE
        if {[dict exists $opts -errorcode]} { set ec [dict get $opts -errorcode] }
        set info $value
        if {[dict exists $opts -errorinfo]} { set info [dict get $opts -errorinfo] }
        return -code error -errorcode $ec -errorinfo $info $value
    }

    # Request cancellation. The task is resumed with a cancel request at
    # once, so its finally clauses have run when cancel returns. From
    # inside the task itself the request takes effect at the next await.
    method cancel {} {
        if {$state ne "running"} { return 0 }
        set cancelReq 1
        if {[info coroutine] eq $co} { return 1 }
        if {$awaitKey ne ""} {
            set k $awaitKey
            if {[catch {::tclutils::tutask::_interrupt $k} m o]} {
                # Body code raised while unwinding; it is recorded as the
                # task's error by _Finish. Nothing to propagate here.
            }
        }
        return 1
    }

    # Wait for the task. Inside a task: await (a timeout cancels the task).
    # Outside: vwait until done -- not for GUI handlers, see the docs.
    method wait {args} {
        set o [::tclutils::common::parseOptions {-timeout 0} {*}$args]
        set observed 1
        if {[info coroutine] ne ""} {
            return [::tclutils::tutask::await [list [self] _Op] \
                -timeout [dict get $o -timeout]]
        }
        return [::tclutils::tutask::_block [list [self] _Op] [dict get $o -timeout]]
    }

    # Call cmd with the task object appended when it is done.
    method ondone {cmd} {
        set observed 1
        if {$state ne "running"} {
            after 0 [list {*}$cmd [self]]
        } else {
            lappend ondone $cmd
        }
        return
    }

    # The task as an operation (starter): what wait and Group use.
    method _Op {cb} {
        set observed 1
        if {$state ne "running"} {
            set id [after 0 [list {*}$cb {*}[my _Outcome]]]
            return [list after cancel $id]
        }
        lappend waiters $cb
        return [list [self] _OpCancel $cb]
    }

    method _OpCancel {cb} {
        set i [lsearch -exact $waiters $cb]
        if {$i >= 0} { set waiters [lreplace $waiters $i $i] }
        my cancel
        return
    }

    method _observed {} { return $observed }

    # Not from inside the task itself: the running coroutine would be torn
    # down under its own feet. Use cancel there.
    method destroy {} {
        if {[info coroutine] eq $co} {
            ::tclutils::tutask::_err INSIDE \
                "a task cannot destroy itself while running; use cancel"
        }
        next
    }

    destructor {
        if {$state eq "running"} {
            catch {my cancel}
            if {[llength [info commands $co]]} {
                # Never awaited again: no clean unwinding possible.
                rename $co {}
                unset -nocomplain ::tclutils::tutask::taskOf($co)
                set state cancelled
            }
        }
        if {$state eq "error" && !$observed} {
            set ec NONE
            if {[dict exists $opts -errorcode]} { set ec [dict get $opts -errorcode] }
            after 0 [list error "tutask: error in task [self] was never collected: $value" \
                [expr {[dict exists $opts -errorinfo] ? [dict get $opts -errorinfo] : $value}] $ec]
        }
        unset -nocomplain ::tclutils::tutask::live([self])
    }
}
# Internal methods the procs of this namespace call. After the method
# definitions: defining a method named _x makes it unexported again.
oo::define ::tclutils::tutask::Task export \
    _cancelRequested _awaiting _Op _OpCancel _observed

proc ::tclutils::tutask::_destroyIf {obj} {
    if {[info object isa object $obj]} { $obj destroy }
}

# Wait for an operation outside any coroutine, in vwait.
proc ::tclutils::tutask::_block {starter ms} {
    variable seq
    variable block
    set key b[incr seq]
    set block($key) ""
    set cc [{*}$starter [list ::tclutils::tutask::_blockSet $key]]
    set tid ""
    if {$ms > 0} {
        set tid [after $ms [list ::tclutils::tutask::_blockSet $key timeout]]
    }
    while {$block($key) eq ""} {
        vwait ::tclutils::tutask::block($key)
    }
    if {$tid ne ""} { after cancel $tid }
    set msg $block($key)
    unset block($key)
    switch -- [lindex $msg 0] {
        ok { return [lindex $msg 1] }
        timeout {
            catch {uplevel #0 $cc}
            _err TIMEOUT "timeout after $ms ms"
        }
        error {
            lassign $msg - m o
            set ec NONE
            if {[dict exists $o -errorcode]} { set ec [dict get $o -errorcode] }
            if {[dict exists $o -errorinfo]} {
                return -code error -errorcode $ec -errorinfo [dict get $o -errorinfo] $m
            }
            return -code error -errorcode $ec $m
        }
    }
    _err PROTOCOL "unexpected result \"$msg\""
}

proc ::tclutils::tutask::_blockSet {key status args} {
    variable block
    if {![info exists block($key)] || $block($key) ne ""} { return }
    set block($key) [list $status {*}$args]
}

# Start a task. It runs at once up to its first await.
#   spawn ?-detach 0|1? cmd ?arg ...?
# A detached task destroys itself when done; an error it raised and nobody
# collected goes to bgerror.
proc ::tclutils::tutask::spawn {args} {
    set detach 0
    if {[lindex $args 0] eq "-detach"} {
        set detach [::tclutils::common::ensureBoolean [lindex $args 1] -detach]
        set args [lrange $args 2 end]
    }
    if {![llength $args]} { _err OPTION "spawn ?-detach 0|1? cmd ?arg ...?" }
    return [::tclutils::tutask::Task new $detach [lindex $args 0] [lrange $args 1 end]]
}

# The task object of the running coroutine, or "".
proc ::tclutils::tutask::current {} {
    variable taskOf
    set co [info coroutine]
    if {$co ne "" && [info exists taskOf($co)]} { return $taskOf($co) }
    return ""
}

# Spawn, wait, destroy: the result. For scripts and tests.
#   run ?-timeout ms? cmd ?arg ...?
proc ::tclutils::tutask::run {args} {
    set ms 0
    if {[lindex $args 0] eq "-timeout"} {
        set ms [lindex $args 1]
        set args [lrange $args 2 end]
    }
    set t [spawn {*}$args]
    try {
        return [$t wait -timeout $ms]
    } finally {
        $t destroy
    }
}

# Live task objects and other counters, to find leaks.
proc ::tclutils::tutask::tasks {} {
    variable live
    return [lsort [array names live]]
}

proc ::tclutils::tutask::stats {} {
    variable live
    variable pend
    variable pipes
    variable pools
    variable boxes
    set running 0
    foreach t [array names live] {
        if {[$t state] eq "running"} { incr running }
    }
    return [dict create tasks [array size live] running $running \
        awaits [array size pend] pipes [array size pipes] \
        pools [array size pools] sandboxes [array size boxes]]
}

# ---------------------------------------------------------------------------
# Group: several tasks, one wait
# ---------------------------------------------------------------------------

oo::class create ::tclutils::tutask::Group {
    variable tasks gen winner

    constructor {} {
        set tasks {}
        set gen 0
        set winner ""
    }

    method spawn {args} {
        set t [::tclutils::tutask::spawn {*}$args]
        lappend tasks $t
        return $t
    }

    method tasks {} { return $tasks }
    method winner {} { return $winner }

    # -mode all   : list of all results in spawn order; the first error
    #               cancels the others and is raised.
    # -mode first : value of the first task to finish; the others are
    #               cancelled. [$g winner] names it.
    method wait {args} {
        set o [::tclutils::common::parseOptions {-mode all -timeout 0} {*}$args]
        ::tclutils::common::ensureOneOf [dict get $o -mode] {all first} -mode
        set starter [list [namespace which my] _Op [dict get $o -mode]]
        if {[info coroutine] ne ""} {
            return [::tclutils::tutask::await $starter -timeout [dict get $o -timeout]]
        }
        return [::tclutils::tutask::_block $starter [dict get $o -timeout]]
    }

    method _Op {mode cb} {
        set g [incr gen]
        set winner ""
        if {![llength $tasks]} {
            if {$mode eq "first"} {
                after 0 [list {*}$cb error "group is empty" \
                    {-code 1 -errorcode {TCLUTILS TUTASK EMPTY}}]
            } else {
                after 0 [list {*}$cb ok {}]
            }
            return ""
        }
        foreach t $tasks {
            $t ondone [list [namespace which my] _Child $g $mode $cb]
        }
        return [list [namespace which my] _OpCancel $g]
    }

    method _OpCancel {g} {
        if {$g == $gen} { incr gen }
        my cancel
        return
    }

    method _Child {g mode cb t} {
        if {$g != $gen} { return }
        set st [$t state]
        if {$mode eq "first"} {
            incr gen
            set winner $t
            my cancel
            if {$st eq "ok"} {
                {*}$cb ok [$t result]
            } else {
                catch {$t result} m o
                {*}$cb error $m $o
            }
            return
        }
        if {$st ne "ok"} {
            incr gen
            my cancel
            catch {$t result} m o
            {*}$cb error $m $o
            return
        }
        foreach x $tasks {
            if {[$x state] ne "ok"} { return }
        }
        incr gen
        set out {}
        foreach x $tasks { lappend out [$x result] }
        {*}$cb ok $out
    }

    method cancel {} {
        foreach t $tasks {
            if {[info object isa object $t]} { $t cancel }
        }
        return
    }

    destructor {
        incr gen
        foreach t $tasks {
            if {[info object isa object $t]} { $t destroy }
        }
    }
}

proc ::tclutils::tutask::group {} {
    return [::tclutils::tutask::Group new]
}

# ---------------------------------------------------------------------------
# Pool: worker threads (Thread package)
# ---------------------------------------------------------------------------

oo::class create ::tclutils::tutask::Pool {
    variable size init workers idle queue jobs jseq

    constructor {args} {
        if {[catch {package require Thread}]} {
            ::tclutils::tutask::_err NOTHREAD "the Thread package is not available"
        }
        set o [::tclutils::common::parseOptions {-size 2 -init ""} {*}$args]
        set size [::tclutils::common::ensurePositiveInteger [dict get $o -size] -size]
        set init [dict get $o -init]
        set workers {}
        set idle {}
        set queue {}
        set jobs [dict create]
        set jseq 0
        set ::tclutils::tutask::pools([self]) 1
    }

    # Operation: run script in a worker; the value is its result. Errors
    # come back with the worker's -errorcode and -errorinfo.
    method op {script} {
        return [list [namespace which my] _Submit $script]
    }

    method _Submit {script cb} {
        set id [incr jseq]
        dict set jobs $id [dict create script $script cb $cb worker "" cancelled 0]
        lappend queue $id
        my _Dispatch
        return [list [namespace which my] _Cancel $id]
    }

    method _Worker {} {
        set w [thread::create {
            proc ::__tutask_job {script} {
                set c [catch {uplevel #0 $script} r o]
                return [list $c $r $o]
            }
            thread::wait
        }]
        if {$init ne "" && [catch {thread::send $w $init} m]} {
            thread::release $w
            ::tclutils::tutask::_err INIT "pool -init failed: $m"
        }
        lappend workers $w
        return $w
    }

    method _Dispatch {} {
        while {[llength $queue]} {
            if {[llength $idle]} {
                set w [lindex $idle 0]
                set idle [lrange $idle 1 end]
            } elseif {[llength $workers] < $size} {
                set w [my _Worker]
            } else {
                return
            }
            set id [lindex $queue 0]
            set queue [lrange $queue 1 end]
            dict set jobs $id worker $w
            set var ::tclutils::tutask::poolres([self],$id)
            trace add variable $var write \
                [list ::tclutils::tutask::_poolDone [self] $id]
            thread::send -async $w [list ::__tutask_job [dict get $jobs $id script]] $var
        }
    }

    method _Done {id r} {
        if {![dict exists $jobs $id]} { return }
        set job [dict get $jobs $id]
        dict unset jobs $id
        set w [dict get $job worker]
        if {$w in $workers} { lappend idle $w }
        if {![dict get $job cancelled]} {
            lassign $r c msg o
            if {$c == 0 || $c == 2} {
                {*}[dict get $job cb] ok $msg
            } else {
                {*}[dict get $job cb] error $msg $o
            }
        }
        my _Dispatch
    }

    method _Cancel {id} {
        if {![dict exists $jobs $id]} { return }
        set i [lsearch -exact $queue $id]
        if {$i >= 0} {
            set queue [lreplace $queue $i $i]
            dict unset jobs $id
            return
        }
        dict set jobs $id cancelled 1
        catch {thread::cancel [dict get $jobs $id worker]}
        return
    }

    method stats {} {
        return [dict create workers [llength $workers] idle [llength $idle] \
            queued [llength $queue] jobs [dict size $jobs]]
    }

    destructor {
        dict for {id job} $jobs {
            if {![dict get $job cancelled]} {
                catch {{*}[dict get $job cb] error "pool destroyed" \
                    {-code 1 -errorcode {TCLUTILS TUTASK CANCELLED}}}
            }
            if {[dict get $job worker] ne ""} {
                catch {thread::cancel [dict get $job worker]}
            }
        }
        foreach w $workers { catch {thread::release $w} }
        foreach name [array names ::tclutils::tutask::poolres [self],*] {
            unset -nocomplain ::tclutils::tutask::poolres($name)
        }
        unset -nocomplain ::tclutils::tutask::pools([self])
    }
}
oo::define ::tclutils::tutask::Pool export _Done

proc ::tclutils::tutask::_poolDone {pool id name1 name2 op} {
    variable poolres
    set key $pool,$id
    trace remove variable ::tclutils::tutask::poolres($key) write \
        [list ::tclutils::tutask::_poolDone $pool $id]
    if {![info exists poolres($key)]} { return }
    set r $poolres($key)
    unset poolres($key)
    if {[info object isa object $pool]} { $pool _Done $id $r }
}

proc ::tclutils::tutask::pool {args} {
    return [::tclutils::tutask::Pool new {*}$args]
}

# ---------------------------------------------------------------------------
# Sandbox: a (safe) interpreter with limits
# ---------------------------------------------------------------------------

oo::class create ::tclutils::tutask::Sandbox {
    variable ip cmds ms

    constructor {args} {
        set o [::tclutils::common::parseOptions \
            {-safe 1 -commands 0 -time 0 -aliases {}} {*}$args]
        set safe [::tclutils::common::ensureBoolean [dict get $o -safe] -safe]
        foreach k {-commands -time} {
            set v [dict get $o $k]
            if {![string is integer -strict $v] || $v < 0} {
                ::tclutils::tutask::_err OPTION "$k must be a non-negative integer"
            }
        }
        set cmds [dict get $o -commands]
        set ms [dict get $o -time]
        if {$safe} { set ip [interp create -safe] } else { set ip [interp create] }
        foreach {name prefix} [dict get $o -aliases] {
            interp alias $ip $name {} {*}$prefix
        }
        set ::tclutils::tutask::boxes([self]) 1
    }

    method interp {} { return $ip }

    # Evaluate synchronously under the limits. Limit errors become
    # {TCLUTILS TUTASK LIMIT COMMANDS|TIME}; other errors keep the child's
    # -errorcode.
    method eval {script} {
        if {$cmds > 0} {
            interp limit $ip command -value \
                [expr {[interp eval $ip {info cmdcount}] + $cmds}]
        }
        if {$ms > 0} {
            set t [expr {[clock milliseconds] + $ms}]
            interp limit $ip time -seconds [expr {$t / 1000}] \
                -milliseconds [expr {$t % 1000}]
        }
        set c [catch {interp eval $ip $script} r o]
        if {$cmds > 0} { interp limit $ip command -value {} }
        if {$ms > 0} { interp limit $ip time -seconds {} -milliseconds {} }
        if {$c == 1} {
            set ec [dict get $o -errorcode]
            if {[lrange $ec 0 1] eq {TCL LIMIT}} {
                ::tclutils::tutask::_err [list LIMIT [lindex $ec 2]] $r
            }
            return -code error -errorcode $ec -errorinfo [dict get $o -errorinfo] $r
        }
        return $r
    }

    # Operation: evaluate on the next event-loop turn. Cancel works until
    # it has started; once running, the limits bound it.
    method op {script} {
        return [list [namespace which my] _Start $script]
    }

    method _Start {script cb} {
        set id [after 0 [list [namespace which my] _Run $script $cb]]
        return [list after cancel $id]
    }

    method _Run {script cb} {
        if {[catch {my eval $script} r o]} {
            {*}$cb error $r $o
        } else {
            {*}$cb ok $r
        }
    }

    destructor {
        catch {interp delete $ip}
        unset -nocomplain ::tclutils::tutask::boxes([self])
    }
}

proc ::tclutils::tutask::sandbox {args} {
    return [::tclutils::tutask::Sandbox new {*}$args]
}

package provide tclutils::tutask 0.1
