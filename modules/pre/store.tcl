namespace eval ::dZSbot::Modules::Pre::Store {

    variable Fields {id section relname u_name g_name nukereason pretime predate preage size files}
}

proc ::dZSbot::Modules::Pre::Store::Path {} {

    return [::dZSbot::Config::Get pre.storage [file join $::dZSbot::Root database pre.tsv]]
}

proc ::dZSbot::Modules::Pre::Store::Ensure {} {

    variable Fields
    set path [Path]

    file mkdir [file dirname $path]

    if {![file exists $path]} {
        set handle [open $path w]
        puts $handle [join $Fields "\t"]
        close $handle
    }

    return $path
}

proc ::dZSbot::Modules::Pre::Store::Encode {value} {

    return [string map [list "\\" "\\\\" "\t" "\\t" "\n" "\\n" "\r" "\\r"] $value]
}

proc ::dZSbot::Modules::Pre::Store::Decode {value} {

    return [string map [list "\\t" "\t" "\\n" "\n" "\\r" "\r" "\\\\" "\\"] $value]
}

proc ::dZSbot::Modules::Pre::Store::NextId {} {

    set max 0

    foreach row [All] {
        set id [dict get $row id]
        if {[string is integer -strict $id] && $id > $max} {
            set max $id
        }
    }

    return [expr {$max + 1}]
}

proc ::dZSbot::Modules::Pre::Store::All {} {

    variable Fields
    set path [Ensure]
    set handle [open $path r]
    set content [string trimright [read $handle]]
    close $handle

    if {$content eq ""} {
        return {}
    }

    set lines [split $content "\n"]
    set rows {}

    foreach line [lrange $lines 1 end] {
        if {[string trim $line] eq ""} {
            continue
        }

        set values [split $line "\t"]
        set row {}

        for {set i 0} {$i < [llength $Fields]} {incr i} {
            dict set row [lindex $Fields $i] [Decode [lindex $values $i]]
        }

        lappend rows $row
    }

    return $rows
}

proc ::dZSbot::Modules::Pre::Store::Add {entry} {

    variable Fields
    set path [Ensure]
    set now [clock seconds]

    if {![dict exists $entry id] || [dict get $entry id] eq ""} {
        dict set entry id [NextId]
    }
    if {![dict exists $entry pretime] || [dict get $entry pretime] eq ""} {
        dict set entry pretime $now
    }
    if {![dict exists $entry predate] || [dict get $entry predate] eq ""} {
        dict set entry predate [clock format [dict get $entry pretime] -format {%Y%m%d}]
    }
    if {![dict exists $entry preage] || [dict get $entry preage] eq ""} {
        dict set entry preage 0
    }

    set line {}
    foreach field $Fields {
        if {[dict exists $entry $field]} {
            lappend line [Encode [dict get $entry $field]]
        } else {
            lappend line ""
        }
    }

    set handle [open $path a]
    puts $handle [join $line "\t"]
    close $handle

    return $entry
}

proc ::dZSbot::Modules::Pre::Store::Search {query {limit 10}} {

    set query [string tolower [string trim $query]]
    set result {}

    foreach row [lreverse [All]] {
        set release [string tolower [dict get $row relname]]

        if {$query eq "" || [string match "*$query*" $release]} {
            lappend result $row
        }

        if {[llength $result] >= $limit} {
            break
        }
    }

    return $result
}

proc ::dZSbot::Modules::Pre::Store::ExistsLocal {release} {

    set release [string trim $release]
    if {$release eq ""} {
        return 0
    }

    foreach row [All] {
        if {[string equal -nocase [dict get $row relname] $release]} {
            return 1
        }
    }

    return 0
}

proc ::dZSbot::Modules::Pre::Store::Backend {} {

    return [string tolower [::dZSbot::Config::Get pre.backend "tsv"]]
}

proc ::dZSbot::Modules::Pre::Store::UsingMySQL {} {

    return [expr {[Backend] eq "mysql"}]
}

