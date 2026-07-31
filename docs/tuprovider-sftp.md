# tuprovider::sftp -- SFTP provider

An SFTP backend for the `tuprovider` interface, built on the OpenSSH `sftp`
client run in batch mode (`sftp -b`).

There is no pure-Tcl SFTP client, so this adapter shells out to the system
`sftp` binary: each operation runs a small batch script and its output is
parsed. That keeps the dependency to something every SSH install already has,
and inherits OpenSSH's authentication (keys, agent, `known_hosts`) rather than
reimplementing it.

## Load

```tcl
tcl::tm::path add /path/to/tclutils/lib/tm
package require tclutils::tuprovider::sftp
```

Loading the package registers the `sftp` scheme with `tuprovider`.

## Open

```tcl
set p [::tclutils::tuprovider open sftp sftp://user@host/pub \
        -identity ~/.ssh/id_ed25519]
```

The URL is `sftp://[user@]host[:port][/base]`. Options after it:

- `-identity FILE`  ssh private key (passed as `-i`)
- `-port N`         port (overrides one given in the URL)
- `-sshopt {...}`   extra `-o` options for sftp, repeatable, e.g.
  `-sshopt {StrictHostKeyChecking=accept-new}`
- `-batchcmd CMD`   override the sftp executable (default `sftp`)

Authentication is OpenSSH's: use a key via `-identity` or an ssh-agent. The host
must be in `known_hosts` (or use `-sshopt {StrictHostKeyChecking=accept-new}` to
add it on first connect) -- because sftp runs non-interactively here, it cannot
prompt to accept an unknown host key.

## Capabilities

```
list stat get put delete mkdir move
```

`copy` is **not** reported: SFTP has no server-side copy. Copying a file is done
at the application level with get+put (a cross-provider copy does exactly this).
`move` maps to sftp's `rename`.

## Operations

- `list $path` -- runs `ls -l $path` over sftp and parses the Unix long
  listing. sftp prints the full path in the name column, so the leaf is taken
  with `file tail`.
- `stat $path` -- sftp's `ls` has no `-d`, so stat lists the PARENT directory
  and picks the matching entry (root `/` is reported as a directory).
- `get` / `put` -- transfer via a local temp file (sftp works on paths, not
  in-memory data), read/written back as bytes.
- `delete` -- tries `rm`, falls back to `rmdir` for directories.
- `mkdir` / `move` -- forward to sftp's `mkdir` / `rename`.

## Notes and limits

- **Whole-file transfers.** Plain sftp transfers whole files, so `head` uses the
  base default (get + truncate) -- a large-file preview reads the whole file.
- **`ls -l` format.** The common Unix long listing is assumed. The link-count
  column may be `?` on some servers; only the perms (field 1), size (field 5)
  and name (field 9+) columns are used, so that is fine.
- **One process per operation.** Each call spawns an sftp process. Fine for
  interactive browsing; a batch of many small operations pays per-call startup.

## See also

`tuprovider`, `tuprovider::ftp`, `tuprovider::dav`, `tuprovider::zip`
