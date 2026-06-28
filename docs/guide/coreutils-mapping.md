# Coreutils mapping

This file maps common Unix commands to the corresponding `tclutils` modules.

| Unix tool | tclutils package | Status |
|---|---|---|
| find | `tclutils::tufind` | implemented |
| grep | `tclutils::tugrep` | implemented |
| sed | `tclutils::tused` | implemented subset |
| wc | `tclutils::tuwc` | implemented |
| cat | `tclutils::tucat` | implemented |
| head | `tclutils::tuhead` | implemented |
| tail | `tclutils::tutail` | implemented |
| sort | `tclutils::tusort` | implemented |
| uniq | `tclutils::tuuniq` | implemented |
| cut | `tclutils::tucut` | implemented field mode |
| paste | `tclutils::tupaste` | implemented |
| join | `tclutils::tujoin` | implemented inner join |
| diff | `tclutils::tudiff` | implemented line/unified/context/directory |
| patch | `tclutils::tupatch` | implemented unified diff applier |
| cmp | `tclutils::tucmp` | implemented |
| strings | `tclutils::tustrings` | implemented |
| hexdump | `tclutils::tuhexdump` | implemented |
| od | `tclutils::tuod` | implemented basis |
| iconv | `tclutils::tuiconv` | implemented basis |
| tee | `tclutils::tutee` | implemented basis |
| xargs | `tclutils::tuxargs` | implemented basis |
| zip/unzip | `tclutils::tuzip` | implemented ZIP subset |
| split | `tclutils::tusplit` | implemented |
| csplit | `tclutils::tucsplit` | implemented |
| comm | `tclutils::tucomm` | implemented |
| fold | `tclutils::tufold` | implemented |
| fmt | `tclutils::tufmt` | implemented |
| nl | `tclutils::tunl` | implemented |
| seq | `tclutils::tuseq` | implemented |
| rev | `tclutils::turev` | implemented |
| tac | `tclutils::tutac` | implemented |
| expand/unexpand | `tclutils::tuexpand` | implemented |
| shuf | `tclutils::tushuf` | implemented |
| column | `tclutils::tucolumn` | implemented table and fill modes |
| pr | `tclutils::tupr` | implemented basis |
| tsort | `tclutils::tutsort` | implemented |
| numfmt | `tclutils::tunumfmt` | implemented SI and IEC |
| date | `tclutils::tudate` | implemented subset (parse/format/arithmetic) |
| uuidgen | `tclutils::tuuuid` | implemented (util-linux tool; v4/v7) |
| stat | `tclutils::tustat` | implemented basis |
| tr | `tclutils::tutr` | implemented basis |
| base64 | `tclutils::tubase64` | implemented basis |
| base32 | `tclutils::tubase32` | implemented (incl. base32hex) |
| cksum | `tclutils::tucrc` | implemented basis |
| md5sum | `tclutils::tuhash` | implemented |
| sha256sum | `tclutils::tuhash` | implemented |
| sha1sum | `tclutils::tuhash` | implemented |
| du | `tclutils::tusize` | implemented |
| realpath | `tclutils::tupath` | implemented (normalize/clean) |
| readlink | `tclutils::tupath` | implemented |
| tar | Tcllib `tar` | use Tcllib, not reimplemented |

Additional developer helpers:

| Helper | tclutils package | Status |
|---|---|---|
| CSV | `tclutils::tucsv` | implemented |
| JSON | `tclutils::tujson` | helper implemented, not full parser |
| XML | `tclutils::tuxml` | helper implemented, not DOM/XPath |

| Binary primitives | `tclutils::tubin` | implemented |
| Hex editing | `tclutils::tuhexedit` | implemented library helper |


## Tcl-specific archive helpers

| Tclutils | Purpose |
|---|---|
| tuzipfs | Tcl 9 ZipFS mount/list/read helper |

| agrep | tuagrep | approximate grep / fuzzy search |


Document helpers:

| Domain | Tclutils |
|---|---|
| ODF text | tuodf |
| PDF inspect | tupdf |
| Markdown utilities | tumd |
