namespace eval ::dZSbot::Modules::Music::Formatter {}

proc ::dZSbot::Modules::Music::Formatter::FormatDiscogsRelease {release} {

    set title [dict get $release title]
    set year [dict get $release year]
    set country [dict get $release country]
    set catno [dict get $release catno]
    set formats [dict get $release formats]
    set labels [dict get $release labels]
    set genres [dict get $release genres]
    set uri [dict get $release uri]

    if {![llength $formats]} {
        set formats {N/A}
    }
    if {![llength $labels]} {
        set labels {N/A}
    }
    if {![llength $genres]} {
        set genres {N/A}
    }

    set urlSuffix ""
    if {$uri ne ""} {
        set urlSuffix " | https://www.discogs.com$uri"
    }

    return [::dZSbot::Theme::Render music.detail [dict create \
        section MUSIC \
        title $title \
        year $year \
        formats [join $formats {/}] \
        labels [join $labels {, }] \
        genres [join $genres {, }] \
        country $country \
        catno $catno \
        url_suffix $urlSuffix]]
}

proc ::dZSbot::Modules::Music::Formatter::PublicLine {release {releaseName ""} {tag "Music"} {section "MUSIC"}} {

    set title [dict get $release title]
    set year [dict get $release year]
    set formats [dict get $release formats]
    set labels [dict get $release labels]
    set releaseSuffix ""

    if {![llength $formats]} {
        set formats {N/A}
    }
    if {![llength $labels]} {
        set labels {N/A}
    }
    if {$releaseName ne ""} {
        set releaseSuffix " | Rel: $releaseName"
    }

    return [::dZSbot::Theme::Render music.public [dict create \
        section $section \
        tag $tag \
        title $title \
        year $year \
        formats [join $formats {/}] \
        labels [join $labels {, }] \
        release_suffix $releaseSuffix]]
}

proc ::dZSbot::Modules::Music::Formatter::FormatStatus {supported} {

    set parts {}
    foreach format $supported {
        lappend parts "[string toupper $format] OK"
    }

    return "Music Module: [join $parts { | }]"
}
