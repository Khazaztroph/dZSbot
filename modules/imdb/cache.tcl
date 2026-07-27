namespace eval ::dZSbot::Modules::IMDb::Cache {

    variable Values
    variable Times
    array set Values {}
    array set Times {}
}

proc ::dZSbot::Modules::IMDb::Cache::Key {query} {

    return [string tolower [string trim $query]]
}

proc ::dZSbot::Modules::IMDb::Cache::Get {query ttl} {

    variable Values
    variable Times

    set key [Key $query]

    if {![info exists Values($key)]} {
        return ""
    }

    if {[expr {[clock seconds] - $Times($key)}] > $ttl} {
        unset Values($key)
        unset Times($key)
        return ""
    }

    return $Values($key)
}

proc ::dZSbot::Modules::IMDb::Cache::Set {query data} {

    variable Values
    variable Times

    set key [Key $query]
    set Values($key) $data
    set Times($key) [clock seconds]

    return $data
}

proc ::dZSbot::Modules::IMDb::Cache::Delete {query} {

    variable Values
    variable Times

    set key [Key $query]
    unset -nocomplain Values($key)
    unset -nocomplain Times($key)
}
