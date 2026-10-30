# Changelog

## 0.69.0 - 2026-10-28

Recommended pairing: tclutils 0.69.0 + tkutils 0.49.0 + ctrlutils 0.5.

Module versions: `tucsv` 0.2, `tusqlite` 0.2, `tuholiday` 0.2, `tuzip` 0.2,
`tudiff` 0.2, `tubookmark` 0.3, `tuical` 0.2, `tuvcard` 0.2, `tuini` 0.2,
`tupatch` 0.3, `tusplit` 0.3, `tutee` 0.3, `tuldif` 0.3, `tumd` 0.2,
`tuiconv` 0.2, `tucat` 0.2, `tucsplit` 0.2, `tuhead` 0.2, `tutail` 0.2,
`tugrep` 0.2, `tustr` 0.3, `tuer` 0.4, `tugantt` 0.3, `tuxychart` 0.2,
`tusankey` 0.2, `tudate` 0.3, `tunumany` 0.3, `tubase64` 0.2, `tucrc` 0.2,
`tudav` 0.3, `tuflow` 0.4, `tuc4` 0.2, `tugit` 0.3, `turadar` 0.3,
`tusort`, `tuuniq`, `tucut`, `tujoin`, `tucolumn`, `tufmt` 0.2,
`tupaste`, `tushuf`, `tufold` 0.3, `tutestrun` 0.2, `tuarchitecture` 0.3,
`tustate`, `tublock` 0.2, `tunotes`, `tumindmap` 0.2, `common` 0.3,
`tused`, `tusettings`, `tuimage` 0.2, `tuprovider`, `tutreemap`, `tuclass` 0.3,
`tupacket`, `tujourney`, `tutimeline`, `tupie`, `tusequence` 0.3, `tukanban`,
`tuquadrant` 0.2, `tudiagram` 0.6, `tusvg` 0.4, `tupngdraw` 0.14, `tupng` 0.6,
`tuappinfo` 0.3; new
`tusysinfo`, `tuedid`, `tulint` 0.1. When copying over an older tree, delete
`tclutils-0.68.0.tm`, `tucsv-0.1.tm`, `tusqlite-0.1.tm`, `tuholiday-0.1.tm`,
`tuzip-0.1.tm`, `tudiff-0.1.tm`, `tubookmark-0.2.tm`, `tuical-0.1.tm`,
`tuvcard-0.1.tm`, `tuini-0.1.tm`, `tupatch-0.2.tm`, `tusplit-0.2.tm`,
`tutee-0.2.tm`, `tuldif-0.2.tm`, `tumd-0.1.tm`, `tuiconv-0.1.tm`,
`tucat-0.1.tm`, `tucsplit-0.1.tm`, `tuhead-0.1.tm`, `tutail-0.1.tm`,
`tugrep-0.1.3.tm`, `tustr-0.2.tm`, `tuer-0.3.tm`, `tugantt-0.2.tm`,
`tuxychart-0.1.tm`, `tusankey-0.1.tm`, `tudate-0.2.tm`, `tunumany-0.2.tm`,
`tubase64-0.1.tm`, `tucrc-0.1.tm`, `tudav-0.2.tm`, `tuflow-0.3.tm`,
`tuc4-0.1.tm`, `tugit-0.2.tm`, `turadar-0.2.tm`, `tusort-0.1.tm`,
`tuuniq-0.1.tm`, `tucut-0.1.tm`, `tupaste-0.2.tm`, `tujoin-0.1.2.tm`,
`tushuf-0.2.tm`, `tucolumn-0.1.tm`, `tufold-0.2.tm`, `tufmt-0.1.tm`,
`tutestrun-0.1.tm`, `tuarchitecture-0.2.tm`, `tustate-0.1.tm`,
`tublock-0.1.tm`, `tunotes-0.1.tm`, `tumindmap-0.1.tm`, `common-0.2.tm`, `tused-0.1.3.tm`,
`tusettings-0.1.tm`, `tuimage-0.1.tm`, `tuprovider-0.2.tm`, `tutreemap-0.2.tm`,
`tuclass-0.2.tm`, `tupacket-0.2.tm`, `tujourney-0.2.tm`, `tukanban-0.1.tm`,
`tutimeline-0.2.tm`, `tupie-0.2.tm`, `tuquadrant-0.1.tm`, `tusequence-0.2.tm`,
`tudiagram-0.5.tm`, `tusvg-0.3.tm`, `tupngdraw-0.13.tm`, `tupng-0.5.tm`,
`tuappinfo-0.2.tm`.

- `tucsv`: `-profile excel-de|rfc4180` for `text`, `file`, `writeFile`;
  `text -bom 1`; `file` and `writeFile` take `-encoding` (default utf-8);
  `writeFile` keeps the line ends of `-newline`. Tests `tucsv-3.1`–`3.6`.
- `tusqlite`: `rows` and `value` take a parameter dict (`:name`); caller
  variables no longer reach the query. New `update`, `delete` (refuse an
  empty WHERE dict). Tests `tusqlite-5.1`–`5.10`.
- New `tusysinfo`: OS, CPU, memory, model, disks and monitors on Linux,
  macOS and Windows; text report and JSON; serial numbers only on request.
  CLI `bin/tusysinfo.tcl`. In the umbrella.
- New `tuedid`: parse a monitor's EDID block. In the umbrella.
- `tuholiday`: `-sundays 0|1` for `holidays` and `isHoliday` (default 1:
  eleven days as before; 0: the nine statutory in all states). Doc no
  longer calls the eleven "nationwide". Tests `tuholiday-3.1`, `3.2`.
- `tusysinfo` doc: monitors describe the device (EDID), not the running
  mode, position or primary output.
- `tuzip`: member names written as UTF-8 with the UTF-8 flag (were Latin-1
  without flag; other programs misread them, `€` became `?`); reading
  takes `-encoding auto|ENC` (auto: UTF-8 if valid, else CP437; archives of
  0.1 with non-ASCII names: `-encoding iso8859-1`). Tests `tuzip-3.1`, `3.2`.
- `tubookmark`: `serialize` keeps the order of folders and links (sorted
  them, folders first); new key `folders` (list), so a folder name with `/`
  stays one folder; attribute values in single quotes or unquoted are read
  (`HREF='…'` gave an empty URL). Tests `tubookmark-3.1`–`3.3`.
- `tubookmark`: `<DD>` descriptions (key `description`) and the toolbar
  folder (`PERSONAL_TOOLBAR_FOLDER`, key `toolbar`) are read and written
  back. Tests `roundtrip-html-*`.
- `tuical`, `tuvcard`: `toIcs` and `toVcf` end the last line with CRLF too
  (RFC 5545/6350; was missing). Tests `roundtrip-ics-crlf`.
- `tuini`: `setValue`, `addSection` and `toIni` refuse a line break in a
  value, `=`/line break/leading `;#[`/outer blanks in a key, `]`/line
  break/outer blanks in a section name (`{TCLUTILS TUINI VALUE}`); `toIni`
  wrote such text and `parse` failed on it. Doc: last of two equal keys
  wins, outer blanks dropped. Tests `tuini-3.1`–`3.7`.
- `tupatch`: the final LF is kept; `\ No newline at end of file` handled as
  in `diff -u`; `parse` reports `oldNoNl`/`newNoNl`. Tests `tupatch-6.1`–`6.7`.
