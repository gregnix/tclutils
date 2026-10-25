# tclutils::tuwc

` tclutils::tuwc ` counts lines, words, characters and bytes.

## Load

```tcl
package require tclutils::tuwc
```

## Commands

```tcl
::tclutils::tuwc::text data
::tclutils::tuwc::file filename
```

## Result

Both commands return a dictionary:

```tcl
lines 10 words 42 chars 180 bytes 190
```

The `file` command additionally adds the key `file`.

| Key | Meaning |
|---|---|
| `lines` | number of `\n`, plus one when the text does not end in `\n` |
| `words` | runs of non-whitespace |
| `chars` | characters (code points) |
| `bytes` | `text`: length in UTF-8; `file`: size of the file in bytes |

`lines` differs from `wc -l`: a last line without `\n` counts. An empty text
has 0 lines, `"\n"` has one.

`file` reads with the system encoding and turns `\r\n` into `\n`; `lines`,
`words` and `chars` count that text. `bytes` is the file size on disk, as with
`wc -c`.
