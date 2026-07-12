set root [file normalize [pwd]]

source [file join $root dZSbot.tcl]

set policy [::dZSbot::SiteAdapter::Policy]

if {[dict get $policy port] != 5420} {
    error "Expected site port 5420, got [dict get $policy port]"
}

if {[dict get $policy passive_ports] ne "5421-5450"} {
    error "Expected passive ports 5421-5450, got [dict get $policy passive_ports]"
}

puts "Site policy: $policy"

set preLine {PRE: "/MP3/Radiohead.OK.Computer.1997.FLAC-GROUP" "MUSICGROUP" "khaza" "USERS" "MP3" "12" "7340032" "1"}
set mp3Line {PRE-MP3: "/MP3/Example.Artist.Example.Album.2026.MP3-GROUP" "MP3GROUP" "khaza" "USERS" "MP3" "10" "102400" "1" "Example Artist" "Example Album" "Electronic" "2026" "320" "CBR"}
set flacLine {PRE-FLAC: "/MUSIC/Daft.Punk.Random.Access.Memories.2013.FLAC-GROUP" "FLACGROUP" "khaza" "USERS" "MUSIC" "13" "8388608" "1" "Daft Punk" "Random Access Memories" "Electronic" "2013" "Lossless" "FLAC"}
set audiobookLine {PRE: "/AUDIOBOOKS/Example.Audio.Book.2026-GROUP" "BOOKGROUP" "khaza" "USERS" "AUDIOBOOKS" "64" "2097152" "1"}
set gamePcLine {PRE: "/PC/Example.Game-RELOADED" "GAMEGROUP" "khaza" "USERS" "PC" "88" "12582912" "1"}
set gameConsoleLine {PRE: "/CONSOLE/Example.Console.Game-GROUP" "GAMEGROUP" "khaza" "USERS" "CONSOLE" "72" "9437184" "1"}
set ebookLine {PRE: "/EBOOKS/Example.Ebook.2026-GROUP" "BOOKGROUP" "khaza" "USERS" "EBOOKS" "3" "10240" "1"}
set parsed [::dZSbot::SiteAdapter::ParseNxPreLine $preLine]

if {![dict get $parsed ok]} {
    error "Expected nxPre PRE line to parse"
}

set payload [dict get $parsed payload]
if {[dict get $payload release] ne "Radiohead.OK.Computer.1997.FLAC-GROUP"} {
    error "Expected parsed release name"
}
if {[dict get $payload section] ne "MP3"} {
    error "Expected parsed PRE section"
}

puts "Parsed nxPre PRE: $payload"

set parsedMp3 [::dZSbot::SiteAdapter::ParseNxPreLine $mp3Line]
if {![dict get $parsedMp3 ok] || [dict get $parsedMp3 payload music.format] ne "MP3"} {
    error "Expected nxPre PRE-MP3 line to parse music metadata"
}
puts "Parsed nxPre PRE-MP3: [dict get $parsedMp3 payload]"

set parsedFlac [::dZSbot::SiteAdapter::ParseNxPreLine $flacLine]
if {![dict get $parsedFlac ok] || [dict get $parsedFlac payload music.format] ne "FLAC"} {
    error "Expected nxPre PRE-FLAC line to parse music metadata"
}
puts "Parsed nxPre PRE-FLAC: [dict get $parsedFlac payload]"

set newDirLine {07-02-2026 10:00:32 NEWDIR: "khaz" "MEV" "/GROUPS/MEV/MUSiC/DEATH_IN_AUGUST-GREET_THE_STORM-EP-CD-FLAC-2026-TOTENKVLT" "\\?\C:\ioFTPD\FTP-ROOT-DIR\GROUPS\MEV\MUSiC\DEATH_IN_AUGUST-GREET_THE_STORM-EP-CD-FLAC-2026-TOTENKVLT"}
set tvNewDirLine {07-02-2026 10:01:32 NEWDIR: "khaz" "MEV" "/GROUPS/MEV/TV/The.Last.of.Us.S01E01.1080p.WEB.H264-GROUP" "\\?\C:\ioFTPD\FTP-ROOT-DIR\GROUPS\MEV\TV\The.Last.of.Us.S01E01.1080p.WEB.H264-GROUP"}
set parsedNewDir [::dZSbot::SiteAdapter::ParseIoFtpdLine $newDirLine]
if {![dict get $parsedNewDir ok] || [dict get $parsedNewDir event] ne "site.newdir"} {
    error "Expected ioFTPD NEWDIR line to parse"
}
if {[dict get $parsedNewDir payload section] ne "MUSIC"} {
    error "Expected NEWDIR section MUSIC"
}
puts "Parsed ioFTPD NEWDIR: [dict get $parsedNewDir payload]"

