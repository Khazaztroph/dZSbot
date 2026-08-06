set root [file normalize [pwd]]
source [file join $root dZSbot.tcl]

::dZSbot::Config::Set database.mysql.enabled 1

rename ::dZSbot::Database::MySQL::Connect ::dZSbot::Database::MySQL::ConnectReal
rename ::dZSbot::Database::MySQL::Disconnect ::dZSbot::Database::MySQL::DisconnectReal

set connectCalls 0
set disconnectCalls 0
set execCalls 0
set selectCalls 0

proc ::dZSbot::Database::MySQL::Connect {} {
    variable Handle
    variable Connected
    variable Driver

    incr ::connectCalls
    set Handle fake-handle
    set Connected 1
    set Driver mysqltcl
    return 1
}

proc ::dZSbot::Database::MySQL::Disconnect {} {
    variable Handle
    variable Connected
    variable Driver

    incr ::disconnectCalls
    set Handle ""
    set Connected 0
    set Driver ""
}

proc mysqlexec {handle sql} {
    incr ::execCalls
    if {$::execCalls == 1} {
        error "MySQL server has gone away"
    }
    return 1
}

proc mysqlsel {handle sql option} {
    incr ::selectCalls
    if {$::selectCalls == 1} {
        error "Lost connection to MySQL server during query"
    }
    return [list one two]
}

if {![::dZSbot::Database::MySQL::Exec "INSERT INTO predb VALUES ('test')"]} {
    error "Expected Exec to reconnect and succeed"
}

if {$execCalls != 2 || $connectCalls != 2 || $disconnectCalls != 1} {
    error "Unexpected Exec reconnect counters: exec=$execCalls connect=$connectCalls disconnect=$disconnectCalls"
}

set rows [::dZSbot::Database::MySQL::SelectFlat "SELECT relname FROM predb"]
if {$rows ne [list one two]} {
    error "Expected SelectFlat to reconnect and return rows: $rows"
}

if {$selectCalls != 2 || $connectCalls != 4 || $disconnectCalls != 2} {
    error "Unexpected SelectFlat reconnect counters: select=$selectCalls connect=$connectCalls disconnect=$disconnectCalls"
}

puts "MySQL reconnect retry passed"
