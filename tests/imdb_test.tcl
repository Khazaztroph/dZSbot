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

set badBoyRelease [::dZSbot::Modules::IMDb::ParseReleaseName {Bad.Boy.in.Love.2024.720p.WEB.H264-AFO}]
if {[dict get $badBoyRelease title] ne "Bad Boy in Love" || [dict get $badBoyRelease year] ne "2024"} {
    error "Unexpected parsed Bad Boy in Love release: $badBoyRelease"
}

set searchUrl [::dZSbot::Modules::IMDb::OMDb::BuildSearchUrl \
    "https://www.omdbapi.com/" \
    "KEY" \
    [dict get $badBoyRelease title] \
    movie \
    [dict get $badBoyRelease year]]
if {[string first "s=Bad%20Boy%20in%20Love" $searchUrl] < 0 ||
    [string first "type=movie" $searchUrl] < 0 ||
    [string first "y=2024" $searchUrl] < 0} {
    error "Expected OMDb fallback search URL to include title, type and year: $searchUrl"
}

set notFoundResponse {{"Response":"False","Error":"Movie not found!"}}
if {![::dZSbot::Modules::IMDb::OMDb::ShouldSearchFallback $notFoundResponse]} {
    error "Expected Movie not found response to trigger OMDb search fallback"
}
if {[::dZSbot::Modules::IMDb::OMDb::ShouldSearchFallback {{"Response":"False","Error":"Invalid API key!"}}]} {
    error "Expected API errors not to trigger OMDb search fallback"
}

set searchResponse {{"Search":[{"Title":"Bad Boy in Love","Year":"2024","imdbID":"tt27524980","Type":"movie","Poster":"N/A"},{"Title":"Bad Boys","Year":"1995","imdbID":"tt0112442","Type":"movie","Poster":"N/A"}],"totalResults":"2","Response":"True"}}
set selectedId [::dZSbot::Modules::IMDb::OMDb::SelectSearchResult \
    $searchResponse \
    "Bad Boy in Love" \
    movie \
    2024]
if {$selectedId ne "tt27524980"} {
    error "Expected fallback search to select tt27524980, got: $selectedId"
}

::dZSbot::Config::Set omdb.api_key KEY
::dZSbot::Config::Set omdb.endpoint http://example.test/
::dZSbot::Config::Set omdb.search_fallback 1
set ::fallbackUrls {}
rename ::dZSbot::Modules::IMDb::OMDb::Request ::dZSbot::Modules::IMDb::OMDb::RequestReal
proc ::dZSbot::Modules::IMDb::OMDb::Request {url timeout} {
    lappend ::fallbackUrls $url
    if {[string first "t=Bad%20Boy%20in%20Love" $url] >= 0} {
        return [dict create ok 1 data $::notFoundResponse]
    }
    if {[string first "s=Bad%20Boy%20in%20Love" $url] >= 0} {
        return [dict create ok 1 data $::searchResponse]
    }
    if {[string first "i=tt27524980" $url] >= 0} {
        return [dict create ok 1 data $::sample]
    }
    return [dict create ok 0 error "Unexpected fallback URL: $url"]
}
set fallbackResult [::dZSbot::Modules::IMDb::OMDb::Fetch "Bad Boy in Love" movie 2024]
rename ::dZSbot::Modules::IMDb::OMDb::Request {}
rename ::dZSbot::Modules::IMDb::OMDb::RequestReal ::dZSbot::Modules::IMDb::OMDb::Request
::dZSbot::Config::Set omdb.api_key ""
::dZSbot::Config::Set omdb.endpoint https://www.omdbapi.com/

if {![dict get $fallbackResult ok] || [dict get $fallbackResult data] ne $sample} {
    error "Expected exact lookup, search fallback and IMDb ID lookup to succeed: $fallbackResult"
}
if {[llength $::fallbackUrls] != 3} {
    error "Expected three OMDb requests during fallback, got: $::fallbackUrls"
}

set cacheRetryKey "movie:Bad Boy in Love:2024"
::dZSbot::Modules::IMDb::Cache::Set $cacheRetryKey $notFoundResponse
set ::cacheRetryFetches 0
rename ::dZSbot::Modules::IMDb::OMDb::Fetch ::dZSbot::Modules::IMDb::OMDb::FetchReal
proc ::dZSbot::Modules::IMDb::OMDb::Fetch {query {type ""} {year ""}} {
    incr ::cacheRetryFetches
    return [dict create ok 1 data $::sample]
}
set cacheRetryResult [::dZSbot::Modules::IMDb::Lookup "Bad Boy in Love" movie 2024]
rename ::dZSbot::Modules::IMDb::OMDb::Fetch {}
rename ::dZSbot::Modules::IMDb::OMDb::FetchReal ::dZSbot::Modules::IMDb::OMDb::Fetch

if {![dict get $cacheRetryResult ok] || $::cacheRetryFetches != 1} {
    error "Expected a cached not-found response to be discarded and retried"
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