set parsedTvNewDir [::dZSbot::SiteAdapter::ParseIoFtpdLine $tvNewDirLine]
if {![dict get $parsedTvNewDir ok] || [dict get $parsedTvNewDir event] ne "site.newdir"} {
    error "Expected ioFTPD TV NEWDIR line to parse"
}
if {[dict get $parsedTvNewDir payload section] ne "TV"} {
    error "Expected TV NEWDIR section TV"
}
puts "Parsed ioFTPD TV NEWDIR: [dict get $parsedTvNewDir payload]"

set completeLine {07-02-2026 10:00:43 COMPLETE_STAT_RACE_FLAC: /GROUPS/MEV/MUSiC/DEATH_IN_AUGUST-GREET_THE_STORM-EP-CD-FLAC-2026-TOTENKVLT/ DEATH_IN_AUGUST-GREET_THE_STORM-EP-CD-FLAC-2026-TOTENKVLT 82865 5 7533 234909 11 1 1 khaz NoGroup 227156}
set parsedComplete [::dZSbot::SiteAdapter::ParseIoFtpdLine $completeLine]
if {![dict get $parsedComplete ok] || [dict get $parsedComplete event] ne "site.upload.complete"} {
    error "Expected ioFTPD COMPLETE line to parse"
}
if {[dict get $parsedComplete payload files] ne "5"} {
    error "Expected COMPLETE files count"
}
if {[dict get $parsedComplete payload user] ne "khaz" || [dict get $parsedComplete payload group] ne "NoGroup"} {
    error "Expected COMPLETE uploader khaz/NoGroup"
}
puts "Parsed ioFTPD COMPLETE: [dict get $parsedComplete payload]"

set preTestFile [file join $root runtime test-nxpre.tsv]
catch {file delete $preTestFile}
::dZSbot::Config::Set pre.storage $preTestFile
::dZSbot::Config::Set imdb.announce.enabled 0
::dZSbot::Config::Set music.announce.enabled 0

set delivered [::dZSbot::SiteAdapter::ImportNxPreLine $preLine]
if {$delivered < 1} {
    error "Expected nxPre PRE line to publish at least one event"
}

set rows [::dZSbot::Modules::Pre::Store::SearchEntries Radiohead 5]
if {![llength $rows]} {
    error "Expected nxPre PRE line to be imported into PRE storage"
}

puts "Imported nxPre PRE: [lindex $rows 0]"

set deliveredFlac [::dZSbot::SiteAdapter::ImportNxPreLine $flacLine]
if {$deliveredFlac < 1} {
    error "Expected nxPre PRE-FLAC line to publish at least one event"
}

set flacRows [::dZSbot::Modules::Pre::Store::SearchEntries Random.Access 5]
if {![llength $flacRows]} {
    error "Expected nxPre PRE-FLAC line to be imported into PRE storage"
}
if {[dict get [lindex $flacRows 0] section] ne "MUSIC"} {
    error "Expected nxPre PRE-FLAC import to allow MUSIC section"
}

puts "Imported nxPre PRE-FLAC: [lindex $flacRows 0]"

foreach item [list \
    [list $audiobookLine AUDIOBOOKS Audio.Book] \
    [list $gamePcLine PC Example.Game] \
    [list $gameConsoleLine CONSOLE Console.Game] \
    [list $ebookLine EBOOKS Ebook]] {
    set line [lindex $item 0]
    set expectedSection [lindex $item 1]
    set query [lindex $item 2]
    set parsedExtra [::dZSbot::SiteAdapter::ParseNxPreLine $line]

    if {![dict get $parsedExtra ok]} {
        error "Expected nxPre line for $expectedSection to parse"
    }
    if {[dict get $parsedExtra payload section] ne $expectedSection} {
        error "Expected section $expectedSection"
    }

    set publicLine [::dZSbot::Modules::Pre::Formatter::PublicLine [dict get $parsedExtra payload]]
    if {[string first $expectedSection $publicLine] < 0} {
        error "Expected public PRE line to include $expectedSection"
    }

    ::dZSbot::SiteAdapter::ImportNxPreLine $line
    set extraRows [::dZSbot::Modules::Pre::Store::SearchEntries $query 5]
    if {![llength $extraRows]} {
        error "Expected $expectedSection PRE to be imported"
    }

    puts "Imported nxPre $expectedSection: [lindex $extraRows 0]"
}
