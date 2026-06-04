# tclutils::tumath

Small numeric helpers the core `expr` does not provide directly. Pure Tcl, no
dependencies. (For `round`/`ceil`/`floor`/`abs` use the core `expr()` functions.)

```tcl
tumath::clamp $x $lo $hi      ;# constrain to [lo,hi]  ({TCLUTILS TUMATH ARG} if lo>hi)
tumath::inRange $x $lo $hi    ;# boolean, inclusive
tumath::percent $part $whole  ;# part/whole*100  ({TCLUTILS TUMATH DIVZERO} if whole==0)
tumath::sign $x               ;# -1 / 0 / 1
tumath::gcd $a $b             ;# greatest common divisor (integers)
tumath::lcm $a $b             ;# least common multiple
tumath::factorial $n          ;# n! for n>=0 (uses Tcl bignums)
tumath::roundTo $x $ndigits   ;# round to N decimal places
```
