set root [file normalize [pwd]]

proc ioftpd {command messageWindow fields} {
    if {$command ne "who"} {
        error "unexpected ioftpd command: $command"
    }
    return [list \
        [list 1 user1 GROUP 2048 /MOVIES/Example.Release-GRP] \
        [list 0 user2 GROUP 0 /TV/Idle.Show-GRP]]
}

source [file join $root dZSbot.tcl]

set tempSection [file join $root runtime]
::dZSbot::Config::Set site.df.sections [list [list RUNTIME $tempSection]]

set commands [::dZSbot::Commands::List site]
if {"!df" ni $commands || "!bw" ni $commands} {
    error "Expected !df and !bw to be registered by site module: $commands"
}

set bw [::dZSbot::Modules::Site::TransferSample]
if {![dict get $bw available]} {
    error "Expected mocked ioftpd who to be available"
}
if {[dict get $bw active] != 1 || [dict get $bw total] != 2} {
    error "Unexpected BW sample: $bw"
}

set df [::dZSbot::Modules::Site::DiskFree $tempSection]
if {![dict get $df ok]} {
    error "Expected runtime disk free to be readable: $df"
}

::dZSbot::Commands::Dispatch !bw tester host hand #chan ""
::dZSbot::Commands::Dispatch !df tester host hand #chan "runtime"
