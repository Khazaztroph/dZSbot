namespace eval ::dZSbot::Modules::Music::FLAC {

    variable Version "0.1.0"
}

proc ::dZSbot::Modules::Music::FLAC::Supports {format} {

    return [expr {$format eq "flac"}]
}
