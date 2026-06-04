# tclutils::tulist

Functional list helpers the Tcl core does not provide directly. Pure Tcl, no
dependencies. `map`/`filter`/`reduce`/`all`/`any` take a **command prefix**
(invoked as `{*}$cmd $item`), complementing the core `lmap` (script body).

```tcl
tulist::unique {a b a c}        ;# a b c        (order-preserving)
tulist::flatten {{1 2} {3 4}}   ;# 1 2 3 4      (optional depth)
tulist::chunk {1 2 3 4 5} 2     ;# {1 2} {3 4} 5
tulist::zip {a b} {1 2}         ;# {a 1} {b 2}  (stops at shortest)
tulist::sum/avg/min/max $list
tulist::reduce {1 2 3} 0 ::tcl::mathop::+        ;# 6
tulist::map    {1 2 3} {apply {{x} {expr {$x*$x}}}}
tulist::filter {1 2 3 4} {apply {{x} {expr {$x%2==0}}}}
tulist::all / any $list $cmd
tulist::take $list n   /   tulist::drop $list n
```

`chunk` with a non-positive size raises `{TCLUTILS TULIST SIZE}`; `avg`/`min`/`max`
of an empty list raise `{TCLUTILS TULIST EMPTY}`. Prefer the core where it fits:
`lreverse`, `lsort -unique` (if order does not matter), `lsearch`, `lmap`.
