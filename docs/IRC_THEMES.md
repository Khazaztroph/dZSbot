# IRC Themes

dZSbot themes control IRC colors, bold text, tags and message templates without
changing module code.

## Theme File

The default theme is:

```text
config/themes/default.conf
```

The active theme is selected in:

```text
config/dzsbot.conf
```

```tcl
::dZSbot::Config::Set theme.name "default"
```

## Colors

Colors are enabled by default:

```tcl
::dZSbot::Config::Set theme.irc.colors 1
```

Disable colors:

```tcl
::dZSbot::Config::Set theme.irc.colors 0
```

Bold text is controlled separately:

```tcl
::dZSbot::Config::Set theme.irc.bold 1
```

## Tags

Use `%tag{...}` in templates:

```tcl
%tag{NEWDATE}
%tag{NUKE}
%tag{REQ}
%tag{{section}}
```

Tags are normalized to uppercase by the theme engine, so `%tag{newdate}` renders
as `[NEWDATE]`.

## Color Slots

Common slots:

```tcl
::dZSbot::Config::Set theme.color.c1 "08"
::dZSbot::Config::Set theme.color.c2 "03"
::dZSbot::Config::Set theme.color.c3 "06"
::dZSbot::Config::Set theme.color.c4 "12"
```

Section-specific colors override global slots:

```tcl
::dZSbot::Config::Set theme.section.MOVIES.c1 "05"
::dZSbot::Config::Set theme.section.TV.c1 "06"
::dZSbot::Config::Set theme.section.MUSIC.c1 "10"
```

## Upload Templates

Examples:

```tcl
::dZSbot::Config::Set theme.template.upload.newdir "%tag{{tag}}%tag{{section}} :: %c2{{release}} ::"
::dZSbot::Config::Set theme.template.upload.complete "%tag{{tag}}%tag{{section}} :: %c2{{release}} :: {files_label} :: {size_compact}{duration_segment}{speed_segment} :: {user}"
```

## Legacy Templates

Legacy templates cover nxTools/ioNiNJA-style events:

```tcl
::dZSbot::Config::Set theme.template.legacy.newdate "%tag{NEWDATE}%tag{{section}} %bold{{release}} was just created in %bold{{area}} ( %bold{{description}} )"
::dZSbot::Config::Set theme.template.legacy.nuke "%tag{NUKE}%tag{{section}} %bold{{relname}} factor %bold{{multiplier}} by %bold{{nuker}} \[reason\] %bold{{reason}} \[nukees\] {nukees}"
::dZSbot::Config::Set theme.template.legacy.unnuke "%tag{UNNUKE}%tag{{section}} %bold{{relname}} factor %bold{{multiplier}} by %bold{{nuker}} \[reason\] %bold{{reason}} \[nukees\] {nukees}"
```

## PRE Stats

PRE stats use these templates:

```tcl
::dZSbot::Config::Set theme.template.pre.stats.header "%c1{PRE {title} Stats}: %c2{{label}} | %c3{{releases} releases} | {files}F | %c4{{size}}"
::dZSbot::Config::Set theme.template.pre.stats.top "%c1{PRE Top {label}}: %c2{{entries}}"
```

Plain text output with colors disabled:

```text
PRE Daily Stats: last 24h | 12 releases | 340F | 188.42 GB
PRE Top Daily Groups: #1 GROUP1 (5) | #2 GROUP2 (3)
PRE Top Daily Sections: #1 MOVIES (6) | #2 TV (4)
```
