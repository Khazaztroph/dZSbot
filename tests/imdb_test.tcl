set root [file normalize [pwd]]

source [file join $root dZSbot.tcl]

set sample {{"Title":"Blade Runner","Year":"1982","Rated":"R","Released":"25 Jun 1982","Runtime":"117 min","Genre":"Action, Drama, Sci-Fi","Director":"Ridley Scott","Writer":"Hampton Fancher, David Webb Peoples","Actors":"Harrison Ford, Rutger Hauer, Sean Young","Plot":"A blade runner must pursue and terminate four replicants who stole a ship in space and have returned to Earth to find their creator.","Language":"English","Country":"United States","Awards":"Nominated for 2 Oscars. 13 wins & 22 nominations total","Poster":"N/A","Ratings":[],"Metascore":"84","imdbRating":"8.1","imdbVotes":"842,000","imdbID":"tt0083658","Type":"movie","DVD":"N/A","BoxOffice":"$32,914,489","Production":"N/A","Website":"N/A","Response":"True"}}

set parsed [::dZSbot::Modules::IMDb::Parser::ParseTitle $sample]

if {![dict get $parsed ok]} {
    error "Expected sample movie to parse"
}

set lines [::dZSbot::Modules::IMDb::Formatter::MovieLines [dict get $parsed title]]

foreach line $lines {
    puts $line
}

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

puts "Cleaned: [::dZSbot::Modules::IMDb::CleanReleaseName {The.Last.of.Us.S01E01.1080p.WEB.H264-GROUP}]"