- `tusplit`: line parts keep their line ends, parts joined give the input;
  `file -lines` splits the bytes (CRLF, encoding stay); `splitLines
  -encoding` (default utf-8). Tests `tusplit-3.1`–`3.4`.
- `tutee`: `writeFile` copies bytes (CR and encoding were lost), returns the
  byte count. Doc: `write` appends LF unlike `tee`. Tests `tutee-3.1`, `3.2`.
- `tumd`: anchors as on GitHub (letters of all scripts, `_`, `-1`/`-2` for
  repeats); `Jörg` and `Jrg` both gave `jrg`. Tests `tumd-4.1`–`4.4`.
- `tuiconv`: strict on 8.6 and 9: `{TCLUTILS TUICONV UNMAPPABLE}`,
  `{TCLUTILS TUICONV INVALID}`; `-replace 1` substitutes (8.6 wrote `?`
  silently). Tests `tuiconv-3.1`–`3.5`.
- `tucat`: no number after the final LF; `files` numbers through as
  `cat -n`; unknown options are an error. Tests `tucat-2.1`–`2.5`.
- `tuldif`: binary attributes (`jpegPhoto`, `userCertificate`, `;binary`,
  `-binary`) keep their bytes; `toLdif` wrote them UTF-8 encoded. Tests
  `tuldif-4.1`–`4.6`.
- `tucsplit`: parts keep their line ends (were joined without LF);
  `-encoding`, `file` keeps CRLF. Tests `tucsplit-2.1`–`2.3`.
- `tuhead`, `tutail`: line ends kept as `head`/`tail`; `text` and `file`
  agree (`tail -n 1` of `a\nb\n` was empty); `{TCLUTILS TUHEAD|TUTAIL
  COUNT}`; `file -encoding`. Tests `tuhead-2.1`–`2.3`, `tutail-2.1`, `2.2`.
- `tugrep`: no empty line after the final LF; `file` keeps trailing empty
  lines. Tests `tugrep-9.1`, `9.2`.
- `tustr`: `toCamel`/`toSnake` with letters of all scripts (`jRgMLler`);
  `slugify` spells Latin letters in ASCII (`Jörg` -> `joerg`, was `j-rg`).
  Tests `tustr-9.1`–`9.3`.
- `tuer`: Unicode entity names; unknown lines raise `SYNTAX` (a block
  `Büro {` became an edge `string`–`PK`). Tests `tuer-9.1`–`9.3`.
- `tugantt`: unknown duration unit raises `DURATION` (was length 0); ids
  with umlauts; unit `ms`. Tests `tugantt-9.1`–`9.3`.
- `tuxychart`: series length must match the x-axis labels (`COUNT`).
  Tests `tuxychart-9.1`, `9.2`.
- `tusankey`: bad rows raise `VALUE` (were skipped); rows with 0 still
  skipped. Test `tusankey-1.8`.
- Doc: `tujson` and `tuurl parseQuery` keep the last of two equal keys;
  `tuldif` drops comments.
- New `tests/roundtrip.test` with files in `tests/data/roundtrip`
  (calendar, contacts, bookmarks): read, write, read again, compare.
- `tudiff`: `-eol ignore|strict` (default ignore; `text` now also ignores
  CR in strings, as `files` did) and `-encoding` for the file commands;
  strict shows a missing final newline as GNU diff. Tests `tudiff-3.1`–`3.4`.
- `tools/check-modules.md`: example output without a personal path.
- `tudate`: a day or month that does not exist (`2026-02-29`,
  `31.04.2026`, `Feb 30 2026`) is `PARSE` on 8.6 too (rolled over to the
  next month); `m/d/Y` after `d/m/Y`; more formats (no seconds,
  `YYYYMMDD`, time only, English month names). Tests `tudate-7.1`–`7.5`.
- `tunumany`: decimal comma before the unit (`1,5K` = 1500); `1,500K`
  does not parse. Tests `tunumany-4.1`, `4.2`.
- `tubase64`, `tucrc`: `-encoding binary|utf-8` (default binary); a
  character above 255 is `BYTES` on 8.6 too (low byte kept).
  `tubase64::decode -encoding utf-8`. Tests `tubase64-2.*`, `tucrc-2.*`.
- `tudav`: Basic authentication as UTF-8 (RFC 7617). Test `tudav-1.2`.
- `tuflow`, `tuc4`: ids with Unicode letters (`Büro[Amt]` was dropped,
  `größe` became `gr`). Tests `tuflow-9.1`, `tuc4-9.1`.
- `tugit`: a commit id used twice is `DUPID` (self edge before);
  generated ids skip used ones. Tests `tugit-9.1`–`9.3`.
- `turadar`: one value per axis, else `COUNT` or `AXIS` (missing values
  were 0, extra or misspelled keys dropped). Tests `turadar-1.9`, `2.6`–`2.8`.
- `tusort`, `tuuniq`, `tucut`, `tupaste`, `tujoin`, `tushuf`, `tucolumn`,
  `tufold`, `tufmt`: text output ends with LF exactly when the input does
  (was always dropped). `bin/tusort.tcl`, `bin/tuuniq.tcl` print the
  result as is (`tuuniq` split lines as a list). Tests `*-9.1`.
- Doc: `tunumfmt` and `tusize` name the base of `K` and `KiB`.
- `man/man1`: `.TH` 0.69.0.
- `tutestrun` 0.2: starts each test file with `-encoding utf-8`; under
  Tcl 8.6 with cp1252 (Windows) 19 tests failed on mojibake in expected
  values. Test `tutestrun-1.9`.
- `tests/tusysinfo.test`: the fake registry does not provide a second
  `registry` version where the real package is loaded (Windows); cleanup
  undoes only what the setup did.
- `tusysinfo`: a monitor without status is not connected; no or an
  unreadable PowerShell answer gives `warnings` (and a report section)
  instead of empty memory, disks and monitors. Test `tusysinfo-9.1`.
- `tuical`, `tuvcard`: folding at 75 octets, not characters; `BEGIN`/`END`
  in any case; `;` and `:` in quoted parameter values; `setProperty`,
  `addProperty` refuse a line break (`VALUE`). `tuvcard`: a group prefix
  (`item1.FN`) counts for the name. Tests `tuical-9.*`, `tuvcard-9.*`.
- `tuflow`: `;` inside a label, an edge label or quotes does not split the
  statement. Test `tuflow-9.2`.
- `tudav`: status and properties from the 2xx `propstat`; weak ETags kept,
  `If-Match` quoted; `_caldavTime` refuses a day that does not exist on
  8.6; `.` and `..` in an href are resolved. Tests `tudav-10.*`.
- `tuarchitecture`, `tustate`, `tublock`: ids with Unicode letters. Tests
  `*-9.1`.
- `tusqlite::value`: options `-default` and `-params` (positional forms
  still work). Tests `tusqlite-5.11`, `5.12`.
- `tunotes`: `save` writes UTF-8 (was the system encoding); `load` reads
  UTF-8 and falls back to the system encoding for older files. Tests
  `tunotes-9.1`, `9.2`.
- `tumindmap`: an id with Unicode letters before a shape is dropped (was
  kept as text). Test `tumindmap-9.1`.
