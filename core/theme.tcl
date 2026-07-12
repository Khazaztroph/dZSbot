###############################################################################
#
# dZSbot 2.0
#
# Module      : Theme
# Description : Runtime theme state.
#
###############################################################################

namespace eval ::dZSbot::Theme {

    variable Initialized 0
    variable Name "default"
}

proc ::dZSbot::Theme::Initialize {{name ""}} {

    variable Initialized
    variable Name

    if {$name eq ""} {
        set name [::dZSbot::Config::Get theme.name "default"]
    }

    set Name $name
    set Initialized 1

    ::dZSbot::Config::Load [file join $::dZSbot::Root config themes "${name}.conf"] 1
    ::dZSbot::Health::Set theme ok $name
    return 1
}

proc ::dZSbot::Theme::Name {} {

    variable Name
    return $Name
}

proc ::dZSbot::Theme::ColorsEnabled {} {

    return [expr {[::dZSbot::Config::Get theme.irc.colors 0] ? 1 : 0}]
}

proc ::dZSbot::Theme::BoldEnabled {} {

    return [expr {[::dZSbot::Config::Get theme.irc.bold 1] ? 1 : 0}]
}

proc ::dZSbot::Theme::ColorCode {slot {section ""}} {

    set sectionKey [string toupper $section]
    set sectionColor [::dZSbot::Config::Get "theme.section.$sectionKey.$slot" ""]

    if {$sectionColor ne ""} {
        return $sectionColor
    }

    return [::dZSbot::Config::Get "theme.color.$slot" "08"]
}

proc ::dZSbot::Theme::Color {slot text {section ""}} {

    if {![ColorsEnabled]} {
        return $text
    }

    set code [ColorCode $slot $section]
    return "\003${code}${text}\003"
}

proc ::dZSbot::Theme::Bold {text} {

    if {![BoldEnabled]} {
        return $text
    }

    return "\002$text\002"
}

proc ::dZSbot::Theme::Tag {label {section ""}} {

    set open [::dZSbot::Config::Get theme.bracket.open "\["]
    set close [::dZSbot::Config::Get theme.bracket.close "\]"]
    return "${open}[Bold [Color c1 $label $section]]${close}"
}

proc ::dZSbot::Theme::Template {name default} {

    return [::dZSbot::Config::Get "theme.template.$name" $default]
}

proc ::dZSbot::Theme::Render {name values {default ""}} {

    set line [Template $name $default]

    dict for {key value} $values {
        set line [string map [list "{$key}" $value] $line]
    }

    set section ""
    if {[dict exists $values section]} {
        set section [dict get $values section]
    }

    while {[regexp {%tag\{([^{}]*)\}} $line -> label]} {
        set line [string map [list "%tag{$label}" [Tag $label $section]] $line]
    }

    foreach slot {c1 c2 c3 c4 muted ok warn error} {
        set pattern [format {%%%s\{([^{}]*)\}} $slot]
        while {[regexp $pattern $line -> value]} {
            set line [string map [list "%${slot}{$value}" [Color $slot $value $section]] $line]
        }
    }

    while {[regexp {%bold\{([^{}]*)\}} $line -> value]} {
        set line [string map [list "%bold{$value}" [Bold $value]] $line]
    }

    return $line
}
