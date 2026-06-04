# tclutils::tuopen

Open a URL or file path with the operating system's default application
(`xdg-open` on Linux/BSD, `open` on macOS, `cmd /c start` on Windows).

## API

```tcl
::tclutils::tuopen::launch https://tcl.tk/     ;# opens in the default browser
::tclutils::tuopen::launch /path/to/report.pdf  ;# opens in the default viewer
::tclutils::tuopen::command http://x -platform windows
#  -> cmd.exe /c start {} http://x
```

Commands:

- `launch target ?-platform p? ?-os o?` — open `target` (runs detached);
  returns the command used. Errors `{TCLUTILS TUOPEN LAUNCH}` on failure,
  `{TCLUTILS TUOPEN TARGET}` on an empty target.
- `command target ?-platform p? ?-os o?` — return the opener command without
  running it (handy for inspection and tests). `-platform`/`-os` override the
  autodetected `tcl_platform` values.

## Editing, folders and config paths

```tcl
::tclutils::tuopen::edit /path/to/notes.txt        ;# open in $EDITOR / notepad / TextEdit
::tclutils::tuopen::openDir /path/to/file.pdf      ;# open the containing folder
::tclutils::tuopen::configDir myapp                ;# per-user config directory
::tclutils::tuopen::configFile myapp settings.ini  ;# a file inside it
```

- `edit target ?-editor cmd? ?-platform p? ?-os o?` / `editCommand ...` — open in
  a text editor; `editCommand` returns the command without running it.
- `openDir target ?-platform p? ?-os o?` — open a directory in the file manager;
  if given an existing file, opens its containing folder.
- `configDir app ?-platform p? ?-os o?` — per-user config directory:
  `%APPDATA%\<app>` (Windows), `~/Library/Application Support/<app>` (macOS),
  `$XDG_CONFIG_HOME/<app>` else `~/.config/<app>` (Unix).
- `configFile app filename ?...?` — a path inside `configDir`.
