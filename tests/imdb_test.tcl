set root [file normalize [pwd]]

source [file join $root dZSbot.tcl]

set sample {{"Title":"Blade Runner","Year":"1982","Rated":"R","Released":"25 Jun 1982","Runtime":"117 min","Genre":"Action, Drama, Sci-Fi","Director":"Ridley Scott","Writer":"Hampton Fancher, David Webb Peoples","Actors":"Harrison Ford, Rutger Hauer, Sean Young","Plot":"A blade runner must pursue and terminate four replicants who stole a ship in space and have returned to Earth to find their creator.","Language":"English","Country":"United States","Awards":"Nominated for 2 Oscars. 13 wins & 22 nominations total","Poster":"N/A","Ratings":[],"Metascore":"84","imdbRating":"8.1","imdbVotes":"842,000","imdbID":"tt0083658","Type":"movie","DVD":"N/A","BoxOffice":"$32,914,489","Production":"N/A","Website":"N/A","Response":"True"}}

set parsed [::dZSbot::Modules::IMDb::Parser::ParseTitle $sample]

if {![dict get $parsed ok]} {
    error "Expected sample movie to parse"
}

set lines [::dZSbot::Modules::IMDb::Formatter::MovieLines [dict get $parsed title]]

if {[lindex $lines 0] ne "\002Blade Runner\002 (1982) | Movie | 117 min"} {
    error "Unexpected default IMDb detail title: [lindex $lines 0]"
}
if {[lindex $lines 2] ne "IMDb: 8.1/10 ********-- (842,000 votes)"} {
    error "Unexpected default IMDb rating detail: [lindex $lines 2]"
}
if {[::dZSbot::Modules::IMDb::Formatter::DetailHeader Example.Release] ne "IMDb details for Example.Release:"} {
    error "Unexpected default IMDb detail header"
}

foreach line $lines {
    puts $line
}

::dZSbot::Config::Set theme.irc.colors 1
set themedLines [::dZSbot::Modules::IMDb::Formatter::MovieLines [dict get $parsed title]]
foreach themedLine $themedLines {
    if {[string first "\003" $themedLine] < 0} {
        error "Expected every IMDb detail line to use the active theme: $themedLine"
    }
}
if {[string first "\003" [::dZSbot::Modules::IMDb::Formatter::DetailHeader Example.Release]] < 0} {
    error "Expected IMDb detail header to use the active theme"
}
::dZSbot::Config::Set theme.irc.colors 0

set series {{"Title":"The Last of Us","Year":"2023–","Runtime":"50 min","Genre":"Action, Adventure, Drama","Director":"N/A","Actors":"Pedro Pascal, Bella Ramsey","Plot":"After a global pandemic destroys civilization, a hardened survivor takes charge of a child who may be humanity's last hope.","imdbRating":"8.7","imdbVotes":"600,000","imdbID":"tt3581920","Type":"series","totalSeasons":"2","Response":"True"}}
set parsedSeries [::dZSbot::Modules::IMDb::Parser::ParseTitle $series]

if {![dict get $parsedSeries ok]} {
    error "Expected sample series to parse"
}

puts [::dZSbot::Modules::IMDb::Formatter::PublicLine [dict get $parsedSeries title]]

set uploadLine [::dZSbot::Modules::IMDb::Formatter::PublicLine [dict get $parsedSeries title] {The.Last.of.Us.S01E01.1080p.WEB.H264-GROUP}]
if {[string first {Rel: The.Last.of.Us.S01E01.1080p.WEB.H264-GROUP} $uploadLine] < 0} {
    error "Expected IMDb upload line to include release folder"
}
puts $uploadLine

set tvRelease [::dZSbot::Modules::IMDb::ParseReleaseName {The.Last.of.Us.S01E01.1080p.WEB.H264-GROUP}]
if {[dict get $tvRelease title] ne "The Last of Us" || [dict get $tvRelease year] ne ""} {
    error "Unexpected parsed TV release: $tvRelease"
}

set movieRelease [::dZSbot::Modules::IMDb::ParseReleaseName {Blade.Runner.1982.1080p.BluRay.x264-GROUP}]
if {[dict get $movieRelease title] ne "Blade Runner" || [dict get $movieRelease year] ne "1982"} {
    error "Unexpected parsed movie release: $movieRelease"
}

set nordicRelease [::dZSbot::Modules::IMDb::ParseReleaseName {Zodiac.2007.NORDiC.1080p.BluRay.x264-RAPiDCOWS}]
if {[dict get $nordicRelease title] ne "Zodiac" || [dict get $nordicRelease year] ne "2007"} {
    error "Unexpected parsed Nordic movie release: $nordicRelease"
}

set complexRelease [::dZSbot::Modules::IMDb::ParseReleaseName {Mission.Impossible.The.Final.Reckoning.2025.2160p.WEB-DL.DDP5.1.Atmos.H.265-GROUP}]
if {[dict get $complexRelease title] ne "Mission Impossible The Final Reckoning" || [dict get $complexRelease year] ne "2025"} {
    error "Unexpected parsed complex release: $complexRelease"
}

set numberedTitle [::dZSbot::Modules::IMDb::ParseReleaseName {Blade.Runner.2049.2017.1080p.BluRay.x264-GROUP}]
if {[dict get $numberedTitle title] ne "Blade Runner 2049" || [dict get $numberedTitle year] ne "2017"} {
    error "Unexpected parsed numbered title: $numberedTitle"
}

package require http
set movieUrl [::dZSbot::Modules::IMDb::OMDb::BuildUrl "https://www.omdbapi.com/" "KEY" [dict get $movieRelease title] "" [dict get $movieRelease year]]
if {[string first "t=Blade%20Runner" $movieUrl] < 0 || [string first "y=1982" $movieUrl] < 0} {
    error "Expected a clean title and separate year in OMDb URL: $movieUrl"
}

rename ::dZSbot::Modules::IMDb::Lookup ::dZSbot::Modules::IMDb::LookupReal
proc ::dZSbot::Modules::IMDb::Lookup {query {type ""} {year ""}} {
    set ::newUploadLookup [list $query $type $year]
    return [dict create ok 1 title [dict get $::parsed title] lines {}]
}
::dZSbot::Modules::IMDb::OnSiteRelease site.newdir [dict create \
    section MOVIES \
    release {Zodiac.2007.NORDiC.1080p.BluRay.x264-RAPiDCOWS}]
rename ::dZSbot::Modules::IMDb::Lookup {}
rename ::dZSbot::Modules::IMDb::LookupReal ::dZSbot::Modules::IMDb::Lookup

if {$::newUploadLookup ne [list "Zodiac" "" "2007"]} {
    error "NEW upload used unexpected OMDb lookup arguments: $::newUploadLookup"
}

puts "Parsed NEW release: $movieRelease"
