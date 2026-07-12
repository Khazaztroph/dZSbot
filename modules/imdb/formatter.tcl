namespace eval ::dZSbot::Modules::IMDb::Formatter {}

proc ::dZSbot::Modules::IMDb::Formatter::RatingBar {rating} {

    if {$rating eq "N/A" || ![string is double -strict $rating]} {
        return ""
    }

    set value [expr {int(round($rating))}]
    if {$value < 0} {
        set value 0
    }
    if {$value > 10} {
        set value 10
    }

    return "[string repeat "*" $value][string repeat "-" [expr {10 - $value}]]"
}

proc ::dZSbot::Modules::IMDb::Formatter::MovieLines {movie} {

    set title [dict get $movie Title]
    set year [dict get $movie Year]
    set type [string tolower [dict get $movie Type]]
    set runtime [dict get $movie Runtime]
    set genre [dict get $movie Genre]
    set rating [dict get $movie imdbRating]
    set votes [dict get $movie imdbVotes]
    set plot [dict get $movie Plot]
    set director [dict get $movie Director]
    set actors [dict get $movie Actors]
    set imdbid [dict get $movie imdbID]
    set seasons [dict get $movie totalSeasons]
    set bar [RatingBar $rating]
    set url "https://www.imdb.com/title/$imdbid/"
    set label "Movie"

    if {$type eq "series"} {
        set label "TV Series"
    } elseif {$type ne "" && $type ne "n/a"} {
        set label [string totitle $type]
    }

    set lines {}
    if {$type eq "series" && $seasons ne "N/A"} {
        lappend lines "\002$title\002 ($year) | $label | $seasons seasons"
    } else {
        lappend lines "\002$title\002 ($year) | $label | $runtime"
    }
    lappend lines "Genre: $genre"

    if {$bar eq ""} {
        lappend lines "IMDb: $rating/10 ($votes votes)"
    } else {
        lappend lines "IMDb: $rating/10 $bar ($votes votes)"
    }

    lappend lines "Director: $director"
    lappend lines "Actors: $actors"
    lappend lines "Plot: $plot"
    lappend lines $url

    return $lines
}

proc ::dZSbot::Modules::IMDb::Formatter::PublicLine {title {release ""}} {

    set titleName [dict get $title Title]
    set year [dict get $title Year]
    set type [string tolower [dict get $title Type]]
    set rating [dict get $title imdbRating]
    set imdbid [dict get $title imdbID]
    set label "Movie"
    set releaseSuffix ""

    if {$type eq "series"} {
        set label "TV"
    }
    if {$release ne ""} {
        set releaseSuffix " | Rel: $release"
    }

    return [::dZSbot::Theme::Render imdb.public [dict create \
        section MOVIES \
        label $label \
        title $titleName \
        year $year \
        rating $rating \
        url "https://www.imdb.com/title/$imdbid/" \
        release_suffix $releaseSuffix]]
}