proc ::dZSbot::Modules::Pre::Store::Ready {} {

    if {[UsingMySQL]} {
        if {![::dZSbot::Database::MySQL::Enabled]} {
            ::dZSbot::Health::Set pre:storage warn "mysql backend selected but database.mysql.enabled is off"
            return 0
        }

        set ready [::dZSbot::Modules::Pre::MySQLStore::Ensure]
        if {$ready} {
            ::dZSbot::Health::Set pre:storage ok "mysql table [::dZSbot::Modules::Pre::MySQLStore::Table]"
        } else {
            ::dZSbot::Health::Set pre:storage error "mysql unavailable"
        }
        return $ready
    }

    Ensure
    ::dZSbot::Health::Set pre:storage ok "tsv [Path]"
    return 1
}

proc ::dZSbot::Modules::Pre::Store::AddEntry {entry} {

    if {[UsingMySQL]} {
        return [::dZSbot::Modules::Pre::MySQLStore::Add $entry]
    }

    return [Add $entry]
}

proc ::dZSbot::Modules::Pre::Store::SearchEntries {query {limit 10}} {

    if {[UsingMySQL]} {
        set rows [::dZSbot::Modules::Pre::MySQLStore::Search $query $limit]
        if {[llength $rows] || ![MySQLFallbackEnabled]} {
            return $rows
        }

        return [Search $query $limit]
    }

    return [Search $query $limit]
}

proc ::dZSbot::Modules::Pre::Store::Exists {release} {

    if {[UsingMySQL]} {
        return [::dZSbot::Modules::Pre::MySQLStore::Exists $release]
    }

    return [ExistsLocal $release]
}

proc ::dZSbot::Modules::Pre::Store::LatestEntries {{limit 10}} {

    if {[UsingMySQL]} {
        set rows [::dZSbot::Modules::Pre::MySQLStore::Latest $limit]
        if {[llength $rows] || ![MySQLFallbackEnabled]} {
            return $rows
        }

        return [Search "" $limit]
    }

    return [Search "" $limit]
}

proc ::dZSbot::Modules::Pre::Store::MySQLFallbackEnabled {} {

    return [expr {[::dZSbot::Config::Get pre.mysql.fallback_to_tsv 1] ? 1 : 0}]
}

proc ::dZSbot::Modules::Pre::Store::Status {} {

    set backend [Backend]
    set status [dict create backend $backend]

    if {$backend eq "mysql"} {
        dict set status mysql_enabled [expr {[::dZSbot::Database::MySQL::Enabled] ? 1 : 0}]
        dict set status mysql_connected [expr {[::dZSbot::Database::MySQL::Connected] ? 1 : 0}]
        dict set status mysql_tls [expr {[::dZSbot::Database::MySQL::TLSActive] ? 1 : 0}]
        dict set status database [::dZSbot::Config::Get database.mysql.database "dzsbot"]
        dict set status host [::dZSbot::Config::Get database.mysql.host "127.0.0.1"]
        dict set status port [::dZSbot::Config::Get database.mysql.port 3306]
        dict set status table [::dZSbot::Modules::Pre::MySQLStore::Table]
        dict set status fallback_to_tsv [expr {[::dZSbot::Config::Get pre.mysql.fallback_to_tsv 1] ? 1 : 0}]
    } else {
        dict set status path [Path]
    }

    return $status
}

proc ::dZSbot::Modules::Pre::Store::StatusLine {} {

    set status [Status]
    set backend [dict get $status backend]

    if {$backend eq "mysql"} {
        set enabled "off"
        if {[dict get $status mysql_enabled]} {
            set enabled "on"
        }

        set connected "no"
        if {[dict get $status mysql_connected]} {
            set connected "yes"
        }

        set tls "no"
        if {[dict get $status mysql_tls]} {
            set tls "yes"
        }

        set fallback "off"
        if {[dict get $status fallback_to_tsv]} {
            set fallback "on"
        }

        return "PRE storage: MySQL | [dict get $status host]:[dict get $status port]/[dict get $status database].[dict get $status table] | enabled $enabled | connected $connected | TLS $tls | TSV fallback $fallback"
    }

    return "PRE storage: TSV | [dict get $status path]"
}
