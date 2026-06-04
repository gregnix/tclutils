# tclutils::tulog

A small, dependency-free leveled logger. A logger is a **callable command
object**, so the level names `info`/`error` are subcommands rather than procs
that would shadow the Tcl built-ins.

## API

```tcl
set log [::tclutils::tulog::new -name app -level info -channel stderr]
$log info  "starting up"
$log debug "x = $x"        ;# suppressed while the level is info
$log warn  "low disk"
$log error "request failed"
$log log info "explicit level form"
$log setLevel debug         ;# raise verbosity
$log level                  ;# -> debug
$log destroy
```

Levels increase in severity: `debug` < `info` < `warn` < `error`; a message is
emitted only when its level is at least the logger's current level. Output is
`TIMESTAMP [LEVEL] name: message` (timestamp and name optional).

Options to `new`: `-channel` (default `stderr`), `-level` (default `info`),
`-name` (prefix, default `""`), `-timestamp` (default `1`).

`::tclutils::tulog::assert exprStr ?msg?` evaluates `exprStr` in the caller's
scope and raises `{TCLUTILS TULOG ASSERT}` if it is false -- a debug-time check.
