set root [file normalize [pwd]]

source [file join $root dZSbot.tcl]

::dZSbot::Config::Set theme.irc.colors 0

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
set firstLine {07-02-2026 10:01:35 UPDATE_MOVIE: {/MOVIE-1080P/Twisters.2024.1080p.BluRay.H264-VALUE/} Vroom GROUP 81 10680 23708262 file001.rar Twisters.2024.1080p.BluRay.H264-VALUE tagline {9m 9s}}
set halfLine {07-02-2026 10:02:35 HALFWAY_RACE_MOVIE: {/MOVIE-1080P/Twisters.2024.1080p.BluRay.H264-VALUE/} Twisters.2024.1080p.BluRay.H264-VALUE Vroom GROUP 8806 23 79 8376 GROUP 8806 23 79 8376 23708262 81 79 8376 4010 17 file001.rar 2 1 Transporter GROUP 81 {{Transporter GROUP} {ioftpd NoGroup}} {9m 9s}}
set racerLine {07-02-2026 10:03:35 RACE_MOVIE: {/MOVIE-1080P/Twisters.2024.1080p.BluRay.H264-VALUE/} Transporter GROUP {{Vroom GROUP}} Twisters.2024.1080p.BluRay.H264-VALUE 4096 file002.rar 12 42 1 1 34 81 47 tagline {{Vroom GROUP}} {8m 20s}}
set leaderLine {07-02-2026 10:04:35 NEWLEADER_MOVIE: {/MOVIE-1080P/Twisters.2024.1080p.BluRay.H264-VALUE/} Transporter GROUP 4096 12 34 42 23708262 Twisters.2024.1080p.BluRay.H264-VALUE file002.rar 1 1 81 47 Transporter GROUP 1000 34 42 4096 GROUP 1000 34 42 4096 tagline {{Vroom GROUP}} {8m 20s}}
set badCrcLine {07-02-2026 10:05:35 BAD_FILE_CRC: {/MOVIE-1080P/Twisters.2024.1080p.BluRay.H264-VALUE/} Twisters.2024.1080p.BluRay.H264-VALUE Transporter GROUP broken.r00}
set zeroLine {07-02-2026 10:06:35 BAD_FILE_0SIZE: {/MOVIE-1080P/Twisters.2024.1080p.BluRay.H264-VALUE/} Twisters.2024.1080p.BluRay.H264-VALUE Transporter GROUP empty.r00}
set nfoLine {07-02-2026 10:07:35 NFO: {/MOVIE-1080P/Twisters.2024.1080p.BluRay.H264-VALUE/} Transporter GROUP Twisters.2024.1080p.BluRay.H264-VALUE twisters.nfo}
set doubleSfvLine {07-02-2026 10:08:35 DOUBLESFV: {/MOVIE-1080P/Twisters.2024.1080p.BluRay.H264-VALUE/} Transporter GROUP Twisters.2024.1080p.BluRay.H264-VALUE twisters.sfv}
set speedTestLine {07-02-2026 10:09:35 SPEEDTEST: {/SPEEDTEST/} Transporter GROUP tagline 20480 512}
set incompleteLine {07-02-2026 10:10:35 INCOMPLETE: {/MOVIE-1080P/Twisters.2024.1080p.BluRay.H264-VALUE/} Transporter GROUP Twisters.2024.1080p.BluRay.H264-VALUE}
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

set parsedFirst [::dZSbot::SiteAdapter::ParseIoFtpdLine $firstLine]
if {![dict get $parsedFirst ok] || [dict get $parsedFirst event] ne "site.upload.first"} {
    error "Expected ioFTPD UPDATE line to parse as FIRST"
}
set firstAnnounce [::dZSbot::Modules::Upload::FormatLine first [dict get $parsedFirst payload]]
if {[string first "Twisters.2024.1080p.BluRay.H264-VALUE by Vroom - 10.43MB/s :: release size - 22.61GB ::" $firstAnnounce] < 0} {
    error "Expected FIRST announce format: $firstAnnounce"
}
puts "Parsed ioFTPD FIRST: [dict get $parsedFirst payload]"

set parsedHalf [::dZSbot::SiteAdapter::ParseIoFtpdLine $halfLine]
if {![dict get $parsedHalf ok] || [dict get $parsedHalf event] ne "site.upload.half"} {
    error "Expected ioFTPD HALFWAY line to parse as HALF"
}
set halfAnnounce [::dZSbot::Modules::Upload::FormatLine half [dict get $parsedHalf payload]]
if {[string first "Twisters.2024.1080p.BluRay.H264-VALUE :: Vroom :: with 23f :: 79% :: 8.60GB :: 8.18MB/s :: others: Transporter/GROUP, ioftpd/NoGroup :: time left 9m 9s" $halfAnnounce] < 0} {
    error "Expected HALF announce format: $halfAnnounce"
}
puts "Parsed ioFTPD HALF: [dict get $parsedHalf payload]"

