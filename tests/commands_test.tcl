set root [file normalize [pwd]]

proc isop {nick chan} {
    return [expr {$nick eq "opuser" && [string equal -nocase $chan "#staff"]}]
}

source [file join $root dZSbot.tcl]

set requestTestFile [file join $root runtime test-requests.db]
catch {file delete $requestTestFile}
::dZSbot::Config::Set request.storage $requestTestFile

set preTestFile [file join $root runtime test-pre.tsv]
catch {file delete $preTestFile}
::dZSbot::Config::Set pre.storage $preTestFile

puts "Commands: [::dZSbot::Commands::List]"

::dZSbot::Commands::Dispatch !status tester host hand #chan ""
::dZSbot::Commands::Dispatch !imdb tester host hand #chan ""
::dZSbot::Commands::Dispatch !request tester host hand #chan "Example.Release.2026"
::dZSbot::Commands::Dispatch !requests tester host hand #chan ""
::dZSbot::Commands::Dispatch !addpre tester host hand #chan "Example.Release.2026 MOVIES tester GROUP 7340032 42"
::dZSbot::Commands::Dispatch !pre tester host hand #chan "Example"
::dZSbot::Commands::Dispatch !pres tester host hand #chan ""
::dZSbot::Commands::Dispatch !music tester host hand #chan "Artist - Title MP3"
::dZSbot::Commands::Dispatch !flac tester host hand #chan "Artist - Album FLAC"
::dZSbot::Commands::Dispatch !musicinfo tester host hand #chan ""
::dZSbot::Commands::Dispatch !tv tester host hand #chan "Example Show"
::dZSbot::Commands::Dispatch !dzb tester host hand #chan "status"
::dZSbot::Commands::Dispatch !dzb tester host hand #staff "status"
::dZSbot::Commands::Dispatch !dzb opuser host hand #staff "status"
