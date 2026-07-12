namespace eval ::dZSbot::Modules::Requests {

    variable Version "0.2.0"
}

source [file join $::dZSbot::Root modules requests store.tcl]
source [file join $::dZSbot::Root modules requests formatter.tcl]

::dZSbot::Modules::Requests::Store::Ensure

proc ::dZSbot::Modules::Requests::CmdRequest {nick host hand chan text} {

    set request [string trim $text]

    if {$request eq ""} {
        ::dZSbot::Commands::Reply $nick $chan "Usage: !request <release/title>"
        return
    }

    set stored [::dZSbot::Modules::Requests::Store::Add $nick $request]
    ::dZSbot::Commands::Reply $nick $chan [::dZSbot::Modules::Requests::Formatter::Added $stored]
}

proc ::dZSbot::Modules::Requests::CmdRequests {nick host hand chan text} {

    set limit [::dZSbot::Config::Get requests.list_limit 10]
    set rows [::dZSbot::Modules::Requests::Store::Open $limit]
    set count [::dZSbot::Modules::Requests::Store::CountOpen]

    if {$count == 0} {
        ::dZSbot::Commands::Reply $nick $chan "No requests yet."
        return
    }

    ::dZSbot::Commands::Reply $nick $chan [::dZSbot::Modules::Requests::Formatter::Header $count]

    set index 0
    foreach row $rows {
        incr index
        ::dZSbot::Commands::Reply $nick $chan [::dZSbot::Modules::Requests::Formatter::Line $row $index]
    }
}

proc ::dZSbot::Modules::Requests::CmdReqDel {nick host hand chan text} {

    set pattern [string trim $text]
    if {$pattern eq ""} {
        ::dZSbot::Commands::Reply $nick $chan "Usage: !reqdel <release/title>"
        return
    }

    set deleted [::dZSbot::Modules::Requests::Store::Delete $pattern]
    if {![llength $deleted]} {
        ::dZSbot::Commands::Reply $nick $chan "Request not found: $pattern"
        return
    }

    ::dZSbot::Commands::Reply $nick $chan [::dZSbot::Modules::Requests::Formatter::Deleted [lindex $deleted 0]]
}

proc ::dZSbot::Modules::Requests::CmdReqFill {nick host hand chan text} {

    set pattern [string trim $text]
    if {$pattern eq ""} {
        ::dZSbot::Commands::Reply $nick $chan "Usage: !reqfill <release/title>"
        return
    }

    set filled [::dZSbot::Modules::Requests::Store::Fill $pattern $nick]
    if {$filled eq ""} {
        ::dZSbot::Commands::Reply $nick $chan "Request not found: $pattern"
        return
    }

    ::dZSbot::Commands::Reply $nick $chan [::dZSbot::Modules::Requests::Formatter::Filled $filled]
}

::dZSbot::Commands::Register requests !request ::dZSbot::Modules::Requests::CmdRequest "Add request"
::dZSbot::Commands::Register requests !req ::dZSbot::Modules::Requests::CmdRequest "Add request"
::dZSbot::Commands::Register requests !requests ::dZSbot::Modules::Requests::CmdRequests "List requests"
::dZSbot::Commands::Register requests !reqdel ::dZSbot::Modules::Requests::CmdReqDel "Delete request"
::dZSbot::Commands::Register requests !reqfill ::dZSbot::Modules::Requests::CmdReqFill "Fill request"

::dZSbot::ModuleManager::Register requests [dict create \
    version $::dZSbot::Modules::Requests::Version \
    description "Request queue" \
    commands [::dZSbot::Commands::List requests]]
