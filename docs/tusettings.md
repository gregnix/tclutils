# tclutils::tusettings

Per-user settings in the platform's config directory, the standard
directories (config, cache, data, temp) and a recent-files list. Settings are
stored as INI through `tuini`, so they can be read and edited by hand. Pure
Tcl, no Tk, Tcl 8.6+ / 9.x.

## API

```tcl
::tclutils::tusettings::dir  kind app ?-create 0|1?        ;# kind: config cache data temp
::tclutils::tusettings::file app ?name?                    ;# <config dir>/<name>.ini
::tclutils::tusettings::load app ?-defaults dict? ?-name settings?
::tclutils::tusettings::save app settings ?-name settings? ;# -> file path
::tclutils::tusettings::value settings section key ?default?

::tclutils::tusettings::recentAdd    app path ?-max 10? ?-list recent?
::tclutils::tusettings::recentList   app ?-existing 0|1? ?-list recent?
::tclutils::tusettings::recentRemove app path ?-list recent?
::tclutils::tusettings::recentClear  app ?-list recent?
```

```tcl
set s [tusettings::load etikettendruck -defaults {
    window  {width 800 height 600}
    printer {name ""}
}]
dict set s printer name Brother_QL-820NWB
tusettings::save etikettendruck $s
tusettings::recentAdd etikettendruck $csvFile
```

## Directories

| kind | Linux / BSD | Windows | macOS |
|---|---|---|---|
| config | `$XDG_CONFIG_HOME` or `~/.config` | `%APPDATA%` | `~/Library/Application Support` |
| cache | `$XDG_CACHE_HOME` or `~/.cache` | `%LOCALAPPDATA%` | `~/Library/Caches` |
| data | `$XDG_DATA_HOME` or `~/.local/share` | `%APPDATA%` | `~/Library/Application Support` |
| temp | `$TMPDIR` or `/tmp` | `%TEMP%` or `%TMP%` | `$TMPDIR` or `/tmp` |

The app name is appended. `dir` does not create anything unless `-create 1`;
`save` and `recentAdd` create the config directory themselves.

## Settings

A settings dict is section -> (dict key -> value); keys before any
`[section]` live in section `""`. `load` merges the file over `-defaults`,
so new keys in a later app version get their default. A missing file gives
the defaults.

`save` writes to a temporary file next to the target and renames it, so a
crash never leaves a half-written file. Comments a user put into the file
are not kept. INI cannot hold everything: a value with a line break or
leading/trailing blanks, a key with `=` or a key starting with `;`, `#` or
`[` raise `{TCLUTILS TUSETTINGS VALUE}` and the file stays as it was.

A file that does not parse (hand-edited, broken line) raises
`{TCLUTILS TUSETTINGS SYNTAX}` with the file name; the caller decides
whether to fall back to the defaults.

## Recent files

One plain text file per list (`<config dir>/<list>.txt`, one path per line,
UTF-8). `recentAdd` normalizes the path, moves it to the top, drops an older
entry for the same file (case-insensitive on Windows) and keeps `-max`
entries. `recentList -existing 1` leaves out files that are gone.

## Errors

`{TCLUTILS TUSETTINGS APP}` (app name empty or with path characters),
`{TCLUTILS TUSETTINGS KIND}`, `{TCLUTILS TUSETTINGS SYNTAX}`,
`{TCLUTILS TUSETTINGS VALUE}`; unknown options
`{TCLUTILS COMMON OPTION <opt>}`.