- New `tulint`: static checks for Tcl sources, findings as data; rules
  `ENC-1`, `ENC-2`, `ENC-3`, `TST-3`; own rules with `register`. CLI
  `bin/tulint.tcl` (exit 1 on an error finding). Not in the umbrella.
  Rule `DAT-2` (info): `open` with a truncating mode. Tests `tulint-*`.
- `common` 0.3: `replaceFile` writes through a temporary file; a failed
  write leaves the old file, no temp file and no open channel. Test
  `common-9.1`, `9.2`.
- Written with `replaceFile` (old file kept on a failed write; was empty
  with an open channel): `tused::processFile`, `tuprovider` local `put`,
  `writeSvg`/`writePng` of `tugantt`, `turadar`, `tusankey`, `tuxychart`,
  `tutreemap`; `tusettings` removes its temp file. Tests `*-9.1`,
  `tugantt-10.1`, `tuxychart-10.1`.
- Also with `replaceFile`: `common::writeFile` (modes `w`, `wb`; so
  `tunotes::save`, `tujson::filePretty`/`fileMinify`), `tucsv::writeFile`,
  `tuiconv::writeFile`, `writeSvg`/`writePng` of `tuflow`, `tupacket`,
  `tujourney`, `tukanban`, `tutimeline`, `tupie`, `tuquadrant`,
  `tusequence`, `tudiagram`, `tusvg` `write`, `tupngdraw` `write`, `tupng`
  `write*`, `tuappinfo::writeLog` (now UTF-8). Tests `*-9.1`, `*-9.2`,
  `tuflow-9.3`/`9.4`, `tudiagram-12.*`, `tupngdraw-15.1`, `common-9.3`/`9.4`.
- `tools/setup.md`: example folders `tclutils-0.69.0`, `tkutils-0.49.0`
  (were 0.58.0 and 0.41.0). `tusqlite` doc: example with `value -default`;
  the trap of the positional form.
- `tuappinfo`: the Tk line shows the patch level (`9.0.4`, was `9.0`); the
  demo tracks the module file. Test `tkpatch-1`.
- `tutreemap`: a `:::class` name with umlauts is removed whole (was cut
  after the first letter). `tuclass`: `;` inside quotes stays in the
  member. `tuimage::fromDataUri`: `;base64` inside a quoted parameter is
  not the base64 flag. Tests `tutreemap-9.2`, `tuclass-9.1`, `tuimage-9.1`.

## 0.68.0 - 2026-10-24

Fixes found while writing and checking the tclutils book. 76 modules get a
new version; every fix has a regression test. Tests: 2355 (was 1995),
0 failures under Tcl 8.6.14 and 9.0.4 (Linux), `tests/all.tcl` also passes
on Windows and macOS. The manual ships as PDF in German and English.
Recommended pairing: tclutils 0.68.0 + tkutils 0.47.0 + ctrlutils 0.4.

Module versions -- delete the old file when copying over an older tree
(e.g. `tuawk-0.1.tm` next to `tuawk-0.2.tm`), and `tclutils-0.67.0.tm`:
0.1 -> 0.2: `tuagrep tuappinfo tuarchitecture tuawk tubase32 tubookmark
tucal tuclass tucmp tucode tucolor tucomm tudeploy tudhash tuexe tuexpand
tufile tufind tufold tufuzzy tugantt tugit tuhexdump tuhexedit tuico
tujourney tulayout tuldif tulog tummdb tunl tunotesdb tunumany tunumfmt tuod
tuopen tupacket tupagespec tupaste tupatch tupie tupngpad tuprovider
tuprovider::sftp turadar turrule tuseq tusequence tushuf tusize tusparql
tusplit tustat tustrings tutable tutablepng tutdbc tutee tuterm tutimeline
tutr tutreemap tutsort tuvalidate tuwc tuxxhash`; `tuer` 0.3, `tuflow` 0.3,
`tusvg` 0.3, `tuzipfs` 0.3, `tudiagram` 0.5, `tumonthpng` 0.5, `tupng` 0.5,
`tupngdraw` 0.13, `tujoin` 0.1.2, `tugrep` 0.1.3. The umbrella requires the
new versions.

### Changed behaviour

- `tucmp`: `data` compares bytes; characters above 255 raise `BYTES`.
- `tuxxhash`: text is hashed as UTF-8 (as `tuhash`); `-encoding binary` for
  raw bytes.
- `tustat`, `tusize`: a symbolic link is reported with its own data
  (`lstat`); `tustat` adds `target`.
- `tuwc`: `file` reports `bytes` as the file size.
- `tucal`: `year` runs the months row-wise like `cal`.
- `tubase32`: `decode` is strict (RFC 4648): `LENGTH`, `BITS`.
- `tuldif`: base64 values are UTF-8; `changetype:` raises `CHANGETYPE`.
- `turrule`: `YEARLY` with `BYMONTH`/`BYDAY`/`BYMONTHDAY`;
  `BYDAY`+`BYMONTHDAY` intersect; a date-only `UNTIL` includes the day;
  unsupported parts raise `UNSUPPORTED`.
- `tuhexedit`: no write past the end of the file (`RANGE`).
- `tucomm`: `-sort 1` sorts in the order the comparison uses.
- `tuagrep`: `search` has no empty last line; `-filenames` ignored for text.
- `tuexpand`: `unexpand` as GNU; `expand` rejects `-all`. `tuseq`: `range`
  rejects `-separator`.
- `tutr`: descending ranges and empty set2 are errors; the last mapping
  wins.
- `tustrings`: `-encoding` removed. `tujoin`: new error messages.
- `tucode`: `lookup` of a character above 255 raises `LOOKUP` on 8.6 too.
- `tucolor`: triples decimal; `fromHsv` checks ranges (negative hue is an
  error).
- `tumonthpng`: header follows `-firstweekday`; `-weekdays` always Monday
  first.
- `tupngpad`: unknown `-align` is an error.
- `tuterm`: `enable` takes booleans only.
- `tulayout`: `ensureBlocks` takes `w`/`h` from the definitions; unknown
  options are errors.
- `tuappinfo`: `-anonymize` hides every path.
- `tuvalidate`: `port` decimal digits only; `ipv4` rejects leading zeros.
- `tuopen`: on Windows URLs go through `rundll32`.
- `tuflow`: case-insensitive header, `A & B --> C`, `sankey` rejected by
  `parse`.
- `tudiagram`: titles are drawn (26 px band); unknown theme raises `THEME`.
- `tusequence`: title drawn; `<<->>` arrows.
- `turadar`: legend only with named curves. `tutreemap`: values <= 0
  dropped.
- `tupie`: `1e3` accepted, negative values raise `VALUE`.
- `tujourney`: fractional scores accepted, others raise `VALUE`.
- `tutimeline`: splits at `: ` only (`12:30` stays whole).
- `tugantt`: no start date raises `DATE` (8.6 too); automatic height.

### Fixes

- Line filters: `tunl` checks `-start`/`-increment`/`-width`; `tutable`
  `COLUMNS`/`HEADERS`, markdown columns at least 3 wide; `tufold -words 1`
  drops trailing blanks; `tushuf`/`tuseq` take 64-bit values on 8.6;
  `tuseq text` finds options anywhere.
