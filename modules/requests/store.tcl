namespace eval ::dZSbot::Modules::Requests::Store {

    variable Fields {timestamp nick request status filled_by filled_at}
}

proc ::dZSbot::Modules::Requests::Store::Path {} {

    set legacy [::dZSbot::Config::Get request.storage ""]
    if {$legacy ne ""} {
        return $legacy
    }

    return [::dZSbot::Config::Get requests.storage [file join $::dZSbot::Root database requests.tsv]]
}

proc ::dZSbot::Modules::Requests::Store::Ensure {} {

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

proc ::dZSbot::Modules::Requests::Store::Encode {value} {

    return [string map [list "\\" "\\\\" "\t" "\\t" "\n" "\\n" "\r" "\\r"] $value]
}

proc ::dZSbot::Modules::Requests::Store::Decode {value} {

    return [string map [list "\\t" "\t" "\\n" "\n" "\\r" "\r" "\\\\" "\\"] $value]
}

proc ::dZSbot::Modules::Requests::Store::NormalizeLegacyLine {line} {

    set values [lrange $line 0 2]
    return [dict create \
        timestamp [lindex $values 0] \
        nick [lindex $values 1] \
        request [lindex $values 2] \
        status open \
        filled_by "" \
        filled_at ""]
}

proc ::dZSbot::Modules::Requests::Store::All {} {

    variable Fields
    set path [Ensure]
    set handle [open $path r]
    set content [string trimright [read $handle]]
    close $handle

    if {$content eq ""} {
        return {}
    }

    set lines [split $content "\n"]
    set first [lindex $lines 0]
    set hasHeader [expr {$first eq [join $Fields "\t"]}]
    set rows {}

    foreach line [lrange $lines [expr {$hasHeader ? 1 : 0}] end] {
        if {[string trim $line] eq ""} {
            continue
        }

        if {!$hasHeader} {
            lappend rows [NormalizeLegacyLine $line]
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

proc ::dZSbot::Modules::Requests::Store::WriteAll {rows} {

    variable Fields
    set path [Ensure]
    set handle [open $path w]
    puts $handle [join $Fields "\t"]

    foreach row $rows {
        set line {}
        foreach field $Fields {
            if {[dict exists $row $field]} {
                lappend line [Encode [dict get $row $field]]
            } else {
                lappend line ""
            }
        }
        puts $handle [join $line "\t"]
    }

    close $handle
    return [llength $rows]
}

proc ::dZSbot::Modules::Requests::Store::Add {nick request} {

    set rows [All]
    set entry [dict create \
        timestamp [clock seconds] \
        nick $nick \
        request $request \
        status open \
        filled_by "" \
        filled_at ""]

    lappend rows $entry
    WriteAll $rows
    return $entry
}

proc ::dZSbot::Modules::Requests::Store::Open {{limit 10}} {

    set result {}

    foreach row [lreverse [All]] {
        if {[dict get $row status] ne "open"} {
            continue
        }

        lappend result $row
        if {[llength $result] >= $limit} {
            break
        }
    }

    return $result
}

proc ::dZSbot::Modules::Requests::Store::CountOpen {} {

    return [llength [Open 100000]]
}

proc ::dZSbot::Modules::Requests::Store::Delete {pattern} {

    set rows [All]
    set kept {}
    set deleted {}
    set lowered [string tolower $pattern]

    foreach row $rows {
        if {[dict get $row status] eq "open" && [string match "*$lowered*" [string tolower [dict get $row request]]]} {
            lappend deleted $row
        } else {
            lappend kept $row
        }
    }

    if {[llength $deleted]} {
        WriteAll $kept
    }

    return $deleted
}

proc ::dZSbot::Modules::Requests::Store::Fill {pattern nick} {

    set rows [All]
    set result {}
    set changed 0
    set lowered [string tolower $pattern]

    for {set i 0} {$i < [llength $rows]} {incr i} {
        set row [lindex $rows $i]
        if {[dict get $row status] ne "open"} {
            continue
        }
        if {![string match "*$lowered*" [string tolower [dict get $row request]]]} {
            continue
        }

        dict set row status filled
        dict set row filled_by $nick
        dict set row filled_at [clock seconds]
        lset rows $i $row
        set result $row
        set changed 1
        break
    }

    if {$changed} {
        WriteAll $rows
    }

    return $result
}
