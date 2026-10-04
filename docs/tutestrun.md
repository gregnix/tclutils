# tclutils::tutestrun

The shared `tests/all.tcl` of tclutils, tkutils and ctrlutils: run every
`*.test` of a directory in its own process and report what went wrong. Pure
Tcl, no Tk, Tcl 8.6+ / 9.x.

## API

```tcl
::tclutils::tutestrun::run dir libs ?-limit 120? ?-limitvar NAME? ?-argv list?
;# -> 0 all fine, 1 a file has problems
```

```tcl
# tests/all.tcl
set here [file dirname [file normalize [info script]]]
# ... find tutestrun-*.tm in the tree under test and source it ...
exit [::tclutils::tutestrun::run $here {tkutils tclutils} \
        -limitvar TKUTILS_TESTGRENZE -argv $argv]
```

Source the module file from the tree under test (own `lib/tm`,
`$env(TCLUTILS_TM)` or the sibling tclutils checkout), not with
`package require`: an installed older tclutils would otherwise provide the
runner. The `all.tcl` files of the three libraries show the lookup.

## What run does

1. **Own trees first.** `dir/../lib/tm` and the sibling checkouts of *libs*
   (or `$env(<LIB>_TM)`) are removed from `TCL<ver>_TM_PATH` for the test
   processes and put in front in this interpreter. A plain
   `tcl::tm::path add` does nothing for a tree that is already listed behind
   an installed copy of the same version -- that copy would be tested.
2. **Banner.** Where each of *libs* resolves (found without loading
   anything), other versions beside it, and which module-path variables are
   set.
3. **Each file in its own process** with *-argv* (tcltest options such as
   `-match`), under a wall-clock limit: `-limit` seconds, or the value of
   the environment variable named by `-limitvar`. A hung file is killed.
4. **Summary.** A file with failed tests, without tcltest summary line, with
   a non-zero exit or a hang is listed under "Files with problems". tcltest
   ends a file with exit code 0 even when tests failed, so the summary line
   is what counts.

Unknown options raise `{TCLUTILS TUTESTRUN OPTION <opt>}`.