- Pipelines: `tuawk` rules run in a private frame (8.6 no longer touches
  globals), `NR`/`NF` start at 0; `tutee` closes channels when an open
  fails; `tutsort` names only cycle nodes; error codes in `tupaste`,
  `tujoin`, `tufuzzy`, `tuagrep`, `tusplit` (`BYTES` in `splitBytes`).
- Binary: `tucode signs` options, `lookup U+00E4`, aligned tables;
  `tuhexdump`, `tuod`, `tustrings` check options and raise `BYTES`;
  `tuhexedit` `OFFSET`/`ENCODING`; `tusize human` up to YiB;
  `tustat modeOctal`.
- Images: `tutablepng` keeps cell text (`4.80`); `tusvg` method `icon`
  emits valid SVG, `icons` lists 149 names; `tupngdraw paste` composites
  alpha; `tupng` honours `tRNS` for RGB and checks CRCs; `tuico` reads
  counts unsigned; `tumonthpng -title` for quarter/year; `tudhash` checks
  dimensions.
- Application: `tuterm names reset`; `tupagespec` decimal on 8.6;
  `tulayout pageSize` checks; `tuzipfs rcopy` copies dot files;
  `tudeploy addModulePaths` skips refused roots; `tulog`, `tunumany`,
  `tuexe` reject options without value; `tunumfmt` reads `KiB` as IEC;
  `tuopen` exports all commands.
- Data and calendars: `tunotesdb fromStore` keeps children, allows child
  before parent; `tubookmark` escapes attributes, one bookmark per `<A>`;
  `tusparql` endpoint with `?`, one `Accept`, all variables; `tupatch`
  checks booleans; `tucal` titles centred.
- Diagrams: `tuclass` one-line blocks and cardinalities; `tuer` quoted
  labels; `tugantt` unique axis ticks.
- Tests run directly under a non-UTF-8 system encoding (Tcl 8.6 on
  Windows): non-ASCII characters in `tupdftext`, `tucmp`, `tucode`,
  `tuhexdump`, `tuhexedit`, `tuod`, `tustrings`, `tuwc` tests written as
  `\uXXXX`; `cli-1.6` expects the file size on disk (CRLF files).
- `tutask-2.8w`, `4.4w` (Windows): read `ping` with `-encoding iso8859-1`;
  German `ping` writes cp850, which fails the strict cp1252 read on Tcl 9.
  `docs/tutask.md` explains `-encoding cp850` for console programs.
- Docs and man pages updated for all changed modules; `docs/tukanban.md`
  and other diagram docs: SVG `-scale` corrected.

### Text that looks like a number

`expr {c ? a : b}` returns a number-like branch in canonical form (`010` ->
`8`/`10`, `5.10` -> `5.1`, `1e3` -> `1000.0`, `0x1F` -> `31`); where a branch
is text, the choice is now made with `if`, which keeps the value unchanged.

- `tuagrep` 0.2: `file -fileswithmatches` file name.
- `tuarchitecture` 0.1 -> 0.2: node and group label falling back to the id.
- `tudiagram` 0.5: title (layout, render), `-fontfile`, group chains in
  the cluster layout.
- `tufile` 0.1 -> 0.2: `type`, `mime`.
- `tufind` 0.1 -> 0.2: `-tails` name.
- `tugit` 0.1 -> 0.2: commit id as label, label falling back to the id.
- `tugrep` 0.1.2 -> 0.1.3: `file -fileswithmatches` file name.
- `tummdb` 0.1 -> 0.2: IPv6 groups next to `::` (`1e3`, `0010`). Also
  `::` was split at every `:`, so `2001:db8::1` and `::1` expanded wrong
  and IPv6 lookups hit the wrong address.
- `tumonthpng` 0.5: `-title` of `render`.
- `tupacket` 0.1 -> 0.2: field label.
- `tupagespec` 0.2: single pages in `compact`.
- `tupng` 0.5: `tRNS` bytes of `encodeIndexed`.
- `tuprovider` 0.1 -> 0.2: `head` content of the local provider.
- `tuprovider::sftp` 0.1 -> 0.2: host in the sftp target, `TMPDIR`.
- `turadar` 0.2: curve label falling back to the id.
- `tusequence` 0.2: participant label falling back to the id, title.
- `tusparql` 0.2: head vars (a single variable such as `010`).
- `tutdbc` 0.1 -> 0.2: column values in `rows` (`01234`, `5.10`).

### Manual

- `man/man1`: pages for the wrappers `tuawk`, `tucal`, `tucode`, `tufile`,
  `tupngpad`; every `.TH` says 0.68.0; `tuzipfs.1` had an empty NAME
  section (the line started with a dot). `man/mann/tummdb.man` (doctools)
  says 0.2 / `tubin` 0.3. `docs/tudiagram.md` lists all non-graph kinds.
- `tests/cli.test`: the fixture directory is `cli-<pid>`, so two suites
  running in the same tree no longer remove each other's files.
- `docs/handbook/de/Tclutils-de.pdf` and `docs/handbook/en/Tclutils-en.pdf`:
  the tclutils manual in German and English (built with bookkit from the
  book sources, 0.68.0); listed in `README.md` and
  `docs/guide/guide-tclutils.md`.

## 0.67.0 - 2026-10-21

New module `tupdftext` 0.1: the text of a PDF, page by page, in pure Tcl.
Recommended pairing: tclutils 0.67.0 + tkutils 0.47.0 + ctrlutils 0.4
(tkutils and ctrlutils need nothing from this release).

- `tupdftext::pages file ?-notext error|empty?`, `text file ?-separator s?`,
  `summary file`. Reads objects by scanning (a damaged cross-reference table
  does no harm), object streams, filters Flate (with PNG predictor),
  ASCIIHex, ASCII85, LZW, the page tree with inherited resources, Form
  XObjects, fonts Type0/Type1/TrueType/Type3 with `/ToUnicode` or
  `/Encoding` and `/Differences`. Spaces and line breaks come from the glyph
  positions. Errors `{TCLUTILS TUPDFTEXT FILE|FORMAT|ENCRYPTED|NOTEXT|OPTION}`.
- Measured against pdftotext on 13 PDFs (pdf4tcl, LibreOffice, PowerPoint,
  TeX, qpdf object streams): 99.5-100 % of the words on all but two math
  test pages (91 %); table in `docs/tupdftext.md`. Tcl 8.6.14 and 9.0.4 give
  the same text.
- `bin/tupdf.tcl text file.pdf ?-page N?` prints the text (form feed between
  pages, as pdftotext). Tests `cli-1.16a`-`c`.
- In the umbrella. Tests `tupdftext.test` (33, one needs pdf4tcl).
- The public command is `summary`, not `info`: a proc `info` in the module's
  namespace would hide Tcl's `info` from every proc of the module.

## 0.66.0 - 2026-10-20

Fixes found while checking the tool book against the code. Recommended
pairing: tclutils 0.66.0 + tkutils 0.47.0 + ctrlutils 0.4.

Module version: `tutask` 0.2 (file `tutask-0.2.tm`; delete `tutask-0.1.tm`
when copying over an older tree).

- `tutask`: requires `tclutils::common 0.2` (was 0.1). `group` and `pool`
  use `ensureOneOf`/`ensurePositiveInteger` from 0.2; with an older common on
  the path they failed later.
- `tutask` pool: a failed constructor (no Thread, `-size 0`) no longer adds a
  bgerror `can't read "jobs"`; the state is set before the checks.
