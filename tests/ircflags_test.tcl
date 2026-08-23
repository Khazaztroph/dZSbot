set root [file normalize [pwd]]

proc botisop {chan} {
    return 1
}

proc matchattr {hand flag {chan ""}} {
    if {$hand eq "siteop" && $flag in {n m o}} {
        return 1
    }
    if {$hand eq "known" && $flag eq "v"} {
        return 1
    }
    return 0
}

set ::pushedModes {}
proc pushmode {chan mode nick} {
    lappend ::pushedModes [list $chan $mode $nick]
}

source [file join $root dZSbot.tcl]

::dZSbot::Config::Set ircflags.enabled 1
::dZSbot::Config::Set ircflags.channels {#staff #pre}
::dZSbot::Config::Set ircflags.rules {
    {o {n m o} {#staff}}
    {v {v} {#pre}}
}

::dZSbot::Modules::IRCFlags::OnJoin Boss host siteop #staff
::dZSbot::Modules::IRCFlags::OnJoin Friend host known #pre
::dZSbot::Modules::IRCFlags::OnJoin Friend host known #staff

if {[lsearch -exact $::pushedModes [list #staff +o Boss]] == -1} {
    error "Expected siteop to receive +o in #staff: $::pushedModes"
}
if {[lsearch -exact $::pushedModes [list #pre +v Friend]] == -1} {
    error "Expected known user to receive +v in #pre: $::pushedModes"
}
if {[lsearch -exact $::pushedModes [list #staff +v Friend]] != -1} {
    error "Did not expect +v in #staff: $::pushedModes"
}
