###############################################################################
#
# dZSbot 2.0
#
# Module      : Bootstrap
# Description : Core bootstrap loader.
#
###############################################################################

namespace eval ::dZSbot::Bootstrap {

    variable Version
    variable Started

    if {![info exists Version]} {
        set Version "0.1.0"
    }

    if {![info exists Started]} {
        set Started 0
    }

}

proc ::dZSbot::Bootstrap::Banner {} {

    set bannerPath [file join $::dZSbot::Root docs banner]

    if {[file exists $bannerPath]} {
        if {[catch {
            set handle [open $bannerPath r]
            set banner [read $handle]
            close $handle
        } error]} {
            ::dZSbot::Logger::Warn "Unable to read banner: $error"
        } else {
            foreach line [split [string trimright $banner] "\n"] {
                ::dZSbot::Logger::Plain $line
            }
        }
    } else {
        ::dZSbot::Logger::Plain "\[dZSbot\]"
    }

    ::dZSbot::Logger::Plain "Version: [::dZSbot::VersionString]"
    ::dZSbot::Logger::Plain "Copyright (c) 2026 dZSbot Project"
    ::dZSbot::Logger::Plain ""
}

proc ::dZSbot::Bootstrap::InitializeCore {} {

    ::dZSbot::Logger::Initialize

    ::dZSbot::Packages::CheckTcl 1
    ::dZSbot::Config::Load [file join $::dZSbot::Root config dzsbot.conf] 1
    ::dZSbot::Health::Set core ok "initialized"
    ::dZSbot::Metrics::Set "core.started" [clock seconds]
    ::dZSbot::Metrics::Set "core.startup_us" $::dZSbot::StartupClock

}

proc ::dZSbot::Bootstrap::StatusHeader {} {

    Banner
}

proc ::dZSbot::Bootstrap::StatusLine {message} {

    ::dZSbot::Logger::Plain $message
}

proc ::dZSbot::Bootstrap::StatusResult {name status} {

    set width 15
    set dots [expr {$width - [string length $name]}]

    if {$dots < 2} {
        set dots 2
    }

    ::dZSbot::Logger::Plain [format "%s%s%s" $name [string repeat "." $dots] [string toupper $status]]
}

proc ::dZSbot::Bootstrap::ModuleDisplayName {name} {

    switch -exact -- $name {
        imdb {
            return "Movies"
        }
        pre {
            return "PRE"
        }
        nfo {
            return "NFO"
        }
        tv {
            return "TV"
        }
        default {
            return [string totitle $name]
        }
    }
}

proc ::dZSbot::Bootstrap::Ready {} {

    set elapsed \
        [expr {([clock microseconds]-$::dZSbot::StartupClock)/1000.0}]

    ::dZSbot::Logger::Info \
        [format "Core initialized in %.2f ms." $elapsed]

    ::dZSbot::Logger::Info "Ready."

}

proc ::dZSbot::Bootstrap::Start {} {

    variable Started

    if {$Started} {
        ::dZSbot::Logger::Warn "Bootstrap already started; ignoring duplicate start."
        return
    }

    set Started 1

    ::dZSbot::Logger::Initialize

    StatusHeader
    StatusLine "Loading Core..."
    InitializeCore

    StatusLine "Loading Logger..."
    StatusLine "Loading Database..."
    ::dZSbot::Database::Initialize

    StatusLine "Loading Theme..."
    ::dZSbot::Theme::Initialize
    ::dZSbot::SiteAdapter::ValidatePolicy

    StatusLine "Loading Modules..."
    StatusLine "Modules..."
    StatusLine ""

    set modules [::dZSbot::ModuleManager::LoadDiscoveredDetailed "" 1]
    set loadedCount 0

    dict for {name status} $modules {
        if {$status eq "ok"} {
            incr loadedCount
        }
        StatusResult [ModuleDisplayName $name] $status
    }

    StatusLine ""
    ::dZSbot::SiteAdapter::StartNxPreWatcher
    ::dZSbot::UpdateCheck::Start
    ::dZSbot::Transport::Publish core.ready [dict create loadedModules $loadedCount]
    ::dZSbot::Health::WriteHeartbeat

    StatusLine "dZSbot loaded and ready."
}
