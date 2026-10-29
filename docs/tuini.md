# tclutils::tuini

INI reader/writer. Parses into a dict section -> (dict key -> value); keys before
any `[section]` live in the global section "". Order is preserved. Comments
(`;` or `#`) are dropped. A key that occurs twice in a section keeps the last
value (the Windows profile API takes the first). Blanks around keys and
values are dropped, so a value cannot end in a blank.

`setValue`, `addSection` and `toIni` refuse what INI cannot hold, so `toIni`
never writes text that `parse` cannot read back (0.2; 0.1 wrote it):

- a value with a line break;
- a key with `=` or a line break, a key starting with `;`, `#` or `[`, a key
  with blanks at either end;
- a section name with `]` or a line break, or blanks at either end.

Error code `{TCLUTILS TUINI VALUE}`.

```tcl
tuini::parse iniText            ;# -> data dict
tuini::toIni data               ;# -> INI text
tuini::sections data
tuini::keys data ?section?
tuini::get  data section key ?default?
tuini::has  data section key
tuini::setValue data section key value   ;# -> new data dict
```
Error codes: `{TCLUTILS TUINI SYNTAX}` (parse), `{TCLUTILS TUINI VALUE}` (see above).

## Additional exported commands

Documented for completeness (same module, also covered by the test suite):

```tcl
tuini::addSection data section                 ;# return a copy of data with an (empty) section ensured to exist
tuini::removeKey data section key              ;# return a copy of data with a key removed from a section
tuini::removeSection data section              ;# return a copy of data with a whole section removed
```