foreach item [list \
    [list $racerLine site.upload.racer "Twisters.2024.1080p.BluRay.H264-VALUE :: Transporter :: 4.00MB/s"] \
    [list $leaderLine site.upload.leader "Twisters.2024.1080p.BluRay.H264-VALUE :: Transporter"] \
    [list $badCrcLine site.upload.badfile "BADCRC" "broken.r00"] \
    [list $zeroLine site.upload.badfile "0SIZE" "empty.r00"] \
    [list $nfoLine site.upload.nfo "NFO" "twisters.nfo"] \
    [list $doubleSfvLine site.upload.doublesfv "DOUBLESFV" "twisters.sfv"] \
    [list $speedTestLine site.upload.speedtest "512MB :: 20.00MB/s"] \
    [list $incompleteLine site.upload.incomplete "INCOMPLETE" "Twisters.2024.1080p.BluRay.H264-VALUE"]] {
    set parsedExtra [::dZSbot::SiteAdapter::ParseIoFtpdLine [lindex $item 0]]
    set expectedEvent [lindex $item 1]
    if {![dict get $parsedExtra ok] || [dict get $parsedExtra event] ne $expectedEvent} {
        error "Expected $expectedEvent from extra ioFTPD line: $parsedExtra"
    }
    set action [dict get [dict get $parsedExtra payload] action]
    set line [::dZSbot::Modules::Upload::FormatLine $action [dict get $parsedExtra payload]]
    foreach expected [lrange $item 2 end] {
        if {[string first $expected $line] < 0} {
            error "Expected '$expected' in $expectedEvent announce: $line"
        }
    }
    puts "Parsed extra ioFTPD event $expectedEvent: [dict get $parsedExtra payload]"
}

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
if {[dict get $parsedComplete payload speed_kbps] ne "7533"} {
    error "Expected COMPLETE average speed"
}
set completeAnnounce [::dZSbot::Modules::Upload::FormatLine complete [dict get $parsedComplete payload]]
if {[string first "DEATH_IN_AUGUST-GREET_THE_STORM-EP-CD-FLAC-2026-TOTENKVLT :: 5f :: 80.92MB :: 11s :: avg. 7.36MB/s :: khaz" $completeAnnounce] < 0} {
    error "Expected COMPLETE announce to include upload speed: $completeAnnounce"
}
puts "Parsed ioFTPD COMPLETE: [dict get $parsedComplete payload]"

foreach item [list \
    [list {07-02-2026 10:11:35 NEWDATE: "/0DAY/2026-08-10" "0DAY" "Newdate 0DAY"} site.legacy.newdate "NEWDATE" "0DAY"] \
    [list {07-02-2026 10:12:35 WIPE: "/MOVIES/Old.Release-GROUP" "khaz" "MEV" "1" "15" "7340032"} site.legacy.wipe "WIPE" "Old.Release-GROUP"] \
    [list {07-02-2026 10:13:35 NUKE: "/MOVIES/Bad.Release-GROUP" "nuker" "STAFF" "3" "bad.pack" "12" "102400" "1" "user/10MB"} site.legacy.nuke "NUKE" "bad.pack"] \
    [list {07-02-2026 10:14:35 REQUEST: "tester" "USERS" "Wanted.Release.2026" "4"} site.legacy.request "REQ" "Wanted.Release.2026"] \
    [list {07-02-2026 10:15:35 REQFILL: "filler" "USERS" "Wanted.Release.2026" "tester" "USERS" "4" "30"} site.legacy.reqfill "FILL" "Wanted.Release.2026"]] {
    set parsedLegacy [::dZSbot::SiteAdapter::ParseIoFtpdLine [lindex $item 0]]
    set expectedEvent [lindex $item 1]
    if {![dict get $parsedLegacy ok] || [dict get $parsedLegacy event] ne $expectedEvent} {
        error "Expected $expectedEvent from legacy line: $parsedLegacy"
    }
    set eventName [string range $expectedEvent [string length "site.legacy."] end]
    set legacyLine [::dZSbot::Modules::Legacy::FormatLine $eventName [dict get $parsedLegacy payload]]
    foreach expected [lrange $item 2 end] {
        if {[string first $expected $legacyLine] < 0} {
            error "Expected '$expected' in legacy announce: $legacyLine"
        }
    }
    puts "Parsed legacy event $expectedEvent: [dict get $parsedLegacy payload]"
}

if {![::dZSbot::Modules::Upload::SectionAllowed TV-1080P]} {
    error "Expected upload announce to allow TV-1080P"
}
if {![::dZSbot::Modules::Upload::SectionAllowed MOVIE-2160P]} {
    error "Expected upload announce to allow MOVIE-2160P"
}

set preTestFile [file join $root runtime "test-nxpre-[pid].tsv"]
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
