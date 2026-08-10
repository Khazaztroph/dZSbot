set root [file normalize [pwd]]

source [file join $root dZSbot.tcl]

::dZSbot::Config::Set theme.irc.colors 0

package require http

if {![::dZSbot::Modules::IMDb::ShouldLookupSection MOVIES]} {
    error "Expected IMDb announce to handle MOVIES"
}
if {![::dZSbot::Modules::IMDb::ShouldLookupSection MOVIE-2160P]} {
    error "Expected IMDb announce to handle MOVIE-2160P"
}
if {[::dZSbot::Modules::IMDb::ShouldLookupSection TV]} {
    error "Expected IMDb announce not to handle TV"
}
if {![::dZSbot::Modules::TV::ShouldLookupSection TV]} {
    error "Expected TV announce to handle TV"
}
if {![::dZSbot::Modules::TV::ShouldLookupSection TV-1080P]} {
    error "Expected TV announce to handle TV-1080P"
}
if {[::dZSbot::Modules::TV::ShouldLookupSection MOVIES]} {
    error "Expected TV announce not to handle MOVIES"
}

set url [::dZSbot::Modules::IMDb::OMDb::BuildUrl "https://www.omdbapi.com/" "KEY" "The Last of Us" series]
if {[string first "type=series" $url] < 0} {
    error "Expected OMDb TV lookup URL to include type=series: $url"
}

set cleaned [::dZSbot::Modules::TV::CleanReleaseName {The.Last.of.Us.S01E01.1080p.WEB.H264-GROUP}]
if {$cleaned ne "The Last of Us"} {
    error "Unexpected cleaned TV release name: $cleaned"
}

set series {{"Title":"The Last of Us","Year":"2023-","Runtime":"50 min","Genre":"Action, Adventure, Drama","Director":"N/A","Actors":"Pedro Pascal, Bella Ramsey","Plot":"After a global pandemic destroys civilization, a hardened survivor takes charge of a child who may be humanity's last hope.","imdbRating":"8.7","imdbVotes":"600,000","imdbID":"tt3581920","Type":"series","totalSeasons":"2","Response":"True"}}
set parsed [::dZSbot::Modules::IMDb::Parser::ParseTitle $series]
if {![dict get $parsed ok]} {
    error "Expected sample TV series to parse"
}

set publicLine [::dZSbot::Modules::TV::PublicLine [dict get $parsed title] {The.Last.of.Us.S01E01.1080p.WEB.H264-GROUP}]
if {[string first {Rel: The.Last.of.Us.S01E01.1080p.WEB.H264-GROUP} $publicLine] < 0} {
    error "Expected TV public line to include release folder"
}
if {[string first {TV Series} $publicLine] < 0} {
    error "Expected TV public line to identify TV Series"
}

if {[::dZSbot::Modules::TV::DetailHeader Example.Series] ne "TV details for Example.Series:"} {
    error "Unexpected default TV detail header"
}

::dZSbot::Config::Set theme.irc.colors 1
if {[string first "\003" [::dZSbot::Modules::TV::DetailHeader Example.Series]] < 0} {
    error "Expected TV detail header to use the active theme"
}
foreach detailLine [::dZSbot::Modules::TV::TVLines [dict get $parsed title]] {
    if {[string first "\003" $detailLine] < 0} {
        error "Expected every TV detail line to use the active theme: $detailLine"
    }
}
::dZSbot::Config::Set theme.irc.colors 0

puts "TV compatibility lookup OK: $publicLine"
