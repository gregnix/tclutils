# --- additional edge-style test cases for tests/tudiagram.test ---------------
# Append these inside tests/tudiagram.test (before cleanupTests). They cover the
# new "thick" edge style added to render. They reuse the existing D namespace.

test tudiagram-6.1 {a thick edge is drawn with a wider stroke} -body {
    set d [D::create]
    set d [D::addNode $d a]
    set d [D::addNode $d b]
    set d [D::addEdge $d a b -style thick]
    string match {*stroke-width="4"*} [D::toSvg $d]
} -result 1

test tudiagram-6.2 {a solid edge keeps the default stroke width} -body {
    set d [D::create]
    set d [D::addNode $d a]
    set d [D::addNode $d b]
    set d [D::addEdge $d a b -style solid]
    set svg [D::toSvg $d]
    list [string match {*stroke-width="2"*} $svg] [string match {*stroke-width="4"*} $svg]
} -result {1 0}
