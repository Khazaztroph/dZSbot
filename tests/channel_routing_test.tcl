set root [file normalize [pwd]]

source [file join $root dZSbot.tcl]

::dZSbot::Config::Set upload.announce.default_channel "#opers"
::dZSbot::Config::Set upload.announce.section_channels {
    {#spam {MUSIC FLAC MP3 XXX}}
    {#monstra {TV-HD-NORDIC TV-SD-NORDIC X264-NORDIC X265-NORDIC UHD-NORDIC *-NORDIC}}
}

if {[::dZSbot::Modules::Upload::ChannelForSection "FLAC"] ne "#spam"} {
    error "Expected FLAC upload announce to route to #spam"
}

if {[::dZSbot::Modules::Upload::ChannelForSection "XXX-PAY"] ne "#spam"} {
    error "Expected XXX-PAY upload announce to route to #spam through XXX"
}

if {[::dZSbot::Modules::Upload::ChannelForSection "TV-HD-NORDIC"] ne "#monstra"} {
    error "Expected TV-HD-NORDIC upload announce to route to #monstra"
}

if {[::dZSbot::Modules::Upload::ChannelForSection "UHD-NORDIC"] ne "#monstra"} {
    error "Expected UHD-NORDIC upload announce to route to #monstra"
}

if {[::dZSbot::Modules::Upload::ChannelForSection "TV-2160P-NORDIC"] ne "#monstra"} {
    error "Expected wildcard NORDIC upload announce to route to #monstra"
}

if {[::dZSbot::Modules::Upload::ChannelForSection "MOVIE-2160P"] ne "#opers"} {
    error "Expected unmatched upload announce to route to #opers"
}

::dZSbot::Config::Set legacy.announce.default_channel "#opers"
::dZSbot::Config::Set legacy.announce.section_channels {
    {#spam {MUSIC FLAC MP3 XXX}}
    {#monstra {TV-HD-NORDIC TV-SD-NORDIC X264-NORDIC X265-NORDIC UHD-NORDIC *-NORDIC}}
}

if {[::dZSbot::Modules::Legacy::ChannelForSection "MP3"] ne "#spam"} {
    error "Expected MP3 legacy announce to route to #spam"
}

if {[::dZSbot::Modules::Legacy::ChannelForSection "X265-NORDIC"] ne "#monstra"} {
    error "Expected X265-NORDIC legacy announce to route to #monstra"
}

if {[::dZSbot::Modules::Legacy::ChannelForSection "GAMES"] ne "#opers"} {
    error "Expected unmatched legacy announce to route to #opers"
}

puts "channel_routing_test ok"
