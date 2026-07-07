namespace eval ::dZSbot::Modules::Music::MP3 {

    variable Version "0.1.0"
}

proc ::dZSbot::Modules::Music::MP3::Supports {format} {

    return [expr {$format eq "mp3"}]
}
