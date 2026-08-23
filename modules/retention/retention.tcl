namespace eval ::dZSbot::Modules::Retention {

    variable Version "0.1.0"
}

proc ::dZSbot::Modules::Retention::CmdRetention {nick host hand chan text} {

    set summary [::dZSbot::Health::Summary]
    set overall [dict get $summary overall]

    ::dZSbot::Commands::Reply $nick $chan "Retention: OK | Core health: [string toupper $overall]"
}

proc ::dZSbot::Modules::Retention::CmdStatus {nick host hand chan text} {

    set replyTarget [StatusReplyTarget $nick $chan]

    set text [string trim $text]
    if {$text eq "status"} {
        CmdAdminStatus $nick $host $hand $chan $text
        return
    }

    set modules [::dZSbot::ModuleManager::List]
    set commands [::dZSbot::Commands::List]
    ::dZSbot::Commands::Reply $nick $replyTarget "dZSbot: [llength $modules] modules loaded, [llength $commands] commands registered."
}

proc ::dZSbot::Modules::Retention::CmdAdminStatus {nick host hand chan text} {

    set replyTarget [StatusReplyTarget $nick $chan]

    if {![AdminAllowed $nick $hand $chan]} {
        ::dZSbot::Commands::Reply $nick $replyTarget "dZSbot: status requires channel op in [::dZSbot::Config::Get status.admin_channel "#staff"]."
        return
    }

    set summary [::dZSbot::Health::Summary]
    set modules [::dZSbot::ModuleManager::List]
    set commands [::dZSbot::Commands::List]
    set policy [::dZSbot::SiteAdapter::Policy]

    ::dZSbot::Commands::Reply $nick $replyTarget "dZSbot status: [string toupper [dict get $summary overall]] | modules [llength $modules] | commands [llength $commands]"
    ::dZSbot::Commands::Reply $nick $replyTarget "Site: [dict get $policy adapter] | [dict get $policy host]:[dict get $policy port] | transport [dict get $policy command_transport] | TLS [dict get $policy tls_min_version]"
    if {[llength [info commands ::dZSbot::Modules::Pre::Store::StatusLine]]} {
        ::dZSbot::Commands::Reply $nick $replyTarget [::dZSbot::Modules::Pre::Store::StatusLine]
    }
    ::dZSbot::Commands::Reply $nick $replyTarget "Modules: [join $modules {, }]"

    set components {}
    dict for {component entry} [dict get $summary components] {
        lappend components "$component=[string toupper [dict get $entry status]]"
    }

    if {[llength $components]} {
        ::dZSbot::Commands::Reply $nick $replyTarget "Health: [join $components { | }]"
    }
}

proc ::dZSbot::Modules::Retention::StatusReplyTarget {nick chan} {

    set target [string tolower [::dZSbot::Config::Get status.reply_target "channel"]]
    if {$target in {private privmsg pm query nick user} && $nick ne ""} {
        return $nick
    }

    return $chan
}

proc ::dZSbot::Modules::Retention::AdminAllowed {nick hand chan} {

    set adminChan [::dZSbot::Config::Get status.admin_channel "#staff"]
    if {$adminChan ne "" && ![string equal -nocase $chan $adminChan]} {
        return 0
    }

    if {![::dZSbot::Config::Get status.require_channel_op 1]} {
        return 1
    }

    if {[llength [info commands ::isop]] && [::isop $nick $chan]} {
        return 1
    }

    if {[llength [info commands ::matchattr]] && $hand ne ""} {
        foreach flags {n m o} {
            if {[::matchattr $hand $flags $chan]} {
                return 1
            }
        }
    }

    if {![llength [info commands ::isop]] && ![llength [info commands ::matchattr]]} {
        return 1
    }

    return 0
}

::dZSbot::Commands::Register retention !retention ::dZSbot::Modules::Retention::CmdRetention "Show retention status"
::dZSbot::Commands::Register retention !status ::dZSbot::Modules::Retention::CmdStatus "Show bot status"
::dZSbot::Commands::Register retention !dzsbot ::dZSbot::Modules::Retention::CmdStatus "Show bot status"
::dZSbot::Commands::Register retention !dzb ::dZSbot::Modules::Retention::CmdStatus "Show bot status"

::dZSbot::ModuleManager::Register retention [dict create \
    version $::dZSbot::Modules::Retention::Version \
    description "Retention and status" \
    commands [::dZSbot::Commands::List retention]]
