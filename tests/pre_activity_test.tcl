set root [file normalize [pwd]]

proc utimer {delay callback} {
    lappend ::scheduledTimers [list $delay $callback]
}

proc ioftpd {subcmd msgWindow fields} {
    if {$subcmd ne "who"} {
        error "unsupported ioftpd subcommand"
    }

    return {
        {1 user1 GROUP 1024 /MUSIC/Example.Release-GROUP/file01.flac}
        {1 user2 GROUP 512 /MUSIC/Example.Release-GROUP}
        {1 other GROUP 4096 /MOVIES/Unrelated.Release-GROUP}
        {0 idle GROUP 0 /}
    }
}

set ::scheduledTimers {}

source [file join $root dZSbot.tcl]

::dZSbot::Config::Set pre.activity.intervals {1 2}
::dZSbot::Config::Set pre.activity.channel "#pre"

set payload [dict create source nxPre section MUSIC path /MUSIC/Example.Release-GROUP release Example.Release-GROUP]
set scheduled [::dZSbot::Modules::Pre::MaybeStartActivity $payload]

if {$scheduled != 2} {
    error "Expected two PRE activity timers"
}

foreach timer $::scheduledTimers {
    puts "Timer: $timer"
}

set sample [::dZSbot::Modules::Pre::ActivitySample $payload]
set line [::dZSbot::Modules::Pre::Formatter::ActivityLine MUSIC Example.Release-GROUP 5 $sample]
puts $line

if {[dict get $sample users] != 2 || [dict get $sample speed] != 1536.0} {
    error "Expected PRE activity to count only matching release transfers: $sample"
}
if {[string first "Example.Release-GROUP :: 2 user/s :: 1.50MB/s" $line] < 0} {
    error "Expected PRE activity line to include release users and speed"
}
if {[string first "RACER" $line] < 0} {
    error "Expected PRE activity line to use RACE label"
}

set idlePayload [dict create source nxPre section MUSIC path /MUSIC/Idle.Release-GROUP release Idle.Release-GROUP]
set idleSample [::dZSbot::Modules::Pre::ActivitySample $idlePayload]
if {[dict get $idleSample users] != 0 || [dict get $idleSample speed] != 0.0} {
    error "Expected unrelated site traffic to be excluded: $idleSample"
}
if {[::dZSbot::Modules::Pre::AnnounceActivity $idlePayload 5] != 0} {
    error "Expected idle PRE activity announcement to be suppressed"
}

::dZSbot::Config::Set theme.irc.colors 1
set themedLine [::dZSbot::Modules::Pre::Formatter::ActivityLine MUSIC Example.Release-GROUP 5 $sample]
if {[string first "\003" $themedLine] < 0} {
    error "Expected PRE activity line to use the active theme"
}

set announcePayload [dict create \
    pre_type PRE \
    section MUSIC \
    release Example.Release-GROUP \
    group GROUP \
    files 2 \
    size 1536]
set resultRow [dict create \
    relname Example.Release-GROUP \
    section MUSIC \
    u_name user \
    g_name GROUP \
    pretime [clock seconds] \
    size 1536 \
    files 2]

foreach themedLine [list \
    [::dZSbot::Modules::Pre::Formatter::AnnounceLine $announcePayload] \
    [::dZSbot::Modules::Pre::Formatter::Line $resultRow 1]] {
    if {[string first "\003" $themedLine] < 0} {
        error "Expected PRE announce/result line to use the active theme: $themedLine"
    }
}
