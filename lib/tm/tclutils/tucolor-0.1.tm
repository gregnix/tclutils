# tclutils::tucolor -- named-color database and conversions. Resolves color
# names / hex / rgb triples to RGB, converts to hex and HSV, finds the nearest
# named color. The name table (CSS3 / X11 standard colors) is embedded, so the
# module is pure Tcl and GUI-free -- no Tk / X11 needed at runtime. The table
# was generated from Tk's `winfo rgb`, so values match X11/Tk exactly.
#
# API:
#   tucolor::rgb     color        -> {r g b}   (0..255 each)
#   tucolor::hex     color        -> #rrggbb
#   tucolor::names                -> sorted list of known color names
#   tucolor::exists  name         -> 0|1
#   tucolor::nearest color        -> nearest known color name (RGB distance)
#   tucolor::toHsv   color        -> {h s v}   (h 0..360, s/v 0..100)
#   tucolor::fromHsv {h s v}      -> {r g b}
#
# color accepts: a known name, #rgb, #rrggbb, or a {r g b} triple (0..255).
#
# Tcl 8.6-
package require Tcl 8.6-

namespace eval ::tclutils {}
namespace eval ::tclutils::tucolor {
    namespace export rgb hex names exists nearest toHsv fromHsv
    variable colors [dict create \
        aliceblue              {240 248 255} \
        antiquewhite           {250 235 215} \
        aqua                   {0 255 255} \
        aquamarine             {127 255 212} \
        azure                  {240 255 255} \
        beige                  {245 245 220} \
        bisque                 {255 228 196} \
        black                  {0 0 0} \
        blanchedalmond         {255 235 205} \
        blue                   {0 0 255} \
        blueviolet             {138 43 226} \
        brown                  {165 42 42} \
        burlywood              {222 184 135} \
        cadetblue              {95 158 160} \
        chartreuse             {127 255 0} \
        chocolate              {210 105 30} \
        coral                  {255 127 80} \
        cornflowerblue         {100 149 237} \
        cornsilk               {255 248 220} \
        crimson                {220 20 60} \
        cyan                   {0 255 255} \
        darkblue               {0 0 139} \
        darkcyan               {0 139 139} \
        darkgoldenrod          {184 134 11} \
        darkgray               {169 169 169} \
        darkgreen              {0 100 0} \
        darkgrey               {169 169 169} \
        darkkhaki              {189 183 107} \
        darkmagenta            {139 0 139} \
        darkolivegreen         {85 107 47} \
        darkorange             {255 140 0} \
        darkorchid             {153 50 204} \
        darkred                {139 0 0} \
        darksalmon             {233 150 122} \
        darkseagreen           {143 188 143} \
        darkslateblue          {72 61 139} \
        darkslategray          {47 79 79} \
        darkslategrey          {47 79 79} \
        darkturquoise          {0 206 209} \
        darkviolet             {148 0 211} \
        deeppink               {255 20 147} \
        deepskyblue            {0 191 255} \
        dimgray                {105 105 105} \
        dimgrey                {105 105 105} \
        dodgerblue             {30 144 255} \
        firebrick              {178 34 34} \
        floralwhite            {255 250 240} \
        forestgreen            {34 139 34} \
        fuchsia                {255 0 255} \
        gainsboro              {220 220 220} \
        ghostwhite             {248 248 255} \
        gold                   {255 215 0} \
        goldenrod              {218 165 32} \
        gray                   {128 128 128} \
        grey                   {128 128 128} \
        green                  {0 128 0} \
        greenyellow            {173 255 47} \
        honeydew               {240 255 240} \
        hotpink                {255 105 180} \
        indianred              {205 92 92} \
        indigo                 {75 0 130} \
        ivory                  {255 255 240} \
        khaki                  {240 230 140} \
        lavender               {230 230 250} \
        lavenderblush          {255 240 245} \
        lawngreen              {124 252 0} \
        lemonchiffon           {255 250 205} \
        lightblue              {173 216 230} \
        lightcoral             {240 128 128} \
        lightcyan              {224 255 255} \
        lightgoldenrodyellow   {250 250 210} \
        lightgray              {211 211 211} \
        lightgreen             {144 238 144} \
        lightgrey              {211 211 211} \
        lightpink              {255 182 193} \
        lightsalmon            {255 160 122} \
        lightseagreen          {32 178 170} \
        lightskyblue           {135 206 250} \
        lightslategray         {119 136 153} \
        lightslategrey         {119 136 153} \
        lightsteelblue         {176 196 222} \
        lightyellow            {255 255 224} \
        lime                   {0 255 0} \
        limegreen              {50 205 50} \
        linen                  {250 240 230} \
        magenta                {255 0 255} \
        maroon                 {128 0 0} \
        mediumaquamarine       {102 205 170} \
        mediumblue             {0 0 205} \
        mediumorchid           {186 85 211} \
        mediumpurple           {147 112 219} \
        mediumseagreen         {60 179 113} \
        mediumslateblue        {123 104 238} \
        mediumspringgreen      {0 250 154} \
        mediumturquoise        {72 209 204} \
        mediumvioletred        {199 21 133} \
        midnightblue           {25 25 112} \
        mintcream              {245 255 250} \
        mistyrose              {255 228 225} \
        moccasin               {255 228 181} \
        navajowhite            {255 222 173} \
        navy                   {0 0 128} \
        oldlace                {253 245 230} \
        olive                  {128 128 0} \
        olivedrab              {107 142 35} \
        orange                 {255 165 0} \
        orangered              {255 69 0} \
        orchid                 {218 112 214} \
        palegoldenrod          {238 232 170} \
        palegreen              {152 251 152} \
        paleturquoise          {175 238 238} \
        palevioletred          {219 112 147} \
        papayawhip             {255 239 213} \
        peachpuff              {255 218 185} \
        peru                   {205 133 63} \
        pink                   {255 192 203} \
        plum                   {221 160 221} \
        powderblue             {176 224 230} \
        purple                 {128 0 128} \
        rebeccapurple          {102 51 153} \
        red                    {255 0 0} \
        rosybrown              {188 143 143} \
        royalblue              {65 105 225} \
        saddlebrown            {139 69 19} \
        salmon                 {250 128 114} \
        sandybrown             {244 164 96} \
        seagreen               {46 139 87} \
        seashell               {255 245 238} \
        sienna                 {160 82 45} \
        silver                 {192 192 192} \
        skyblue                {135 206 235} \
        slateblue              {106 90 205} \
        slategray              {112 128 144} \
        slategrey              {112 128 144} \
        snow                   {255 250 250} \
        springgreen            {0 255 127} \
        steelblue              {70 130 180} \
        tan                    {210 180 140} \
        teal                   {0 128 128} \
        thistle                {216 191 216} \
        tomato                 {255 99 71} \
        turquoise              {64 224 208} \
        violet                 {238 130 238} \
        wheat                  {245 222 179} \
        white                  {255 255 255} \
        whitesmoke             {245 245 245} \
        yellow                 {255 255 0} \
        yellowgreen            {154 205 50}
    ]
}

