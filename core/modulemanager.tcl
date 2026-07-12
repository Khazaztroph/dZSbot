###############################################################################
#
# dZSbot 2.0
#
# Module      : Module Manager
# Description : Module registry and isolated module loader.
#
###############################################################################

namespace eval ::dZSbot::ModuleManager {

    variable Modules
    array set Modules {}
    variable Quiet 0
}

proc ::dZSbot::ModuleManager::Register {name metadata} {

    variable Modules
    variable Quiet

    dict set metadata name $name
    dict set metadata registered [clock seconds]
    set Modules($name) $metadata

    ::dZSbot::Health::Set "module:$name" ok "registered"
    if {!$Quiet} {
        ::dZSbot::Logger::Info "Module registered: $name"
    }

    return $Modules($name)
}

proc ::dZSbot::ModuleManager::Load {name path} {

    if {![file exists $path]} {
        ::dZSbot::Health::Set "module:$name" error "missing: $path"
        ::dZSbot::Logger::Warn "Module '$name' not found: $path"
        return 0
    }

    LoadConfig $name

    if {[catch {uplevel #0 [list source $path]} error options]} {
        ::dZSbot::Health::Set "module:$name" error $error
        ::dZSbot::Metrics::Increment "modules.errors"
        ::dZSbot::Logger::Error "Module '$name' failed to load: $error"
        return 0
    }

    ::dZSbot::Metrics::Increment "modules.loaded"

    if {![Exists $name]} {
        Register $name [dict create path $path status loaded]
    }

    ::dZSbot::Health::Set "module:$name" ok "loaded"
    return 1
}

proc ::dZSbot::ModuleManager::LoadConfig {name} {

    set configPath [file join $::dZSbot::Root config modules "${name}.conf"]

    if {![file exists $configPath]} {
        ::dZSbot::Logger::Debug "Module config not found for $name: $configPath"
        return 0
    }

    return [::dZSbot::Config::Load $configPath 1]
}

proc ::dZSbot::ModuleManager::Discover {{root ""}} {

    if {$root eq ""} {
        set root [file join $::dZSbot::Root modules]
    }

    set found {}

    if {![file isdirectory $root]} {
        return $found
    }

    foreach dir [lsort [glob -nocomplain -types d -directory $root *]] {
        set name [file tail $dir]
        set main [file join $dir "$name.tcl"]

        if {[file exists $main]} {
            dict set found $name $main
        }
    }

    return $found
}

proc ::dZSbot::ModuleManager::LoadDiscovered {{root ""}} {

    set loaded 0
    dict for {name path} [Discover $root] {
        if {[Load $name $path]} {
            incr loaded
        }
    }

    return $loaded
}

proc ::dZSbot::ModuleManager::LoadDiscoveredDetailed {{root ""} {quiet 0}} {

    variable Quiet

    set previousQuiet $Quiet
    set Quiet $quiet
    set result {}

    dict for {name path} [Discover $root] {
        if {[Load $name $path]} {
            dict set result $name ok
        } else {
            dict set result $name error
        }
    }

    set Quiet $previousQuiet
    return $result
}

proc ::dZSbot::ModuleManager::Exists {name} {

    variable Modules
    return [info exists Modules($name)]
}

proc ::dZSbot::ModuleManager::Get {name} {

    variable Modules

    if {[info exists Modules($name)]} {
        return $Modules($name)
    }

    return {}
}

proc ::dZSbot::ModuleManager::List {} {

    variable Modules
    return [lsort [array names Modules]]
}

namespace eval ::dZSbot::PluginManager {}

foreach procName {Register Load LoadConfig Discover LoadDiscovered LoadDiscoveredDetailed Exists Get List} {
    proc ::dZSbot::PluginManager::$procName {args} [format {
        tailcall ::dZSbot::ModuleManager::%s {*}$args
    } $procName]
}
