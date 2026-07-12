set root [file normalize [pwd]]

source [file join $root dZSbot.tcl]

set sample {{"pagination":{"page":1,"pages":1,"per_page":1,"items":1},"results":[{"country":"UK","year":"1997","format":["CD","Album"],"label":["Parlophone"],"type":"release","genre":["Electronic","Rock"],"style":["Alternative Rock"],"id":123,"barcode":[],"master_id":456,"master_url":"https://api.discogs.com/masters/456","uri":"/Radiohead-OK-Computer/release/123","catno":"CDNODATA 02","title":"Radiohead - OK Computer","thumb":"","cover_image":"","resource_url":"https://api.discogs.com/releases/123"}]}}

set parsed [::dZSbot::Modules::Music::Parser::ParseDiscogsSearch $sample]
if {![dict get $parsed ok]} {
    error "Expected Discogs sample to parse"
}

puts [::dZSbot::Modules::Music::Formatter::FormatDiscogsRelease [dict get $parsed release]]

set uploadLine [::dZSbot::Modules::Music::Formatter::PublicLine [dict get $parsed release] {Radiohead.OK.Computer.1997.FLAC-GROUP}]
if {[string first {Rel: Radiohead.OK.Computer.1997.FLAC-GROUP} $uploadLine] < 0} {
    error "Expected Music upload line to include release folder"
}
puts $uploadLine

set flacPreLine [::dZSbot::Modules::Music::Formatter::PublicLine [dict get $parsed release] {Radiohead.OK.Computer.1997.FLAC-GROUP} PRE-FLAC MUSIC]
if {[string first {PRE-FLAC} $flacPreLine] < 0} {
    error "Expected Music PRE-FLAC line to include PRE-FLAC tag"
}
puts $flacPreLine

::dZSbot::Config::Set discogs.token "test-token"
::dZSbot::Config::Set discogs.auth_mode "token"
set request [::dZSbot::Modules::Music::Discogs::BuildSearchRequest "Radiohead OK Computer" flac]
if {![dict get $request ok]} {
    error "Expected Discogs token request to build"
}
if {[lsearch -exact [dict get $request headers] "Discogs token=test-token"] < 0} {
    error "Expected Discogs Authorization token header"
}

::dZSbot::Config::Set discogs.auth_mode "query_token"
set queryRequest [::dZSbot::Modules::Music::Discogs::BuildSearchRequest "Radiohead OK Computer" mp3]
if {[string first "token=test-token" [dict get $queryRequest url]] < 0} {
    error "Expected Discogs query token URL"
}

::dZSbot::Config::Set discogs.auth_mode "oauth"
::dZSbot::Config::Set discogs.consumer_key "consumer-key"
::dZSbot::Config::Set discogs.consumer_secret "consumer-secret"
::dZSbot::Config::Set discogs.oauth.access_token "access-token"
::dZSbot::Config::Set discogs.oauth.access_token_secret "access-secret"
set oauthRequest [::dZSbot::Modules::Music::Discogs::BuildSearchRequest "Radiohead OK Computer" flac]
if {![dict get $oauthRequest ok]} {
    error "Expected Discogs OAuth request to build: [dict get $oauthRequest error]"
}
if {[string first "OAuth" [dict get $oauthRequest headers]] < 0} {
    error "Expected Discogs OAuth Authorization header"
}

puts "Cleaned: [::dZSbot::Modules::Music::Parser::CleanReleaseName {Radiohead.OK.Computer.1997.FLAC-GROUP}]"