- `tutask` pool: if `-init` fails in a new worker, the waiting job is taken
  out of the queue and its waiter gets `INIT`. Before, it stayed queued
  (`stats`: `queued 1 jobs 1`).
- `tutask` group: destroying a group right after `wait` no longer leaves a
  bgerror `invalid command name ...::my` from late callbacks of cancelled
  tasks.
- Tests: `tutask-7.3a`, `-8.9`, `-8.10` (67 tests).
- Docs: `docs/tutask.md` names `-size` default 2, `$g tasks`, `$s interp`,
  that `pipe` cancel on Unix does not reach background grandchildren, and
  that `-commands` does not stop an empty loop (use `-time`). README names
  Thread for the `tutask` pool. `tupath` comment, roadmap test count.

- `tutask`: `-timeout` is checked the same way everywhere. `run -timeout`,
  `$t wait -timeout` and `$g wait -timeout` outside a task took "abc" or -5
  silently; now `{TCLUTILS TUTASK OPTION}` as in `await`. `run` checks before
  spawning, so a bad value leaves no task. Test `tutask-1.20` (68 tests).

## 0.65.0 - 2026-10-06

Recommended pairing: tclutils 0.65.0 + tkutils 0.46.0 + ctrlutils 0.3.

- `tutask` 0.1 (new): tasks on coroutines. `await` with timeout,
  `cancel` that runs the task's `finally` and cancels the awaited
  operation, groups (`all` fail-fast, `first`), a thread pool (Thread
  package, loaded on first use) and a sandbox (safe interp with command
  and time limits). Operations: `timer`, `pipe` (kills on cancel),
  `onwrite`. Errors keep their code across tasks, threads and interps;
  uncollected errors go to `bgerror`. Loaded by the umbrella.
- `tutask` tests 2.8w/4.4w: `pipe` cancel and timeout on Windows
  (`taskkill /T /F`, child `ping`), verified with Tcl 8.6.17.

## 0.64.0

Recommended pairing: tclutils 0.64.0 + tkutils 0.46.0 + ctrlutils 0.3.

