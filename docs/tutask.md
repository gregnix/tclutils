# tclutils::tutask

Tasks on coroutines: `await` with timeout, `cancel` that runs `finally`,
task groups, a thread pool and a sandbox. Pure Tcl; the pool needs the
Thread package and loads it on first use.

## Commands

`spawn`, `run`, `current`, `await`, `sleep`, `timer`, `onwrite`, `pipe`,
`group`, `pool`, `sandbox`, `tasks`, `stats` -- all in
`::tclutils::tutask`, exported for `namespace import`.

## The contract

A task is a coroutine owned by an object. Inside a task, `await` suspends
until an *operation* reports back; meanwhile the event loop keeps running.
Every operation is a command prefix (a *starter*):

```tcl
starter cb          ;# returns a cancel command (a prefix, may be "")
# later, exactly once:
{*}$cb ok value
{*}$cb error message ?options?
```

Built-in starters: `timer`, `pipe`, `onwrite`, `$task _Op` (via `wait`),
`$group` (via `wait`), `$pool op`, `$sandbox op`. Your own operations follow
the same two lines.

## Tasks

```tcl
namespace import ::tclutils::tutask::*

set t [spawn apply {{url} {
    set page [await [pipe [list curl -s $url]] -timeout 5000]
    return [string length $page]
}} https://example.org]

$t wait          ;# the value, or the task's error
$t destroy
```

- `spawn ?-detach 0|1? cmd ?arg ...?` → task object. The task runs at once
  up to its first `await`. A detached task destroys itself when done.
- `run ?-timeout ms? cmd ?arg ...?` → spawn, wait, destroy; the value. For
  scripts and tests.
- `current` → the running task, or `""`.
- `$t state` → `running`, `ok`, `error` or `cancelled`.
- `$t result` → the value; raises the task's error (with its `-errorcode`
  and `-errorinfo`), `CANCELLED`, or `NOTDONE` while running.
- `$t wait ?-timeout ms?` → inside a task: awaits; outside: blocks in
  `vwait`. A timeout cancels the task.
- `$t cancel` → 1 if the task was running. The task is resumed with a
  cancel request, so its `finally` clauses have run when `cancel` returns,
  and the operation it was awaiting is cancelled too. Called from inside the
  task, the request takes effect at the next `await`. A task that catches
  `CANCELLED` and awaits again is cancelled again.
- `$t ondone cmd` → `cmd` is called with the task appended when it is done.
- `$t destroy` → cancels a running task first. Not allowed from inside the
  task itself (`INSIDE`); use `cancel` there.

An error nobody collected (`result`, `wait`, `ondone`, a group) is reported
through `bgerror` when the task object is destroyed.

## Waiting inside a task

```tcl
await starter ?-timeout ms?
sleep ms
```

- `await` returns the operation's value or raises its error with the
  operation's own `-errorcode`. On timeout it calls the operation's cancel
  command and raises `{TCLUTILS TUTASK TIMEOUT}`.
- Only the first report of an operation counts. A late result after a
  timeout or cancel is dropped.
- `await` works in any coroutine; `cancel` needs a task.

## Operations

- `timer ms ?value?` → done after `ms` with `value`.
- `onwrite varName` → done when the variable is written; the value is its
  new content. For GUI waits: a button sets the variable.
- `pipe cmdlist ?-encoding enc? ?-profile p?` → runs the pipeline without
  blocking; the value is its output, stdout and stderr together. A non-zero
  exit raises Tcl's `{CHILDSTATUS pid code}`. Cancel kills the processes
  (`kill` on Unix, `taskkill /T /F` on Windows). On Unix only the processes
  of the pipeline itself: what they start in the background (`sh -c "x &"`)
  keeps running (measured 2026-10-20; `setsid` is planned, see the
  roadmap). `-profile` is Tcl 9 only.

## Groups

```tcl
set g [group]
$g spawn apply {{} { sleep 30; return a }}
$g spawn apply {{} { return b }}
$g wait                    ;# -> a b   (spawn order)
$g wait -mode first        ;# value of the first to finish; [$g winner]
$g destroy                 ;# destroys its tasks
```

- `-mode all` (default): all results in spawn order. The first error
  cancels the other tasks and is raised.
- `-mode first`: the first task to finish wins; the others are cancelled.
- Cancelling a task that awaits a group cancels the group's tasks.
- An empty group: `all` returns `{}`, `first` raises `EMPTY`.
- `$g tasks` lists the group's task objects.
- `$g destroy` right after `wait` is safe: callbacks of tasks cancelled by
  `-mode first` or by an error that arrive later are dropped.

## Pool (Thread package)

```tcl
set p [pool -size 4 -init {package require mylib}]
set v [await [$p op {mylib::rechne 42}] -timeout 10000]
$p stats                    ;# workers idle queued jobs
$p destroy
```

`-size` defaults to 2. Each job runs in a worker thread (own interpreter,
no shared variables).
Errors keep the worker's `-errorcode` and `-errorinfo`. Cancelling a
running job calls `thread::cancel`; the worker lives on. Destroying the
pool releases the workers; tasks still waiting get `CANCELLED`. Without
the Thread package `pool` raises `NOTHREAD`. If `-init` fails in a new
worker, the job's waiter gets `INIT`; nothing stays queued.

## Sandbox

```tcl
set s [sandbox -commands 100000 -time 2000 -aliases {log {my::log}}]
$s eval $script                 ;# synchronous
await [$s op $script]           ;# from a task, next event-loop turn
$s destroy
```

A safe interpreter (`-safe 0` for a normal one) with a command limit and a
time limit per evaluation. Exceeding one raises
`{TCLUTILS TUTASK LIMIT COMMANDS}` or `{TCLUTILS TUTASK LIMIT TIME}`; the
next evaluation starts with fresh limits. Other errors keep the child's
`-errorcode`. The script runs in the calling thread: `op` can be cancelled
until it starts, then the limits bound it. For real parallelism use a pool.
`$s interp` returns the child interpreter (to add aliases or variables).

The command limit counts commands. A loop whose body is empty, like
`while 1 {}`, executes none and is not stopped by `-commands`; only
`-time` ends it (measured with Tcl 8.6.14 and 9.0.4). Always set `-time` for
untrusted scripts.

## Leaks

`tasks` lists the live task objects; `stats` returns a dict
`tasks running awaits pipes pools sandboxes`. After a test run all of them
should be 0.

## In a Tk application

Use tasks from event handlers: `spawn` and return. Do not call `$t wait`
outside a task in a handler -- it runs a nested `vwait`, the same trap as
`vwait` in a callback. Inside a task, `wait` and `await` are fine.

## Errors

`{TCLUTILS TUTASK <REASON>}`: `CANCELLED`, `TIMEOUT`, `NOTASK` (await
outside a coroutine), `NOTDONE`, `OPTION`, `NOTHREAD`, `EMPTY`, `INIT`
(pool `-init` failed), `INSIDE`, `PROTOCOL`, and `LIMIT COMMANDS` /
`LIMIT TIME`.
