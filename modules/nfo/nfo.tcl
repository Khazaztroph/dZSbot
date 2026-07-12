namespace eval ::dZSbot::Modules::NFO {

    variable Version "0.1.0"
}

proc ::dZSbot::Modules::NFO::Storage {} {

    return [::dZSbot::Config::Get nfo.storage [file join $::dZSbot::Root database nfo]]
}

proc ::dZSbot::Modules::NFO::CmdNfo {nick host hand chan text} {

    set release [string trim $text]

    if {$release eq ""} {
        ::dZSbot::Commands::Reply $nick $chan "Usage: !nfo <release>"
        return
    }

    set safe [string map [list "/" "_" "\\" "_" ":" "_"] $release]
    set path [file join [Storage] "$safe.nfo"]

    if {![file exists $path]} {
        ::dZSbot::Commands::Reply $nick $chan "NFO: no NFO stored for $release"
        return
    }

    set handle [open $path r]
    set firstLine [gets $handle]
    close $handle

    ::dZSbot::Commands::Reply $nick $chan "NFO: $release | $firstLine"
}

::dZSbot::Commands::Register nfo !nfo ::dZSbot::Modules::NFO::CmdNfo "Show NFO summary"

::dZSbot::ModuleManager::Register nfo [dict create \
    version $::dZSbot::Modules::NFO::Version \
    description "NFO lookup" \
    commands [::dZSbot::Commands::List nfo]]
