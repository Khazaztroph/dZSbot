set root [file normalize [pwd]]

proc utimer {delay callback} {
    lappend ::scheduledTimers [list $delay $callback]
}

proc ioftpd {subcmd msgWindow fields} {
    if {$subcmd ne "who"} {
        error "unsupported ioftpd subcommand"
    }

    return {
        {1 user1 GROUP 1024 /MUSIC/Release}
        {1 user2 GROUP 512 /MUSIC/Release}
        {0 idle GROUP 0 /}
    }
}

set ::scheduledTimers {}

source [file join $root dZSbot.tcl]

::dZSbot::Config::Set pre.activity.intervals {1 2}
::dZSbot::Config::Set pre.activity.channel "#pre"

set payload [dict create source nxPre section MUSIC release Example.Release-GROUP]
set scheduled [::dZSbot::Modules::Pre::MaybeStartActivity $payload]

if {$scheduled != 2} {
    error "Expected two PRE activity timers"
}

foreach timer $::scheduledTimers {
    puts "Timer: $timer"
}

set sample [::dZSbot::Modules::Pre::ActivitySample]
set line [::dZSbot::Modules::Pre::Formatter::ActivityLine MUSIC Example.Release-GROUP 5 $sample]
puts $line

if {[string first "2@1.50 MB/s" $line] < 0} {
    error "Expected PRE activity line to include users and speed"
}
