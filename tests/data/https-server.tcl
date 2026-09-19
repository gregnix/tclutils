# https-server.tcl -- minimal HTTPS server for the tclutils test suite.
#
#   <interp> https-server.tcl <certfile> <keyfile>
#
# Prints the port it listens on (127.0.0.1/localhost, ephemeral), answers every
# request with "200 ok", and exits when its stdin reaches EOF -- i.e. when the
# test closes the pipe. It must run in its own process: ::http::geturl opens
# the tls socket blocking, so a server in the test's own interpreter would
# never get to answer and the test would hang (measured 2026-09-19).
#
# Used by tuhttps.test and tufetch.test together with tuhttps-localhost.crt/.key
# (self-signed for localhost and 127.0.0.1, valid until 2126, test use only).
package require tls
lassign $argv crt key
proc srvAccept {ch addr port} {
    fconfigure $ch -blocking 0 -translation {auto binary}
    fileevent $ch readable [list srvRead $ch]
}
proc srvRead {ch} {
    # a rejected handshake surfaces here as a read error: drop the socket
    if {[catch {gets $ch line} n]} { catch {close $ch}; return }
    if {$n < 0} { if {[eof $ch]} { catch {close $ch} }; return }
    if {$line eq ""} {
        catch {
            puts -nonewline $ch "HTTP/1.0 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok"
            flush $ch
        }
        catch {close $ch}
    }
}
set srv [::tls::socket -server srvAccept -certfile $crt -keyfile $key 0]
puts [lindex [fconfigure $srv -sockname] 2]
flush stdout
fileevent stdin readable { if {[gets stdin l] < 0} { exit 0 } }
vwait forever
