namespace eval ::dZSbot::Modules::IMDb {}

proc ::dZSbot::Modules::IMDb::CmdMovie {nick host hand chan text} {

    set query [string trim $text]

    if {$query eq ""} {
        ::dZSbot::Commands::Reply $nick $chan "Usage: !imdb <movie title|ttxxxxxxx>"
        return
    }

    if {![::dZSbot::Modules::IMDb::ChannelEnabled $chan]} {
        return
    }

    if {![::dZSbot::Modules::IMDb::FloodAllowed]} {
        ::dZSbot::Commands::Reply $nick $chan "IMDb: flood protection active."
        return
    }

    set result [::dZSbot::Modules::IMDb::Lookup $query]

    if {![dict get $result ok]} {
        ::dZSbot::Commands::Reply $nick $chan "IMDb: [dict get $result error]"
        return
    }

    foreach line [dict get $result lines] {
        ::dZSbot::Commands::Reply $nick $chan $line
    }
}

proc ::dZSbot::Modules::IMDb::RegisterCommands {} {

    ::dZSbot::Commands::Register imdb !imdb ::dZSbot::Modules::IMDb::CmdMovie "Search OMDb/IMDb"
    ::dZSbot::Commands::Register imdb !movie ::dZSbot::Modules::IMDb::CmdMovie "Search OMDb/IMDb"
    ::dZSbot::Commands::Register imdb !movies ::dZSbot::Modules::IMDb::CmdMovie "Search OMDb/IMDb"
}
