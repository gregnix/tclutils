# tclutils::tuopen

Open a URL or file path with the operating system's default application
(`xdg-open` on Linux/BSD, `open` on macOS, `rundll32` / `cmd /c start` on
Windows).

## API

```tcl
::tclutils::tuopen::launch https://tcl.tk/     ;# opens in the default browser
::tclutils::tuopen::launch /path/to/report.pdf  ;# opens in the default viewer
::tclutils::tuopen::command http://x -platform windows
#  -> rundll32 url.dll,FileProtocolHandler http://x
::tclutils::tuopen::command C:/doc/a.pdf -platform windows
#  -> cmd.exe /c start {} C:/doc/a.pdf
```

On Windows a URL -- a target that starts with a scheme of two or more
characters and `:` (`https:`, `mailto:`, `file:`) -- is opened with
`rundll32 url.dll,FileProtocolHandler <url>`. That bypasses `cmd.exe`, which
would treat `&` in a query string as a command separator and cut the URL.
Anything else (files, folders, `C:/...`) goes to `cmd.exe /c start "" <path>`.

All seven commands (`launch`, `command`, `edit`, `editCommand`, `openDir`,
`configDir`, `configFile`) are exported for `namespace import`.

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
