# tclutils::tufind

Portable file finder in pure Tcl.

## Load

```tcl
package require tclutils::tufind
```

## Main commands

```tcl
::tclutils::tufind::files root pattern ?options?
::tclutils::tufind::directories root pattern ?options?
::tclutils::tufind::all root pattern ?options?
::tclutils::tufind::walk root patterns callback ?options?
```

## Options

```text
-recursive 0|1       recurse into subdirectories, default 1
-mindepth N          only accept paths at depth N or deeper, default 0
-maxdepth N          stop recursion at depth N, -1 means unlimited
-type file|dir|directory|any|all
-hidden 0|1          include hidden dot-files, default 0
-fullpath 0|1        match pattern against full path as well as tail, default 1
-tails 0|1           return file tails instead of full paths
-followlinks 0|1     follow symbolic links to directories, default 0
-size SPEC           file size filter: N, +N, -N, optional k/m/g suffix
-mtime SPEC          modification age in days: N, +N older than N, -N newer than N
```

## Examples

```tcl
set pdfs [::tclutils::tufind::files . *.pdf]
```

```tcl
set largeTxt [::tclutils::tufind::files . *.txt -size +1k]
```

```tcl
set recent [::tclutils::tufind::files . *.log -mtime -2]
```

```tcl
set dirs [::tclutils::tufind::directories . * -maxdepth 2]
```
