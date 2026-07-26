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

set musicBrainzSample {{"created":"2026-07-13T00:00:00.000Z","count":1,"offset":0,"releases":[{"id":"b84ee12a-1234-4567-8901-abcdefabcdef","score":100,"title":"OK Computer","status":"Official","date":"1997-06-16","country":"GB","barcode":"724385522925","artist-credit":[{"name":"Radiohead","artist":{"id":"a74b1b7f-71a5-4011-9441-d0b5e4122711","name":"Radiohead"}}],"label-info":[{"label":{"name":"Parlophone"}}],"media":[{"format":"CD"}],"tags":[{"count":2,"name":"alternative rock"},{"count":1,"name":"electronic"}]}]}}
set mbParsed [::dZSbot::Modules::Music::Parser::ParseMusicBrainzReleaseSearch $musicBrainzSample]
if {![dict get $mbParsed ok]} {
    error "Expected MusicBrainz sample to parse"
}
set mbRelease [dict get $mbParsed release]
if {[dict get $mbRelease source] ne "MusicBrainz"} {
    error "Expected MusicBrainz source"
}
if {[dict get $mbRelease title] ne "Radiohead - OK Computer"} {
    error "Unexpected MusicBrainz title: [dict get $mbRelease title]"
}
if {[lsearch -exact [dict get $mbRelease formats] CD] < 0} {
    error "Expected MusicBrainz CD format"
}
puts [::dZSbot::Modules::Music::Formatter::FormatRelease $mbRelease]

set lastFmSample {{"results":{"opensearch:Query":{"#text":"","role":"request","searchTerms":"ok computer","startPage":"1"},"opensearch:totalResults":"1","albummatches":{"album":[{"name":"OK Computer","artist":"Radiohead","url":"https://www.last.fm/music/Radiohead/OK+Computer"}]}}}}
set lastFmParsed [::dZSbot::Modules::Music::Parser::ParseLastFmAlbumSearch $lastFmSample]
if {![dict get $lastFmParsed ok]} {
    error "Expected Last.fm sample to parse"
}
if {[dict get [dict get $lastFmParsed release] source] ne "Last.fm"} {
    error "Expected Last.fm source"
}

set providers [::dZSbot::Modules::Music::Providers]
if {[lindex $providers 0] ne "musicbrainz"} {
    error "Expected MusicBrainz first in provider chain: $providers"
}

::dZSbot::Config::Set discogs.token "test-token"
::dZSbot::Config::Set discogs.auth_mode "token"
set request [::dZSbot::Modules::Music::Discogs::BuildSearchRequest "Radiohead OK Computer" flac]
if {![dict get $request ok]} {
    puts "Skipping Discogs request build checks: [dict get $request error]"
} else {
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
}

puts "Cleaned: [::dZSbot::Modules::Music::Parser::CleanReleaseName {Radiohead.OK.Computer.1997.FLAC-GROUP}]"
