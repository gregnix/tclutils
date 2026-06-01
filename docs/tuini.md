# tclutils::tuini

INI reader/writer. Parses into a dict section -> (dict key -> value); keys before
any `[section]` live in the global section "". Order is preserved. Comments
(`;` or `#`) are dropped.

```tcl
tuini::parse iniText            ;# -> data dict
tuini::toIni data               ;# -> INI text
tuini::sections data
tuini::keys data ?section?
tuini::get  data section key ?default?
tuini::has  data section key
tuini::setValue data section key value   ;# -> new data dict
```
Error code: `{TCLUTILS TUINI SYNTAX}`.