- `tustr` 0.2: `graphemes` (user-perceived characters, simplified UAX #29)
  and `isPrintable` (Unicode, not only ASCII). Surrogate pairs from Tcl 8.6
  count as one character.
- `tudate` 0.2: `zones` lists the time zones `clock` accepts.
- `tusettings` 0.1 (new): per-user settings as INI in the platform's config
  directory, `dir config|cache|data|temp`, recent-files list. Doc, man page
  and module header use the fully qualified `::tclutils::tusettings::...` in
  examples (the short form only resolves inside `namespace eval ::tclutils`).
- `tutestrun` 0.1 (new): the shared `tests/all.tcl` (own trees first, banner,
  per-file limit, summary). tclutils, tkutils and ctrlutils use it; the
  tclutils runner now passes tcltest options and lists problem files.
- `tunum` 0.4: `format` rounds half away from zero on every platform
  (`1234.5 -decimals 0` is `1.235`); `format %.*f` rounded differently on
  Windows.
- `tupath::clean`: an absolute path keeps its root (`C:/` on Windows), `..`
  stops there.
- Tests run on Windows: no `/dev/null` or Unix roots in fixtures, `cli-1.10`
  copies binary; `tuhttps`/`tufetch` tests that need a CA bundle are skipped
  without one (constraint `caOK`). The TLS tests in `tufetch.test` are
  renumbered 4.x (3.x was used twice).
- `tutestrun`: output a test file writes in another encoding no longer stalls
  the run under Tcl 9 (the file ran into the limit); such bytes are replaced.
- `tupkgfinder` 0.2: `candidates` and `shadows` list every copy of a package
  on the module paths and `auto_path`, including a second copy with the same
  version, which the package database does not show.

## 0.63.0

Security and robustness release. Recommended pairing: tclutils 0.63.0 +
tkutils 0.46.0 + ctrlutils 0.3.

### Tests / runner (2026-10-03)

- `tupostgrest.test` pg-1.1: umlaut via `\u00fc` in `[list …]` so Tcl 8.6 with
  iso8859-1 / cp1252 script encoding does not double-encode the URL.
- `tests/all.tcl`: per-file wall-clock limit (`TCLUTILS_TESTGRENZE`, default 120 s).

### `tuflow`: hyphen in a node id is `BADID` (2026-09-24)

Node ids stay `[A-Za-z0-9_]+`. A leftover `-3` after an id (e.g.
`Nwifi-3["SSID"]`) used to be swallowed: the graph kept `Nwifi` and dropped
the rest, with no error. `parse` now raises `{TCLUTILS TUFLOW BADID}` and
names the id plus the allowed alphabet. Underscore ids (`Nwifi_3`) are
unchanged. Package remains `tclutils::tuflow` 0.2.

### Caps contract (2026-09-23)

`docs/tuprovider.md` holds one table of `caps` per scheme (local / zip / dav /
ftp / sftp). `tests/tuprovider-caps.test` reads that table. SFTP `head` stays
the base default (full `get`, then truncate): OpenSSH `sftp get [-afpR]` has
no byte range.

### The test runner says where the modules come from

Before the tests run, `tests/all.tcl` prints which file each library
(tclutils) resolves to -- found without loading anything -- and which
module-path variables are set; an old file beside a new one shows as
`(also: <version>)`. (Idea 5 of ideen-tclutils-tkutils.md.)

Own trees first: when the tree is already listed in `TCL8_6_TM_PATH` /
`TCL9_0_TM_PATH` behind a directory with an installed copy of the same version
(e.g. `site-tcl`), `tcl::tm::path add` does nothing and the installed copy
wins -- the suite then tests that copy, not the tree (reproduced with Tcl 8.6:
`TCL8_6_TM_PATH=<tree>:<site-tcl>`). The runner now removes its own trees from
those variables for the test processes and puts them in front in its own
interpreter, so the banner shows what the tests load. A test file started
directly, without the runner, is still exposed to this.

### `common::ensureOneOf` (in `common` 0.2)

`ensureOneOf value allowed what` returns the value or raises
`unknown <what>: <value>` / `Known: ...` with `{TCLUTILS COMMON VALUE <what>}`
-- the enum counterpart to `parseOptions` (idea 2). `common` was already
counted up to 0.2 in this release.

### Security: HTTPS certificates are verified again — and the check stays local

Measured 2026-09-19 against a local self-signed server: after **one**
`tufetch` call, every later `::http::geturl https://…` in the process accepted
the forged certificate. `::http::register` is global to the interpreter, and
three modules each registered `https` with their own policy and never undid it:

| module | registered | verified? |
|---|---|---|
| `tufetch` 0.3 | on every call | no (`-require 0`) |
| `tupostgrest` 0.1 | on every request | yes, unless `-insecure 1` |
| `tudav` 0.1 | once, for good | tls 2.0 yes; **tls 1.x (Tcl 8.6) never** |

- **`tuhttps` 0.1 (new)** — one place for the rule. `socketCmd` builds a
  verifying `::tls::socket` prefix (`-insecure 1` is the only way to switch the
  check off; `-cafile` for an internal CA; no SNI for IP literals). `with`
  registers `https` only for the duration of a script and restores the previous
  registration afterwards, also on error. tls 1.x does not find the system CA
  store by itself; `socketCmd` then looks for a CA bundle (`SSL_CERT_FILE`, the
  usual Linux/BSD/macOS paths) and raises `NOCA` with the way out if there is
  none — it never falls back to "unverified".
- **`tufetch` 0.4** — verifies on all three transports; `-insecure 0|1` and
  `-cafile` now apply to native, curl (`-k`/`--cacert`) and wget
  (`--no-check-certificate`/`--ca-certificate`) alike. A `CONNECT` error on
  https names `-cafile`/`-insecure`. tls 1.x without a CA bundle: the native
  path steps aside for curl/wget; with neither, `NOMETHOD` names the way out.
  New errorcode `{TCLUTILS TUFETCH CAFILE}`.
  Also fixed: the wget fallback passed each header as two arguments
  (`--header=Name:` and the value), so wget took the value for a second URL.
  The old test matched the joined list as a string and stayed green.
- **`tudav` 0.2** — client and `configure` take `-cafile` and `-insecure`;
  https is registered per request. `configure` lists the known options on an
  unknown one.
- **`tupostgrest` 0.2** — `-cafile` added; `-insecure` now affects only that
  client's requests. `new` lists the known options on an unknown one and checks
  that `-insecure` is a boolean.
- `tuprovider::dav` passes `-cafile`/`-insecure` through to `tudav`.

**Behaviour change.** Code that relied on a self-signed or internal certificate
being accepted silently now gets an error that suggests `-cafile` (preferred)
or `-insecure 1`. On Tcl 8.6 with tls 1.x and no CA bundle (typical on
Windows), `tudav` and `tupostgrest` fail with the way out in the message, and
`tufetch` uses curl/wget or fails with `NOMETHOD`. Not measured: tls 2.0 on
Windows; if its OpenSSL build finds no CA store the handshake fails loudly and
`-cafile` is the way out.

Tests run offline: `tests/data/https-server.tcl` serves a self-signed
certificate (`tests/data/tuhttps-localhost.crt`, test use only) from a child
process — in the test's own interpreter the blocking tls handshake hung. Each
new test was run against the previous module version first: `tufetch` 10,
`tudav` 5 (under 8.6 the old `tudav` accepted the forged certificate),
`tupostgrest` 4 failures.

### The umbrella loads without tcllib again (`tuprovider::ftp` 0.2)

`tuprovider::ftp` did `package require ftp` (tcllib) when it was loaded, and
the umbrella loads it — so `package require tclutils` failed on every system
without tcllib, against CONTRIBUTING rule 1. Found 2026-09-19 because
tkutils' `stack.test` exited 1 under Tcl 8.6 (no tcllib in that environment);
under 9.0 tcllib was installed and nothing showed. The tcllib client is now
loaded when a connection is opened; without it, `open ftp …` fails with
`{TCLUTILS TUPROVIDER FTP NOPKG}` and says what is missing. A new test checks
in a fresh process that loading the provider does not load `ftp`; against 0.1
it fails, with or without tcllib installed.

### Every module has a description and a category

8 modules had neither a `# Description:` nor a `# Category:` header line, so
`tools/check-modules.tcl` and its GUI showed empty columns for them (the storage providers, `tuico`, `tudhash`, `tuxxhash`).
Added, with categories from the existing list. `tests/headers.test` (new)
fails when a module lacks either line (counter-checked by removing one).

### `tools/md2man.tcl`: sub-modules

`md2man.tcl` converts only docs that belong to a module, and looked for the
module as `lib/tm/<repo>/<mod>-X.Y.tm` only. The docs of sub-modules
(`docs/tuprovider-ftp.md` for `lib/tm/tclutils/tuprovider/ftp-0.2.tm`) counted
as "no module" and were skipped without a word — hence the missing man pages
for `tuprovider-ftp` and `tuprovider-sftp` (and stale ones for `-dav`/`-zip`),
the same gap `check-modules.tcl` had. It now also tries
`lib/tm/<repo>/<parent>/<child>-X.Y.tm`. Measured into a scratch directory:
136 pages before, 140 after, `tuprovider-ftp.n` with `.TH … 0.2`.

### `tools/check-modules.tcl`: sub-modules

For modules in a sub-directory (`lib/tm/tclutils/tuprovider/dav-0.1.tm`) the
manifest rebuilt the path as `lib/tm/tclutils/tuprovider-dav-0.1.tm`, which
does not exist. Description, category and dependencies of the four provider
backends therefore came out empty — also after the header lines were added —,
the path column was wrong, and the package column said
`tclutils::tuprovider-dav` instead of `tclutils::tuprovider::dav`. The GUI
opens the module from that path, so a click on such a row pointed at a missing
file. The tool now keeps the real file and package name of every module. The
human report is unchanged; in the manifest only the four provider rows change.
Checked: every manifest path in tclutils, tkutils and ctrlutils exists, and
the GUI shows the category of all five providers and opens
`tuprovider/dav-0.1.tm`.

### One version per module

`tests/versions.test` (new) checks that the version in the file name, in
`package provide` and in `variable version` agree. Five modules had a stale
`variable version`: `tumonthpng` (0.3 in a 0.4 file), `tupng` (0.2 / 0.4),
`tupngdraw` (0.11 / 0.12), `tufind` (0.1.3 / 0.1), `tudiff` (0.1.2 / 0.1). They
now say what `package provide` says. Nothing reads the variable. The test does
not look for old files lying next to new ones; `tools/check-modules.tcl`
reports those as multi-version.

### Documentation

`docs/guide/architecture.md` knows the storage providers (new section, with
the model/view/controller split of the Explorer stack), `tuhttps`,
`tupostgrest`, `tutdbc` and the hash modules `tudhash`/`tuxxhash`.

### `common` 0.2

- `parseOptions` names the known options on an unknown one:
  `unknown option "-typ"` / `Known: -type -timeout`. The errorcode is
  unchanged (`{TCLUTILS COMMON OPTION <opt>}`); no existing test compared the
  full message. Every module that uses `parseOptions` gets the new message.
- `readFile` and `writeFile` take `-encoding enc`. Without it they keep using
  the system encoding (utf-8 on Linux, usually cp1252 under Tcl 8.6 on
  Windows) — pass `-encoding utf-8` where non-ASCII text is compared.

### Tests independent of the environment

`tudhash.test` and `tuxxhash.test` found their module only through
`TCLUTILS_TM`; under a plain `tclsh tests/all.tcl` they aborted without a
summary. They now add `lib/tm` themselves, like the other test files.

Measured 2026-09-19 without any module path in the environment (145 test
files, each with a summary): Tcl 9.0.4 / tls 2.0 — 1819 passed, 12 skipped;
Tcl 8.6.14 / tls 1.7.22, no tcllib — 1758 passed, 73 skipped; 0 failed on
both, `all.tcl` exit 0.

## 0.62.0

### Added

- **`tunotesdb` 0.1** — the persistent counterpart to `tunotes`: one row per
  note in SQLite instead of one Tcl dict saved as JSON.
  - Same note layout (`id parent_id title content created modified tags`) and
    the same timestamp format, so both engines are interchangeable and
    `tkutils::tkunotes` works with either.
  - The hierarchy lives in `parent_id` and is queried with `WITH RECURSIVE`:
    `descendants`, `ancestors`, `path`, `depth`, `siblings` and `subtree` do
    their work in the database rather than loading every note to follow a chain
    of parents.
  - **Full-text search through FTS5** with ranking and snippets, as an
    external-content index (`content='notes'`) kept in step by three triggers —
    the text is not stored twice and no application code has to reindex. A
    syntactically wrong query raises `BADQUERY` instead of looking like an empty
    result.
  - `init` is idempotent and switches the database to WAL, so readers do not
    block the writer.
  - Bridges both ways: `toStore` returns a `tunotes` store (and thus a JSON
    export via `tunotes::toJson`), `fromStore` imports one in a single
    transaction.
  - Builds on `tusqlite` for the SQL layer and, like that module, does **not**
    `package require sqlite3` itself — the caller opens the database and passes
    the handle.
  - Errors use `errorCode {TCLUTILS TUNOTESDB <REASON>}`.
  - 41 tests, green on Tcl 8.6 (SQLite 3.45) and 9.0 (SQLite 3.53); without the
    `sqlite3` package they are skipped, not failed.

`tunotes` remains the right choice for a handful of notes and for anywhere that
must stay free of external packages. `tunotesdb` is for many notes, several
writers, or a server.

## 0.61.0

Adds a Windows icon container, pure Tcl and without Tk, as the writing
counterpart to tklib's `ico` package.

- `tuico` 0.1 — the `.ico` container format. `write` builds a file from
  `{size pngData}` pairs and validates every payload first (PNG signature, IHDR
  dimensions against the declared size), so a rejected call leaves no partial
  file behind. `info` reports each entry as a dict (`width`, `height`, `bpp`,
  `format`, `offset`, `length`) and recognises BMP payloads on read; `extract`
  returns a payload, optionally to a file.
- The entries carry **PNG payloads**, which Windows accepts since Vista and
  which keep an alpha channel. This is the gap tklib's `ico` leaves open: it
  reads icons from ICO/EXE/DLL/ICL, but by its own documentation cannot write a
  true 32bpp alpha icon from a Tk image. Use tklib `ico` to extract, `tuico` to
  write.
- Errors use `errorCode {TCLUTILS TUICO <REASON>}`.
- 15 tests, headless, green on Tcl 8.6.14 and 9.0.4.

Recommended pairing: tclutils 0.61.0 + tkutils 0.43.0 (`tkutils::tkuwinico` renders
the icon sizes and hands the PNG payloads to this module).

## 0.60.0

Adds a standalone-application builder for Tcl 9 (zipkits) and the `zipfs` image
primitives it uses. The runtime library stays pure Tcl on 8.6 and 9.x; the
builder targets Tcl 9 (zipfs is a Tcl 9 core feature).

- `tuzipfs` 0.2 — zipfs image primitives: `rcopy` (byte-exact recursive copy that
  also works from a mounted zipfs, where `file copy` is unreliable), `copyStdlib`
  (place `tcl_library` and, for GUI apps, `tk_library` into a VFS tree), `mkimg`
  (a checked wrapper over `zipfs mkimg`), and `buildImage` (drop the stdlib into
  an assembled tree and build in one call). The mount/read commands from 0.1 are
  unchanged.
- New app `build-app` — turns an app under `apps/` (tclutils or tkutils) into a
  single standalone executable, a Tcl 9 zipkit. A dependency prober runs the app
  once in the target basekit and bundles only the packages actually loaded; `-tm`
  supplies module trees, `-extlib` the roots for external pkgIndex packages
  (sqlite3, tdbc, tablelist …), `-include SRC=DEST` copies shared code an app
  sources from a sibling directory, and `-launch` names the GUI entry proc. The
  output platform is chosen by the target `-basekit`, so the same builder makes
  Linux and Windows binaries; the standard library is taken from that basekit.
- Self-hosting builder — `build-app` is also shipped as
  `apps/bin/build-app-zipkit-linux`, a zipkit that carries `tuzipfs` embedded, so
  a build host needs only that file plus the basekits (no installed Tcl or
  tclutils).
- Reproducible builds — `-writemanifest FILE` records the prober's dependency
  closure as an editable list; `-manifest FILE` builds from that list without
  probing (no display needed), for CI or for shipping an app as scripts plus a
  package list. Native client libraries (libpq, the Oracle client) are not Tcl
  packages and remain a target-system dependency either way.
- Docs — `docs/guide/build-app-guide.md` (with a pipeline diagram),
  `docs/guide/build-app-app-conventions.md`, `apps/build-app/README.md` and the
  worked `EXAMPLE-*` tutorials, `apps/_template/` skeletons (GUI + CLI). The
  `tuzipfs` man page and doc are updated to 0.2.
- Recommended pairing: tclutils 0.60.0 + tkutils 0.42.2.

## 0.59.0

- Fixed the umbrella typo `tclutis::tulayout` in `tclutils-0.58.0.tm`, which
  broke `package require tclutils` entirely (the umbrella now loads).
- Umbrella now also loads `tuxxhash`, `tudhash` and `tupostgrest`.
- Added man pages for `tudhash` and `tuxxhash`.
- Recommended pairing: tclutils 0.59.0 + tkutils 0.42.0.
- tupdf 0.2

## 0.58.0

Adds a Mermaid-compatible diagram subsystem and a MaxMind DB reader; the library
remains pure Tcl and runs on Tcl 8.6 and Tcl 9.x. All diagram rendering uses
primitive operations on a shared abstract canvas, so SVG and PNG output stay
congruent.

- Diagrams -- `tuflow`: the render facade. Detects the diagram language of a
  fenced code block and dispatches -- graph types through a parser into the
  `tudiagram` model (laid out and drawn), non-graph types through a
  self-contained 2D renderer. Requiring it pulls in `tudiagram`; the individual
  parsers and renderers load lazily on first use.
- Diagram model -- `tudiagram` 0.3: abstract graph model, layout and drawing.
  Node shapes box / rounded / circle / stadium / diamond / hexagon / cylinder,
  per-node colour overrides, thick edges, and crow's-foot end-marks
  (exactlyOne / zeroOrOne / oneOrMany / zeroOrMany). All shapes use
  rect / line / polygon / text primitives for portability.
- Graph parsers (Mermaid subset -> `tudiagram`): `tustate` (stateDiagram),
  `tuer` 0.2 (erDiagram, crow's-foot), `tuclass` (classDiagram),
  `turequirement` (requirementDiagram), `tumindmap` (mindmap), `tuc4` (C4),
  `tublock` (block-beta), `tugit` (gitGraph).
- 2D renderers (own parser + render): `tupie` (pie), `tuxychart` (xychart),
  `tuquadrant` (quadrantChart), `tujourney` (journey), `tutimeline` (timeline),
  `tusankey` (sankey-beta), `tugantt` (gantt), `tusequence` (sequenceDiagram).
- Canvas backends: `tusvg` 0.2 gains a Canvas-object constructor (`tusvg::new`);
  `tupngdraw` 0.12. The two share an abstract drawing protocol, so every
  renderer targets both SVG and PNG.
- Geo: `tummdb` -- pure-Tcl MaxMind DB (.mmdb) reader; added to the umbrella.
- Removed `tumermaid` (redundant -- tuflow's flowchart parser produces the same
  output). Cut over tudiagram 0.1 -> 0.3, tuflow 0.1 -> 0.2, tupngdraw 0.11 -> 0.12.
- Recommended pairing: tclutils 0.58.0 + tkutils 0.41.0.

## 0.57.0

Adds one color module; the library remains pure Tcl and runs on Tcl 8.6 and
Tcl 9.x.

- Color: `tucolor` -- named-color database and conversions. Resolves color
  names / `#rgb` / `#rrggbb` / `{r g b}` to RGB, converts to hex and HSV
  (`rgb`, `hex`, `toHsv`, `fromHsv`), lists/checks names (`names`, `exists`) and
  finds the nearest named color (`nearest`). The 148-entry CSS3/X11 name table
  is embedded (generated from Tk's `winfo rgb`, so values match X11/Tk), keeping
  the module GUI-free -- no Tk/X11 at runtime. Complements `tuterm`, `tupng`
  and `tusvg`. Ships with `test`, `doc`, `man` and demo; added to the umbrella.
- Recommended pairing: tclutils 0.57.0 + tkutils 0.41.0.

## 0.56.0

Adds one console module; the library remains pure Tcl and runs on Tcl 8.6 and
Tcl 9.x.

- Terminal / console: `tuterm` -- ANSI terminal styling (SGR): text attributes
  and 16- / 256- / 24-bit colors via `style` / `wrap`, an SGR `strip`, a global
  `enable` switch that honours the `NO_COLOR` convention (`auto`), and optional
  Windows VT-mode init (`enableVT`, via `twapi`; no-op on other platforms).
  Generalised from a console helper; GUI-free. Ships with `test`, `doc`, `man`
  and demo. Added to the umbrella (now 0.56.0).
- Recommended pairing: tclutils 0.56.0 + tkutils 0.41.0.

## 0.55.0

Adds two number modules; the library remains pure Tcl and runs on Tcl 8.6 and
Tcl 9.x.

- Numbers: `tunum` -- locale-aware parsing of grouped / currency amounts
  (EU `1.234,56`, US `1,234.56`, currency-symbol stripping) with `parse`,
  `sum` (skips non-numeric values) and `isNumber`. Pure Tcl, value-based;
  output is always a Tcl number.
- Numbers: `tunumany` -- a single `parse` entry point that routes to the right
  backend instead of merging them: locale / currency strings go to `tunum`,
  SI/IEC unit notation (`1.5K`, `2Mi`) to `tunumfmt`, with `-prefer` to force a
  route and a fallback to the other. Keeps the two specialised parsers separate
  while giving callers one function for either notation.
- `tunum` and `tunumany` are added to the umbrella; each ships with `test`,
  `doc`, `man` and demo. `tcltest` suite green on Tcl 8.6 and Tcl 9.x.
- Recommended pairing: tclutils 0.55.0 + tkutils 0.41.0.

## 0.54.0

Adds one module; the library remains pure Tcl and runs on Tcl 8.6 and Tcl 9.x.

- Deployment / packaging: `tudeploy` -- runtime discovery and loading of Tcl
  module packages from application-relative deployment roots (`vendor`,
  `libs/common`, `libs`, `lib/tm`), plus locating bundled resource
  directories for external binaries. Generalises the recurring "add candidate
  roots to `tcl::tm::path`, then `package require`" idiom; pairs with
  `tuexe` for decoder/tool lookup. Includes `test`, `doc`, `man`, and demo.
- Introspection / diagnostics: `tupkgfinder` -- inspect package resolution
  (known versions, `ifneeded` scripts and source paths, active vs. shadowed
  version, search paths, optional filesystem search); and `tuappinfo` --
  collect a plain-text application/system report (Tcl/Tk, environment, search
  paths, loaded packages, tracked modules) with optional anonymisation. Both
  pure Tcl and GUI-free; rendering is left to the caller. Each ships with
  `test`, `doc`, `man`, and demo.
- Recommended pairing: tclutils 0.54.0 + tkutils 0.40.0.

## 0.53.0

Changes since 0.41.0. Many modules were added; the library remains pure Tcl
(Tcl core only; `zlib` optional for ZIP) and runs on Tcl 8.6 and Tcl 9.x.

- PNG / image family: `tupng` (PNG read/write), `tupngdraw` (canvas-style
  drawing to PNG), `tupngpad`, `tucodepng`, `tutablepng`, `tumonthpng`,
  `tusvg` (SVG generation), and `tuimage` (image type/dimension/data-URI
  helpers).
- Date / web / IDs: `tudate`, `tuurl`, `tuuuid`, `tudav` (WebDAV client),
  `tufetch` (tiny HTTP(S) `get`/`download`, native `http`+`tls` else
  curl/wget), and `tusparql` (thin SPARQL client). The net helpers are
  optional and not dependency-free.
- Events / logging / registry: `tuevent`, `tulog`, `turegistry`.
- Calendar / recurrence: `turrule` (RRULE expansion), `tuholiday`.
- Strings / validation: `tustr`, `tuvalidate`, `tupagespec` (page-range
  spec parser, e.g. `1-3,5,7-`).
- Lists / dicts / math / tables: `tulist`, `tudict`, `tumath`, `tutable`.
- Stream / filesystem: `tuopen` (open files/URLs with the OS handler) and
  `tuexe` (locate external executables across bundled dirs and PATH).
- Data / records: `tusqlite` (TDBC/sqlite helper, optional), `tubookmark`.
- Text filters / encoding: `tucsplit`, `tufmt`, `tubase32`.
- Module hygiene: per-module `test` / `doc` / `man` across all 96 umbrella
  modules; `tcltest` suite green on Tcl 8.6 and Tcl 9.x.
- Recommended pairing: tclutils 0.53.0 + tkutils 0.40.0.

## 0.41.0

Initial public release.

- Pure-Tcl utility library, no external dependencies (Tcl core only; `zlib`
  optional for ZIP). Runs on Tcl 8.6 and Tcl 9.x.
- Coreutils-style text filters (cat, tac, rev, nl, seq, head, tail, wc, sort,
  tsort, uniq, cut, paste, join, comm, split, fold, expand, shuf, column, pr,
  tr, sed-subset, grep, awk, xargs).
- Compare/patch: `tucmp`, `tudiff`, `tupatch`.
- Binary / encoding / checksums: `tubin`, `tuhexdump`, `tuod`, `tuhexedit`,
  `tubase64`, `tucrc`, `tustrings`, `tuiconv`, `tucode`, and `tuhash`
  (SHA-256 / SHA-1 / MD5, verified against the standard vectors).
- Data / serialization: `tucsv` (RFC-4180 quoting, multiline, BOM strip,
  lenient `-strict 0`), `tujson` (parse / `parseTyped` / `fromJson` and the
  `toJson` encoder with builders), `tuxml`, `tunumfmt`.
- Stream / filesystem: `tufile`, `tufind`, `tustat`, `tutee`, `tupath`
  (normalize/clean/relative/commonPath/readlink), `tusize` (du-like).
- Fuzzy search: `tufuzzy`, `tuagrep`.
- Records / PIM (read + edit): `tunotes`, `tuical`, `tuini`, `tuvcard`,
  `tuldif`.
- Document helpers: `tumd`, `tupdf`, `tuodf`, `tucal`.
- Archive: `tuzip`, `tuzipfs`.
- Thin CLI wrappers in `bin/` and runnable demos in `examples/`.
- Full `tcltest` suite, green on Tcl 8.6 and Tcl 9.x.
