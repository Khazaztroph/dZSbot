namespace eval ::dZSbot::Modules::Requests::Formatter {}

proc ::dZSbot::Modules::Requests::Formatter::Age {timestamp} {

    if {![string is integer -strict $timestamp] || $timestamp <= 0} {
        return "unknown"
    }

    set seconds [expr {[clock seconds] - $timestamp}]
    if {$seconds < 0} {
        set seconds 0
    }

    set days [expr {$seconds / 86400}]
    set hours [expr {($seconds % 86400) / 3600}]
    set mins [expr {($seconds % 3600) / 60}]

    if {$days > 0} {
        return "${days}d ${hours}h"
    }
    if {$hours > 0} {
        return "${hours}h ${mins}m"
    }

    return "${mins}m"
}

proc ::dZSbot::Modules::Requests::Formatter::Added {entry} {

    return "Request added: [dict get $entry request]"
}

proc ::dZSbot::Modules::Requests::Formatter::Header {count} {

    if {$count == 1} {
        return "REQUESTS: 1 open request"
    }

    return "REQUESTS: $count open requests"
}

proc ::dZSbot::Modules::Requests::Formatter::Line {entry index} {

    return "REQUESTS #$index: [dict get $entry request] | by [dict get $entry nick] | [Age [dict get $entry timestamp]] ago"
}

proc ::dZSbot::Modules::Requests::Formatter::Deleted {entry} {

    return "Request deleted: [dict get $entry request]"
}

proc ::dZSbot::Modules::Requests::Formatter::Filled {entry} {

    return "Request filled: [dict get $entry request] | by [dict get $entry filled_by]"
}
