namespace eval ::dZSbot::Modules::IRCFlags {

    variable Version "0.1.0"
}

proc ::dZSbot::Modules::IRCFlags::Initialize {} {

    if {[llength [info commands ::bind]]} {
        catch {::unbind join - * ::dZSbot::Modules::IRCFlags::OnJoin}
        ::bind join - * ::dZSbot::Modules::IRCFlags::OnJoin
    }
}

proc ::dZSbot::Modules::IRCFlags::OnJoin {nick host hand chan} {

    if {![::dZSbot::Config::Get ircflags.enabled 0]} {
        return
    }
    if {![ChannelAllowed $chan]} {
        return
    }
    if {[llength [info commands ::botisop]] && ![::botisop $chan]} {
        return
    }

    foreach rule [::dZSbot::Config::Get ircflags.rules {}] {
        set parsed [ParseRule $rule]
        if {![dict get $parsed ok]} {
            ::dZSbot::Logger::Warn "Skipping IRC flag rule: [dict get $parsed error]"
            continue
        }
        if {![RuleChannelAllowed $parsed $chan]} {
            continue
        }
        if {![RuleMatches $parsed $nick $hand $chan]} {
            continue
        }

        GiveMode $chan $nick [dict get $parsed mode]
    }
}

proc ::dZSbot::Modules::IRCFlags::ParseRule {rule} {

    if {[catch {set count [llength $rule]} error]} {
        return [dict create ok 0 error $error]
    }
    if {$count < 2} {
        return [dict create ok 0 error "expected {mode flags ?channels?}"]
    }

    set mode [string trimleft [lindex $rule 0] "+"]
    set flags [lindex $rule 1]
    set channels {}
    if {$count >= 3} {
        set channels [lindex $rule 2]
    }

    if {![regexp {^[A-Za-z]$} $mode]} {
        return [dict create ok 0 error "invalid IRC mode: $mode"]
    }

    return [dict create ok 1 mode $mode flags $flags channels $channels]
}

proc ::dZSbot::Modules::IRCFlags::RuleMatches {rule nick hand chan} {

    set flags [dict get $rule flags]
    if {$flags eq "*" || $flags eq {}} {
        return 1
    }
    if {$hand eq "" || $hand eq "*"} {
        return 0
    }
    if {![llength [info commands ::matchattr]]} {
        return 0
    }

    foreach flag $flags {
        if {[::matchattr $hand $flag $chan] || [::matchattr $hand $flag]} {
            return 1
        }
    }

    return 0
}

proc ::dZSbot::Modules::IRCFlags::ChannelAllowed {chan} {

    set channels [::dZSbot::Config::Get ircflags.channels {}]
    if {![llength $channels]} {
        return 1
    }

    foreach allowed $channels {
        if {[string equal -nocase $allowed $chan]} {
            return 1
        }
    }

    return 0
}

proc ::dZSbot::Modules::IRCFlags::RuleChannelAllowed {rule chan} {

    set channels [dict get $rule channels]
    if {![llength $channels]} {
        return 1
    }

    foreach allowed $channels {
        if {[string equal -nocase $allowed $chan]} {
            return 1
        }
    }

    return 0
}

proc ::dZSbot::Modules::IRCFlags::GiveMode {chan nick mode} {

    if {[llength [info commands ::pushmode]]} {
        ::pushmode $chan +$mode $nick
        return
    }
    if {[llength [info commands ::putquick]]} {
        ::putquick "MODE $chan +$mode $nick"
    } elseif {[llength [info commands ::putserv]]} {
        ::putserv "MODE $chan +$mode $nick"
    }
}

::dZSbot::Modules::IRCFlags::Initialize

::dZSbot::ModuleManager::Register ircflags [dict create \
    version $::dZSbot::Modules::IRCFlags::Version \
    description "Auto IRC mode assignment from Eggdrop user flags" \
    commands {}]