proc ::tclutils::tucolor::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TUCOLOR $reason] $msg
}

# Resolve a color (name | #rgb | #rrggbb | {r g b}) to a {r g b} triple.
proc ::tclutils::tucolor::rgb {color} {
    variable colors
    set c [string trim $color]
    set lc [string tolower $c]
    if {[dict exists $colors $lc]} { return [lmap v [dict get $colors $lc] {expr {$v}}] }
    if {[regexp {^#([0-9a-fA-F])([0-9a-fA-F])([0-9a-fA-F])$} $c -> r g b]} {
        scan $r %x r; scan $g %x g; scan $b %x b
        return [list [expr {$r*17}] [expr {$g*17}] [expr {$b*17}]]
    }
    if {[regexp {^#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})$} $c -> r g b]} {
        scan $r %x r; scan $g %x g; scan $b %x b
        return [list $r $g $b]
    }
    if {[llength $c] == 3} {
        set ok 1
        foreach v $c {
            if {![string is integer -strict $v] || $v < 0 || $v > 255} { set ok 0; break }
        }
        if {$ok} { return [lmap v $c {expr {$v}}] }
    }
    _err NAME "unknown color \"$color\""
}

# Hex string #rrggbb for any color.
proc ::tclutils::tucolor::hex {color} {
    lassign [rgb $color] r g b
    return [format "#%02x%02x%02x" $r $g $b]
}

# Sorted list of known color names.
proc ::tclutils::tucolor::names {} {
    variable colors
    return [lsort [dict keys $colors]]
}

# Whether a name is in the table (case-insensitive).
proc ::tclutils::tucolor::exists {name} {
    variable colors
    return [dict exists $colors [string tolower [string trim $name]]]
}

# Nearest known color name by Euclidean RGB distance.
proc ::tclutils::tucolor::nearest {color} {
    variable colors
    lassign [rgb $color] r g b
    set best ""; set bestd ""
    dict for {nm v} $colors {
        lassign $v cr cg cb
        set d [expr {($r-$cr)**2 + ($g-$cg)**2 + ($b-$cb)**2}]
        if {$bestd eq "" || $d < $bestd} { set bestd $d; set best $nm }
    }
    return $best
}

# RGB -> HSV. h in 0..360, s and v in 0..100.
proc ::tclutils::tucolor::toHsv {color} {
    lassign [rgb $color] R G B
    set r [expr {$R/255.0}]; set g [expr {$G/255.0}]; set b [expr {$B/255.0}]
    set mx [expr {max($r,$g,$b)}]; set mn [expr {min($r,$g,$b)}]
    set d [expr {$mx-$mn}]
    set v $mx
    set s [expr {$mx == 0 ? 0 : $d/$mx}]
    if {$d == 0} {
        set h 0
    } elseif {$mx == $r} {
        set h [expr {60*(fmod(($g-$b)/$d, 6.0))}]
    } elseif {$mx == $g} {
        set h [expr {60*(($b-$r)/$d + 2)}]
    } else {
        set h [expr {60*(($r-$g)/$d + 4)}]
    }
    if {$h < 0} { set h [expr {$h+360}] }
    return [list [expr {round($h)}] [expr {round($s*100)}] [expr {round($v*100)}]]
}

# HSV -> RGB. Input h 0..360, s/v 0..100; output {r g b} 0..255.
proc ::tclutils::tucolor::fromHsv {hsv} {
    lassign $hsv h s v
    set s [expr {$s/100.0}]; set v [expr {$v/100.0}]
    set c [expr {$v*$s}]
    set hp [expr {(($h % 360)+360)%360 / 60.0}]
    set x [expr {$c*(1 - abs(fmod($hp,2.0) - 1))}]
    set m [expr {$v-$c}]
    if {$hp < 1}    { set rgb [list $c $x 0] } \
    elseif {$hp < 2} { set rgb [list $x $c 0] } \
    elseif {$hp < 3} { set rgb [list 0 $c $x] } \
    elseif {$hp < 4} { set rgb [list 0 $x $c] } \
    elseif {$hp < 5} { set rgb [list $x 0 $c] } \
    else             { set rgb [list $c 0 $x] }
    return [lmap ch $rgb {expr {round(($ch+$m)*255)}}]
}

package provide tclutils::tucolor 0.1
