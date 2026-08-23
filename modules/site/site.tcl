namespace eval ::dZSbot::Modules::Site {

    variable Version "0.1.0"
    variable BncCheckCommand ""
    variable BncToken 0
    variable BncLastKey ""
    variable BncLastClock 0
    variable QuotaAutoTimer ""
}

proc ::dZSbot::Modules::Site::Initialize {} {

    StartQuotaAuto
}

proc ::dZSbot::Modules::Site::CmdDf {nick host hand chan text} {

    set replyTarget [ReplyTarget $nick $chan site.commands.df.reply_target]

    if {![::dZSbot::Config::Get site.commands.df.enabled 1]} {
        ::dZSbot::Commands::Reply $nick $replyTarget "DF: command is disabled."
        return
    }

    set filter [string toupper [string trim $text]]
    set lines {}
    set source [string tolower [::dZSbot::Config::Get site.commands.df.source "cache"]]

    set sections [DfSections]
    if {$source ni {auto cache file status fluxftp api} && ![llength $sections]} {
        ::dZSbot::Commands::Reply $nick $replyTarget "DF: no sections configured. Set site.df.sections in config/modules/site.conf."
        return
    }

    if {$source in {auto fluxftp api}} {
        set api [FluxFtpDfLines $filter]
        if {[dict get $api ok]} {
            set lines [dict get $api lines]
        } elseif {$source ni {auto} && [DfFallbackEnabled]} {
            set fallback [DfCacheLines $filter]
            if {[dict get $fallback ok]} {
                set lines [dict get $fallback lines]
            } else {
                lappend lines "DF: ERROR | [dict get $api error]; fallback failed: [dict get $fallback error]"
            }
        } elseif {$source ni {auto}} {
            lappend lines "DF: ERROR | [dict get $api error]"
        }
    }

    if {![llength $lines] && $source in {auto cache file status}} {
        set cache [DfCacheLines $filter]
        if {[dict get $cache ok]} {
            set lines [dict get $cache lines]
        } elseif {$source ni {auto}} {
            lappend lines "DF: ERROR | [dict get $cache error]"
        }
    }

    if {![llength $lines] && $source eq "auto" && [llength $sections]} {
        foreach section $sections {
            if {![dict get $section ok]} {
                lappend lines "DF: invalid section config | [dict get $section error]"
                continue
            }

            set name [string toupper [dict get $section name]]
            set path [dict get $section path]
            if {$filter ne "" && ![string match "*$filter*" $name]} {
                continue
            }

            lappend lines [FormatDfLine $name $path [DiskFree $path]]
        }
    } elseif {$source ni {auto cache file status fluxftp api}} {
        foreach section $sections {
            if {![dict get $section ok]} {
                lappend lines "DF: invalid section config | [dict get $section error]"
                continue
            }

            set name [string toupper [dict get $section name]]
            set path [dict get $section path]
            if {$filter ne "" && ![string match "*$filter*" $name]} {
                continue
            }

            lappend lines [FormatDfLine $name $path [DiskFree $path]]
        }
    }

    if {![llength $lines]} {
        ::dZSbot::Commands::Reply $nick $replyTarget "DF: no configured section matched '$text'."
        return
    }

    foreach line $lines {
        ::dZSbot::Commands::Reply $nick $replyTarget $line
    }
}

proc ::dZSbot::Modules::Site::DfSections {} {

    set raw [::dZSbot::Config::Get site.df.sections {}]
    set result {}

    if {![catch {dict size $raw} size] && $size > 0} {
        dict for {name path} $raw {
            lappend result [dict create ok 1 name $name path $path]
        }
        return $result
    }

    foreach section $raw {
        lappend result [ParseDfSection $section]
    }

    return $result
}

proc ::dZSbot::Modules::Site::ParseDfSection {section} {

    if {[catch {set count [llength $section]} error]} {
        return [dict create ok 0 error $error]
    }

    if {$count < 2} {
        return [dict create ok 0 error "expected {NAME PATH}"]
    }

    set name [lindex $section 0]
    set path [lindex $section 1]

    if {[string trim $name] eq "" || [string trim $path] eq ""} {
        return [dict create ok 0 error "empty name or path"]
    }

    return [dict create ok 1 name $name path $path]
}

proc ::dZSbot::Modules::Site::DfCacheLines {filter} {

    set path [::dZSbot::Config::Get site.commands.df.cache_file ""]
    if {$path eq ""} {
        return [dict create ok 0 error "site.commands.df.cache_file not configured" lines {}]
    }
    if {![file exists $path]} {
        return [dict create ok 0 error "DF cache file not found: $path" lines {}]
    }

    set maxAge [::dZSbot::Config::Get site.commands.df.cache_max_age_seconds 300]
    if {![string is integer -strict $maxAge] || $maxAge < 1} {
        set maxAge 300
    }

    set age [expr {[clock seconds] - [file mtime $path]}]
    if {$age > $maxAge} {
        return [dict create ok 0 error "DF cache is stale (${age}s old)" lines {}]
    }

    if {[catch {
        set fh [open $path r]
        fconfigure $fh -encoding utf-8 -translation lf
        set content [read $fh]
        close $fh
    } error]} {
        catch {close $fh}
        return [dict create ok 0 error $error lines {}]
    }

    set lines {}
    foreach rawLine [split $content "\n"] {
        set rawLine [string trimright $rawLine "\r"]
        if {[string trim $rawLine] eq "" || [string match "#*" [string trimleft $rawLine]]} {
            continue
        }

        set entry [ParseDfCacheLine $rawLine]
        if {![dict get $entry ok]} {
            if {[dict exists $entry name] && [dict exists $entry path]} {
                lappend lines [FormatDfLine [string toupper [dict get $entry name]] [dict get $entry path] $entry]
            }
            continue
        }

        set name [string toupper [dict get $entry name]]
        if {$filter ne "" && ![string match "*$filter*" $name]} {
            continue
        }

        lappend lines [FormatDfLine $name [dict get $entry path] $entry]
    }

    return [dict create ok 1 error "" lines $lines]
}

proc ::dZSbot::Modules::Site::FluxFtpDfLines {filter} {

    if {![FluxFtpAvailable]} {
        return [dict create ok 0 error "FluxFTP adapter unavailable" lines {}]
    }

    if {[catch {set result [::dZSbot::Adapter::FluxFTP::DiskFree]} error]} {
        return [dict create ok 0 error $error lines {}]
    }
    if {![dict get $result ok]} {
        return [dict create ok 0 error [DictGet $result error "FluxFTP diskfree failed"] lines {}]
    }

    set lines {}
    foreach section [DictGet $result sections {}] {
        set name [string toupper [DictGet $section name "UNKNOWN"]]
        if {$filter ne "" && ![string match "*$filter*" $name]} {
            continue
        }

        lappend lines [FormatDfLine $name [DictGet $section path ""] [dict merge [dict create ok 1] $section]]
    }

    return [dict create ok 1 error "" lines $lines]
}

proc ::dZSbot::Modules::Site::ParseDfCacheLine {line} {

    set parts [split $line "\t"]
    if {[llength $parts] < 7} {
        return [dict create ok 0 error "expected 7 tab-separated fields"]
    }

    set error [lindex $parts 6]
    if {$error ne ""} {
        return [dict create ok 0 name [lindex $parts 1] path [lindex $parts 2] error $error]
    }

    return [dict create \
        ok 1 \
        timestamp [lindex $parts 0] \
        name [lindex $parts 1] \
        path [lindex $parts 2] \
        free_mb [lindex $parts 3] \
        used_mb [lindex $parts 4] \
        total_mb [lindex $parts 5] \
        error ""]
}

proc ::dZSbot::Modules::Site::CmdBw {nick host hand chan text} {

    set replyTarget [ReplyTarget $nick $chan]

    if {![::dZSbot::Config::Get site.commands.bw.enabled 1]} {
        ::dZSbot::Commands::Reply $nick $replyTarget "BW: command is disabled."
        return
    }

    set sample [TransferSample]
    if {![dict get $sample available]} {
        ::dZSbot::Commands::Reply $nick $replyTarget "BW: unavailable ([dict get $sample error])."
        return
    }

    set active [dict get $sample active]
    set total [dict get $sample total]
    set speed [FormatSpeed [dict get $sample speed]]
    set lines [dict get $sample lines]
    set type [DictGet $sample type "transfers"]

    if {[dict exists $sample summary]} {
        ::dZSbot::Commands::Reply $nick $replyTarget [dict get $sample summary]
    } elseif {$type eq "site"} {
        ::dZSbot::Commands::Reply $nick $replyTarget "BW: site status"
    } else {
        ::dZSbot::Commands::Reply $nick $replyTarget "BW: $active active / $total online | $speed"
    }
    foreach line $lines {
        ::dZSbot::Commands::Reply $nick $replyTarget $line
    }
}

proc ::dZSbot::Modules::Site::CmdBnc {nick host hand chan text} {

    if {[BncDuplicate $nick $chan $text]} {
        return
    }

    set replyTarget [ReplyTarget $nick $chan site.commands.bnc.reply_target]

    if {![::dZSbot::Config::Get site.commands.bnc.enabled 1]} {
        ::dZSbot::Commands::Reply $nick $replyTarget "BNC: command is disabled."
        return
    }

    if {![AdminAllowed $nick $hand $chan]} {
        ::dZSbot::Commands::Reply $nick $replyTarget "BNC: command requires channel op in [::dZSbot::Config::Get status.admin_channel "#staff"]."
        return
    }

    if {[catch {set lines [BncLines $text]} error options]} {
        ::dZSbot::Logger::Error "BNC command failed: $error"
        ::dZSbot::Commands::Reply $nick $replyTarget "BNC: failed ($error)"
        return
    }

    foreach line $lines {
        ::dZSbot::Commands::Reply $nick $replyTarget $line
    }
}

proc ::dZSbot::Modules::Site::PubmBncFallback {nick host hand chan text} {

    set words [split [string trim $text]]
    if {![llength $words]} {
        return
    }

    set command [string tolower [lindex $words 0]]
    if {$command ne "!bnc"} {
        return
    }

    set rest [join [lrange $words 1 end] " "]
    CmdBnc $nick $host $hand $chan $rest
}

proc ::dZSbot::Modules::Site::BncDuplicate {nick chan text} {

    variable BncLastKey
    variable BncLastClock

    set now [clock milliseconds]
    set key "[string tolower $nick]|[string tolower $chan]|[string trim $text]"

    if {$key eq $BncLastKey && ($now - $BncLastClock) < 1000} {
        return 1
    }

    set BncLastKey $key
    set BncLastClock $now
    return 0
}

proc ::dZSbot::Modules::Site::CmdQuota {nick host hand chan text} {

    set replyTarget [ReplyTarget $nick $chan]

    if {![::dZSbot::Config::Get site.commands.quota.enabled 1]} {
        ::dZSbot::Commands::Reply $nick $replyTarget "QUOTA: command is disabled."
        return
    }

    if {[::dZSbot::Config::Get site.commands.quota.admin_only 1] && ![AdminAllowed $nick $hand $chan]} {
        ::dZSbot::Commands::Reply $nick $replyTarget "QUOTA: command requires channel op in [::dZSbot::Config::Get status.admin_channel "#staff"]."
        return
    }

    set quotaChannel [string trim [::dZSbot::Config::Get site.commands.quota.channel ""]]
    if {$quotaChannel ne ""} {
        set replyTarget $quotaChannel
    }

    foreach line [QuotaLines] {
        ::dZSbot::Commands::Reply $nick $replyTarget $line
    }
}

proc ::dZSbot::Modules::Site::CmdSiteAction {action nick host hand chan text} {

    set replyTarget [ReplyTarget $nick $chan site.commands.actions.reply_target]

    if {![::dZSbot::Config::Get site.commands.actions.enabled 1]} {
        ::dZSbot::Commands::Reply $nick $replyTarget "SITE: action commands are disabled."
        return
    }

    if {[::dZSbot::Config::Get site.commands.actions.admin_only 1] && ![AdminAllowed $nick $hand $chan]} {
        ::dZSbot::Commands::Reply $nick $replyTarget "SITE: $action requires channel op in [::dZSbot::Config::Get status.admin_channel "#staff"]."
        return
    }

    set args [string trim $text]
    if {$args eq ""} {
        ::dZSbot::Commands::Reply $nick $replyTarget "Usage: [ActionUsage $action]"
        return
    }

    set command [ActionSiteCommand $action $args]
    set result [FtpSiteCommand $command]
    if {![dict get $result ok]} {
        ::dZSbot::Commands::Reply $nick $replyTarget "SITE $action failed: [dict get $result error]"
        return
    }

    set lines [ParseSiteCommandLines [dict get $result lines]]
    if {![llength $lines]} {
        set lines [list "SITE $action: command sent."]
    }

    set maxLines [::dZSbot::Config::Get site.commands.actions.max_reply_lines 4]
    if {![string is integer -strict $maxLines] || $maxLines < 1} {
        set maxLines 4
    }

    foreach line [lrange $lines 0 [expr {$maxLines - 1}]] {
        ::dZSbot::Commands::Reply $nick $replyTarget "SITE $action: $line"
    }
}

proc ::dZSbot::Modules::Site::CmdApprove {nick host hand chan text} {
    CmdSiteAction APPROVE $nick $host $hand $chan $text
}

proc ::dZSbot::Modules::Site::CmdNuke {nick host hand chan text} {
    CmdSiteAction NUKE $nick $host $hand $chan $text
}

proc ::dZSbot::Modules::Site::CmdUnnuke {nick host hand chan text} {
    CmdSiteAction UNNUKE $nick $host $hand $chan $text
}

proc ::dZSbot::Modules::Site::CmdReqFilled {nick host hand chan text} {
    CmdSiteAction REQFILL $nick $host $hand $chan $text
}

proc ::dZSbot::Modules::Site::CmdSiteReqDel {nick host hand chan text} {
    CmdSiteAction REQDEL $nick $host $hand $chan $text
}

proc ::dZSbot::Modules::Site::CmdIncomplete {nick host hand chan text} {

    set replyTarget [ReplyTarget $nick $chan site.commands.incomplete.reply_target]

    if {![::dZSbot::Config::Get site.commands.incomplete.enabled 1]} {
        ::dZSbot::Commands::Reply $nick $replyTarget "INCOMPLETE: command is disabled."
        return
    }

    foreach line [IncompleteLines $text] {
        ::dZSbot::Commands::Reply $nick $replyTarget $line
    }
}

proc ::dZSbot::Modules::Site::QuotaLines {} {

    set cache [QuotaCacheRows]
    if {![dict get $cache ok]} {
        return [list "QUOTA: unavailable ([dict get $cache error])."]
    }

    set rows [dict get $cache rows]
    if {![llength $rows]} {
        return [list "QUOTA: no uploader data in quota cache."]
    }

    set sorted [QuotaSortRows $rows weekly_gb]
    set limit [::dZSbot::Config::Get site.commands.quota.limit 13]
    if {![string is integer -strict $limit] || $limit < 1} {
        set limit 13
    }

    set dayRanks [QuotaDayRanks $rows]
    set lines [list [QuotaHeader]]
    set rank 0
    foreach row [lrange $sorted 0 [expr {$limit - 1}]] {
        incr rank
        lappend lines [QuotaRowLine $rank $row $dayRanks]
    }

    set failLine [string trim [::dZSbot::Config::Get site.commands.quota.fail_line ""]]
    if {$failLine ne ""} {
        lappend lines $failLine
    }

    return $lines
}

proc ::dZSbot::Modules::Site::QuotaCacheRows {} {

    set path [::dZSbot::Config::Get site.commands.quota.cache_file ""]
    if {$path eq ""} {
        return [dict create ok 0 error "site.commands.quota.cache_file not configured" rows {}]
    }
    if {![file exists $path]} {
        return [dict create ok 0 error "quota cache file not found: $path" rows {}]
    }

    set maxAge [::dZSbot::Config::Get site.commands.quota.cache_max_age_seconds 3600]
    if {![string is integer -strict $maxAge] || $maxAge < 1} {
        set maxAge 3600
    }

    set age [expr {[clock seconds] - [file mtime $path]}]
    if {$age > $maxAge} {
        return [dict create ok 0 error "quota cache is stale (${age}s old)" rows {}]
    }

    if {[catch {
        set fh [open $path r]
        fconfigure $fh -encoding utf-8 -translation lf
        set content [read $fh]
        close $fh
    } error]} {
        catch {close $fh}
        return [dict create ok 0 error $error rows {}]
    }

    set rows {}
    foreach rawLine [split $content "\n"] {
        set rawLine [string trimright $rawLine "\r"]
        if {[string trim $rawLine] eq "" || [string match "#*" [string trimleft $rawLine]]} {
            continue
        }

        set parsed [ParseQuotaLine $rawLine]
        if {[dict get $parsed ok]} {
            lappend rows $parsed
        } else {
            ::dZSbot::Logger::Warn "Skipping quota row: [dict get $parsed error]"
        }
    }

    return [dict create ok 1 error "" rows $rows]
}

proc ::dZSbot::Modules::Site::ParseQuotaLine {line} {

    set parts [split $line "\t"]
    if {[llength $parts] < 4} {
        set parts [regexp -all -inline {\S+} $line]
    }
    if {[llength $parts] < 4} {
        return [dict create ok 0 error "expected user status weekly_gb today_gb"]
    }

    set user [lindex $parts 0]
    set status [lindex $parts 1]
    set weekly [NormalizeQuotaNumber [lindex $parts 2]]
    set today [NormalizeQuotaNumber [lindex $parts 3]]
    set dayRank [lindex $parts 4]

    if {$user eq "" || ![string is double -strict $weekly] || ![string is double -strict $today]} {
        return [dict create ok 0 error "invalid quota values in '$line'"]
    }
    if {![string is integer -strict $dayRank]} {
        set dayRank ""
    }

    return [dict create ok 1 user $user status $status weekly_gb $weekly today_gb $today day_rank $dayRank]
}

proc ::dZSbot::Modules::Site::NormalizeQuotaNumber {value} {

    set clean [string trim $value]
    regsub -nocase {(gb|g)$} $clean "" clean
    return [string trim $clean]
}

proc ::dZSbot::Modules::Site::QuotaHeader {} {

    set server [::dZSbot::Config::Get site.commands.quota.server_name "SomeServer"]
    set quota [::dZSbot::Config::Get site.commands.quota.required_gb 0]
    set period [::dZSbot::Config::Get site.commands.quota.period_label "Weekly"]
    set rule [::dZSbot::Config::Get site.commands.quota.rule_label "20% top-1"]
    set daysLeft [QuotaDaysLeft]

    return "\[ $server\]-\[ QUOTA [format "%.2f" $quota]/GB \]-\[ $period $rule \]-\[ $daysLeft DAYS LEFT \]"
}

proc ::dZSbot::Modules::Site::QuotaDaysLeft {} {

    set configured [::dZSbot::Config::Get site.commands.quota.days_left ""]
    if {[string is integer -strict $configured] && $configured >= 0} {
        return $configured
    }

    set resetDay [::dZSbot::Config::Get site.commands.quota.week_reset_day 1]
    if {![string is integer -strict $resetDay] || $resetDay < 0 || $resetDay > 6} {
        set resetDay 1
    }

    set today [clock format [clock seconds] -format %w]
    set days [expr {($resetDay - $today + 7) % 7}]
    if {$days == 0} {
        set days 7
    }
    return $days
}

proc ::dZSbot::Modules::Site::QuotaSortRows {rows field} {

    set pairs {}
    foreach row $rows {
        lappend pairs [list [DictGet $row $field 0] $row]
    }

    set result {}
    foreach pair [lsort -real -decreasing -index 0 $pairs] {
        lappend result [lindex $pair 1]
    }
    return $result
}

proc ::dZSbot::Modules::Site::QuotaDayRanks {rows} {

    set limit [::dZSbot::Config::Get site.commands.quota.dayup_limit 3]
    if {![string is integer -strict $limit] || $limit < 1} {
        return {}
    }

    set ranks {}
    set rank 0
    foreach row [QuotaSortRows $rows today_gb] {
        incr rank
        if {$rank > $limit} {
            break
        }
        dict set ranks [string tolower [dict get $row user]] $rank
    }

    return $ranks
}

proc ::dZSbot::Modules::Site::QuotaRowLine {rank row dayRanks} {

    set user [dict get $row user]
    set status [dict get $row status]
    set weekly [format "%.2f" [dict get $row weekly_gb]]
    set today [format "%.2f" [dict get $row today_gb]]
    set dayRank [dict get $row day_rank]

    if {$dayRank eq ""} {
        set key [string tolower $user]
        if {[dict exists $dayRanks $key]} {
            set dayRank [dict get $dayRanks $key]
        }
    }

    set suffix ""
    if {$dayRank ne ""} {
        set suffix " (#$dayRank DAYUP)"
    }

    return "[format "%02d" $rank]: $user $status with $weekly GB | today: $today GB$suffix"
}

proc ::dZSbot::Modules::Site::StartQuotaAuto {} {

    variable QuotaAutoTimer

    if {$QuotaAutoTimer ne "" && [llength [info commands ::killutimer]]} {
        catch {::killutimer $QuotaAutoTimer}
        set QuotaAutoTimer ""
    }

    if {![::dZSbot::Config::Get site.commands.quota.auto.enabled 0]} {
        return
    }
    if {![llength [info commands ::utimer]]} {
        return
    }

    set interval [::dZSbot::Config::Get site.commands.quota.auto.interval_seconds 7200]
    if {![string is integer -strict $interval] || $interval < 60} {
        set interval 7200
    }

    set QuotaAutoTimer [::utimer $interval ::dZSbot::Modules::Site::RunQuotaAuto]
}

proc ::dZSbot::Modules::Site::RunQuotaAuto {} {

    set channel [string trim [::dZSbot::Config::Get site.commands.quota.auto.channel [::dZSbot::Config::Get site.commands.quota.channel "#monstra"]]]
    if {$channel ne ""} {
        foreach line [QuotaLines] {
            ::dZSbot::Commands::Reply "" $channel $line
        }
    }

    StartQuotaAuto
}

proc ::dZSbot::Modules::Site::ActionSiteCommand {action args} {

    set command [::dZSbot::Config::Get "site.commands.actions.command.$action" $action]
    return "[string trim $command] $args"
}

proc ::dZSbot::Modules::Site::ActionUsage {action} {

    switch -- $action {
        APPROVE { return "!approve <release/path>" }
        NUKE { return "!nuke <release/path> <multiplier> <reason>" }
        UNNUKE { return "!unnuke <release/path> <reason>" }
        REQFILL { return "!reqfilled <request/release>" }
        REQDEL { return "!reqdel <request/release>" }
    }

    return "![string tolower $action] <args>"
}

proc ::dZSbot::Modules::Site::IncompleteLines {{filter ""}} {

    set cache [IncompleteRows]
    if {![dict get $cache ok]} {
        return [list "INCOMPLETE: unavailable ([dict get $cache error])."]
    }

    set filter [string toupper [string trim $filter]]
    set sections {}
    foreach configured [::dZSbot::Config::Get site.commands.incomplete.sections {}] {
        lappend sections [string toupper $configured]
    }

    set limit [::dZSbot::Config::Get site.commands.incomplete.limit 20]
    if {![string is integer -strict $limit] || $limit < 1} {
        set limit 20
    }

    set lines {}
    set count 0
    foreach row [dict get $cache rows] {
        set section [string toupper [dict get $row section]]
        set release [dict get $row release]
        if {[llength $sections] && $section ni $sections} {
            continue
        }
        if {$filter ne "" && ![string match "*$filter*" $section] && ![string match "*$filter*" [string toupper $release]]} {
            continue
        }

        incr count
        lappend lines "INCOMPLETE: $section | $release | [dict get $row age] | [dict get $row user]/[dict get $row group]"
        if {[llength $lines] >= $limit} {
            break
        }
    }

    if {![llength $lines]} {
        if {$filter ne ""} {
            return [list "INCOMPLETE: no entries matched '$filter'."]
        }
        return [list "INCOMPLETE: no incomplete releases."]
    }

    return [linsert $lines 0 "INCOMPLETE: showing [llength $lines] of $count matching entries"]
}

proc ::dZSbot::Modules::Site::IncompleteRows {} {

    set path [::dZSbot::Config::Get site.commands.incomplete.cache_file ""]
    if {$path eq ""} {
        return [dict create ok 0 error "site.commands.incomplete.cache_file not configured" rows {}]
    }
    if {![file exists $path]} {
        return [dict create ok 0 error "incomplete cache file not found: $path" rows {}]
    }

    set maxAge [::dZSbot::Config::Get site.commands.incomplete.cache_max_age_seconds 3600]
    if {[string is integer -strict $maxAge] && $maxAge > 0} {
        set age [expr {[clock seconds] - [file mtime $path]}]
        if {$age > $maxAge} {
            return [dict create ok 0 error "incomplete cache is stale (${age}s old)" rows {}]
        }
    }

    set fh [open $path r]
    fconfigure $fh -encoding utf-8
    set rows {}
    while {[gets $fh line] >= 0} {
        set line [string trim $line]
        if {$line eq "" || [string match "#*" $line]} {
            continue
        }
        set parsed [ParseIncompleteLine $line]
        if {[dict get $parsed ok]} {
            lappend rows $parsed
        } else {
            ::dZSbot::Logger::Warn "Skipping incomplete row: [dict get $parsed error]"
        }
    }
    close $fh

    return [dict create ok 1 rows $rows]
}

proc ::dZSbot::Modules::Site::ParseIncompleteLine {line} {

    set parts [split $line "\t"]
    if {[llength $parts] < 3} {
        return [dict create ok 0 error "expected timestamp section release"]
    }

    set timestamp [lindex $parts 0]
    set age $timestamp
    if {[string is integer -strict $timestamp]} {
        set age [AgeLabel [expr {[clock seconds] - $timestamp}]]
    }

    set user "UNKNOWN"
    if {[llength $parts] > 4} {
        set user [lindex $parts 4]
    }
    set group "UNKNOWN"
    if {[llength $parts] > 5} {
        set group [lindex $parts 5]
    }

    return [dict create \
        ok 1 \
        timestamp $timestamp \
        age $age \
        section [lindex $parts 1] \
        release [lindex $parts 2] \
        path [lindex $parts 3] \
        user $user \
        group $group]
}

proc ::dZSbot::Modules::Site::BncLines {{filter ""}} {

    set targets [BncTargets]
    set filter [string toupper [string trim $filter]]

    if {![llength $targets]} {
        return [list "BNC: no BNC targets configured. Set site.commands.bnc.targets in config/modules/site.conf."]
    }

    set lines {}
    set online 0
    set checked 0

    foreach target $targets {
        if {![dict get $target ok]} {
            lappend lines "BNC: ERROR | [dict get $target error]"
            continue
        }

        set name [string toupper [dict get $target name]]
        if {$filter ne "" && ![string match "*$filter*" $name]} {
            continue
        }

        incr checked
        set result [BncCheckTarget $target]
        set endpoint [BncEndpoint $target $result]
        if {[dict get $result ok]} {
            incr online
            set detail "[dict get $result ms]ms"
            if {[dict exists $result detail] && [dict get $result detail] ne ""} {
                set detail [dict get $result detail]
            }
            lappend lines "BNC: $name | OK | $endpoint | $detail"
        } else {
            lappend lines "BNC: $name | DOWN | $endpoint | [dict get $result error]"
        }
    }

    if {!$checked} {
        return [list "BNC: no configured target matched '$filter'."]
    }

    return [linsert $lines 0 "BNC: $online/$checked online"]
}

proc ::dZSbot::Modules::Site::BncTargets {} {

    set raw [::dZSbot::Config::Get site.commands.bnc.targets {}]
    set result {}

    foreach target $raw {
        lappend result [ParseBncTarget $target]
    }

    return $result
}

proc ::dZSbot::Modules::Site::ParseBncTarget {target} {

    if {[catch {set count [llength $target]} error]} {
        return [dict create ok 0 error $error]
    }
    if {$count < 2} {
        return [dict create ok 0 error "expected {NAME HOST PORT} or {NAME eggdrop 0}"]
    }

    set name [string trim [lindex $target 0]]
    set host [string trim [lindex $target 1]]
    set port 0
    if {$count >= 3} {
        set port [string trim [lindex $target 2]]
    }

    if {$name eq "" || $host eq ""} {
        return [dict create ok 0 error "empty name or host"]
    }

    set mode "tcp"
    if {[string tolower $host] in {eggdrop current irc-current irc_current}} {
        set mode "eggdrop"
        set port 0
    }

    if {$mode eq "tcp" && ($port eq "" || ![string is integer -strict $port] || $port < 1 || $port > 65535)} {
        return [dict create ok 0 error "invalid port for $name: $port"]
    }
    if {$mode eq "eggdrop" && $count >= 3 && $port ne "0"} {
        return [dict create ok 0 error "eggdrop target for $name must use port 0"]
    }

    return [dict create ok 1 name $name host $host port $port mode $mode]
}

proc ::dZSbot::Modules::Site::SetBncCheckCommand {command} {

    variable BncCheckCommand
    set BncCheckCommand $command
}

proc ::dZSbot::Modules::Site::BncCheckTarget {target} {

    variable BncCheckCommand

    if {$BncCheckCommand ne ""} {
        return [uplevel #0 [list $BncCheckCommand $target]]
    }

    if {[dict exists $target mode] && [dict get $target mode] eq "eggdrop"} {
        return [EggdropIrcCheck]
    }

    return [TcpCheck [dict get $target host] [dict get $target port] [::dZSbot::Config::Get site.commands.bnc.timeout_ms 3000]]
}

proc ::dZSbot::Modules::Site::BncEndpoint {target result} {

    if {[dict exists $result endpoint] && [dict get $result endpoint] ne ""} {
        return [dict get $result endpoint]
    }

    return "[dict get $target host]:[dict get $target port]"
}

proc ::dZSbot::Modules::Site::EggdropIrcCheck {} {

    set endpoint "Eggdrop IRC connection"
    if {[info exists ::server] && [string trim $::server] ne ""} {
        set endpoint [string trim $::server]
    }

    set detail "connected"
    if {[info exists ::server-online] && [string is integer -strict ${::server-online}] && ${::server-online} > 0} {
        set seconds [expr {[clock seconds] - ${::server-online}}]
        if {$seconds < 0} {
            set seconds 0
        }
        set detail "online [BncFormatDuration $seconds]"
    }

    if {[info exists ::server] && [string trim $::server] ne "" && [llength [info commands ::putserv]]} {
        return [dict create ok 1 ms 0 error "" endpoint $endpoint detail $detail]
    }
    if {[info exists ::server-online] && [string is integer -strict ${::server-online}] && ${::server-online} > 0} {
        return [dict create ok 1 ms 0 error "" endpoint $endpoint detail $detail]
    }

    return [dict create ok 0 ms 0 error "Eggdrop IRC connection unavailable" endpoint $endpoint]
}

proc ::dZSbot::Modules::Site::BncFormatDuration {seconds} {

    if {![string is integer -strict $seconds] || $seconds < 0} {
        set seconds 0
    }

    set days [expr {$seconds / 86400}]
    set hours [expr {($seconds % 86400) / 3600}]
    set minutes [expr {($seconds % 3600) / 60}]

    if {$days > 0} {
        return "${days}d ${hours}h"
    }
    if {$hours > 0} {
        return "${hours}h ${minutes}m"
    }
    return "${minutes}m"
}

proc ::dZSbot::Modules::Site::AgeLabel {seconds} {

    if {![string is integer -strict $seconds] || $seconds < 0} {
        set seconds 0
    }

    set days [expr {$seconds / 86400}]
    set hours [expr {($seconds % 86400) / 3600}]
    set minutes [expr {($seconds % 3600) / 60}]

    if {$days > 0} {
        return "${days}d ${hours}h ago"
    }
    if {$hours > 0} {
        return "${hours}h ${minutes}m ago"
    }
    return "${minutes}m ago"
}

proc ::dZSbot::Modules::Site::TcpCheck {host port timeoutMs} {

    variable BncToken

    if {![string is integer -strict $timeoutMs] || $timeoutMs < 100} {
        set timeoutMs 3000
    }

    set start [clock milliseconds]
    set token [namespace current]::BncCheck[incr BncToken]

    if {[catch {set sock [socket -async $host $port]} error]} {
        return [dict create ok 0 ms 0 error $error]
    }

    catch {fconfigure $sock -blocking 0 -translation binary}
    set ${token}(done) 0
    set ${token}(ok) 0
    set ${token}(error) ""

    set timer [after $timeoutMs [list ::dZSbot::Modules::Site::TcpCheckTimeout $token $sock]]
    fileevent $sock writable [list ::dZSbot::Modules::Site::TcpCheckWritable $token $sock]
    vwait ${token}(done)

    catch {after cancel $timer}
    catch {fileevent $sock writable {}}
    catch {close $sock}

    set ok [set ${token}(ok)]
    set error [set ${token}(error)]
    unset -nocomplain ${token}(done) ${token}(ok) ${token}(error)

    if {$ok} {
        return [dict create ok 1 ms [expr {[clock milliseconds] - $start}] error ""]
    }

    if {$error eq ""} {
        set error "connection failed"
    }
    return [dict create ok 0 ms [expr {[clock milliseconds] - $start}] error $error]
}

proc ::dZSbot::Modules::Site::TcpCheckWritable {token sock} {

    set error ""
    catch {set error [fconfigure $sock -error]}
    if {$error eq ""} {
        set ${token}(ok) 1
    } else {
        set ${token}(ok) 0
        set ${token}(error) $error
    }
    set ${token}(done) 1
}

proc ::dZSbot::Modules::Site::TcpCheckTimeout {token sock} {

    set ${token}(ok) 0
    set ${token}(error) "timeout"
    set ${token}(done) 1
}

proc ::dZSbot::Modules::Site::AdminAllowed {nick hand chan} {

    set adminChan [::dZSbot::Config::Get status.admin_channel "#staff"]
    if {$adminChan ne "" && ![string equal -nocase $chan $adminChan]} {
        return 0
    }

    if {![::dZSbot::Config::Get status.require_channel_op 1]} {
        return 1
    }

    if {[llength [info commands ::isop]] && [::isop $nick $chan]} {
        return 1
    }

    if {[llength [info commands ::matchattr]] && $hand ne ""} {
        foreach flags {n m o} {
            if {[::matchattr $hand $flags $chan]} {
                return 1
            }
        }
    }

    if {![llength [info commands ::isop]] && ![llength [info commands ::matchattr]]} {
        return 1
    }

    return 0
}

proc ::dZSbot::Modules::Site::ReplyTarget {nick chan {configKey "site.commands.reply_target"}} {

    set target [string tolower [::dZSbot::Config::Get $configKey [::dZSbot::Config::Get site.commands.reply_target "channel"]]]
    if {$target in {private privmsg pm query nick user} && $nick ne ""} {
        return $nick
    }

    return $chan
}

proc ::dZSbot::Modules::Site::DiskFree {path} {

    if {![file exists $path]} {
        return [dict create ok 0 error "path not found: $path"]
    }

    EnsureExecTempDir

    set psPath [PowerShellPath $path]
    set escapedPath [PowerShellSingleQuote $psPath]
    set script [string map [list @@PATH@@ $escapedPath] {
            $p = '@@PATH@@'
            $item = Get-Item -LiteralPath $p -ErrorAction Stop
            $drive = [System.IO.DriveInfo]::new($item.PSDrive.Root)
            $free = [int64]($drive.AvailableFreeSpace / 1MB)
            $total = [int64]($drive.TotalSize / 1MB)
            $used = [int64](($drive.TotalSize - $drive.AvailableFreeSpace) / 1MB)
            [Console]::Out.WriteLine("$free|$used|$total")
        }]
    set command [list powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass \
        -Command $script]

    if {[catch {set output [exec {*}$command 2>@1]} error]} {
        return [dict create ok 0 error $error]
    }

    set parts [split [string trim $output] "|"]
    if {[llength $parts] < 3} {
        return [dict create ok 0 error "invalid disk output"]
    }

    return [dict create \
        ok 1 \
        free_mb [lindex $parts 0] \
        used_mb [lindex $parts 1] \
        total_mb [lindex $parts 2]]
}

proc ::dZSbot::Modules::Site::EnsureExecTempDir {} {

    set tempDir [file join $::dZSbot::Root runtime tmp]
    if {![file isdirectory $tempDir]} {
        file mkdir $tempDir
    }

    set normalized [file normalize $tempDir]
    set ::env(TMP) $normalized
    set ::env(TEMP) $normalized
    set ::env(TMPDIR) $normalized
}

proc ::dZSbot::Modules::Site::PowerShellPath {path} {

    set normalized [file normalize $path]
    if {[regexp {^[A-Za-z]:[/\\]} $normalized] || [string match "\\\\*" $normalized]} {
        return $normalized
    }

    set cygpath [::dZSbot::Config::Get site.commands.cygpath "C:/cygwin64/bin/cygpath.exe"]
    if {![file exists $cygpath]} {
        set cygpath "cygpath"
    }

    if {[catch {set converted [exec $cygpath -aw $normalized]}]} {
        return $normalized
    }

    return [string trim $converted]
}

proc ::dZSbot::Modules::Site::PowerShellSingleQuote {value} {

    return [string map [list "'" "''"] $value]
}

proc ::dZSbot::Modules::Site::FormatDfLine {name path result} {

    if {![dict get $result ok]} {
        return "DF: $name | ERROR | [dict get $result error]"
    }

    set free [dict get $result free_mb]
    set used [dict get $result used_mb]
    set total [dict get $result total_mb]
    set pct "N/A"

    if {[string is double -strict $total] && $total > 0} {
        set pct [format "%.1f%% free" [expr {($free * 100.0) / $total}]]
    }

    return "DF: $name | free [FormatBytesMb $free] / total [FormatBytesMb $total] | used [FormatBytesMb $used] | $pct"
}

proc ::dZSbot::Modules::Site::TransferSample {} {

    set source [string tolower [::dZSbot::Config::Get site.commands.bw.source "cache"]]

    if {$source in {auto fluxftp api}} {
        set sample [FluxFtpTransferSample]
        if {[dict get $sample available]} {
            return $sample
        }
        if {$source ni {auto} && [BwFallbackEnabled]} {
            set fallback [CacheTransferSample]
            if {[dict get $fallback available]} {
                return $fallback
            }
            dict set sample error "[dict get $sample error]; fallback failed: [dict get $fallback error]"
        }
        if {$source ne "auto"} {
            return $sample
        }
    }

    if {$source in {auto cache file status}} {
        set sample [CacheTransferSample]
        if {[dict get $sample available] || $source ne "auto"} {
            return $sample
        }
    }

    if {$source in {auto ioftpd local} && [llength [info commands ::ioftpd]]} {
        set sample [IoFtpdWhoSample]
        if {[dict get $sample available] || $source ne "auto"} {
            return $sample
        }
    }

    if {$source in {ftps ftp site}} {
        set sample [SiteCommandSample]
        if {[dict get $sample available] || $source ne "auto"} {
            return $sample
        }
    }

    return [dict create available 0 total 0 active 0 speed 0 lines {} error "no usable BW source" type none]
}

proc ::dZSbot::Modules::Site::FluxFtpAvailable {} {

    if {![llength [info commands ::dZSbot::Adapter::FluxFTP::Enabled]]} {
        return 0
    }

    if {![::dZSbot::Adapter::FluxFTP::Enabled]} {
        return 0
    }

    return 1
}

proc ::dZSbot::Modules::Site::DfFallbackEnabled {} {

    set fallback [string tolower [::dZSbot::Config::Get site.commands.df.fallback "cache"]]
    return [expr {$fallback in {cache file status}}]
}

proc ::dZSbot::Modules::Site::BwFallbackEnabled {} {

    set fallback [string tolower [::dZSbot::Config::Get site.commands.bw.fallback "cache"]]
    return [expr {$fallback in {cache file status}}]
}

proc ::dZSbot::Modules::Site::FluxFtpTransferSample {} {

    if {![FluxFtpAvailable]} {
        return [dict create available 0 total 0 active 0 speed 0 lines {} error "FluxFTP adapter unavailable" type fluxftp]
    }

    if {[catch {set result [::dZSbot::Adapter::FluxFTP::Bandwidth]} error]} {
        return [dict create available 0 total 0 active 0 speed 0 lines {} error $error type fluxftp]
    }
    if {![dict get $result ok]} {
        return [dict create available 0 total 0 active 0 speed 0 lines {} error [DictGet $result error "FluxFTP bandwidth failed"] type fluxftp]
    }

    set uploadCount [DictGet $result upload_count 0]
    set downloadCount [DictGet $result download_count 0]
    set transferCount [DictGet $result transfer_count 0]
    set idleCount [DictGet $result idle_count 0]
    set uploadSpeed [DictGet $result upload_speed_kbps 0]
    set downloadSpeed [DictGet $result download_speed_kbps 0]
    set transferSpeed [DictGet $result transfer_speed_kbps 0]
    set totalSpeed [DictGet $result total_speed_kbps [expr {$uploadSpeed + $downloadSpeed}]]
    set active [expr {$uploadCount + $downloadCount + $transferCount}]
    set total [expr {$active + $idleCount}]
    set showIdle [::dZSbot::Config::Get site.commands.bw.show_idle 0]
    set lines {}

    foreach transfer [DictGet $result transfers {}] {
        set direction [DictGet $transfer direction "unknown"]
        set speed [DictGet $transfer speed_kbps 0]
        if {($direction eq "idle" || $speed <= 0) && !$showIdle} {
            continue
        }

        lappend lines [FormatFluxFtpTransferLine $transfer]
    }

    set summary "BW: UP $uploadCount @ [FormatSpeed $uploadSpeed] | DN $downloadCount @ [FormatSpeed $downloadSpeed]"
    if {$transferCount > 0} {
        append summary " | XFER $transferCount @ [FormatSpeed $transferSpeed]"
    }
    append summary " | idle $idleCount | total [FormatSpeed $totalSpeed]"

    return [dict create \
        available 1 \
        total $total \
        active $active \
        speed $totalSpeed \
        lines [LimitLines $lines] \
        summary $summary \
        error "" \
        type fluxftp]
}

proc ::dZSbot::Modules::Site::CacheTransferSample {} {

    set path [::dZSbot::Config::Get site.commands.bw.cache_file ""]
    if {$path eq ""} {
        return [dict create available 0 total 0 active 0 speed 0 lines {} error "site.commands.bw.cache_file not configured" type cache]
    }
    if {![file exists $path]} {
        return [dict create available 0 total 0 active 0 speed 0 lines {} error "BW cache file not found: $path" type cache]
    }

    set maxAge [::dZSbot::Config::Get site.commands.bw.cache_max_age_seconds 15]
    if {![string is integer -strict $maxAge] || $maxAge < 1} {
        set maxAge 15
    }

    set age [expr {[clock seconds] - [file mtime $path]}]
    if {$age > $maxAge} {
        return [dict create available 0 total 0 active 0 speed 0 lines {} error "BW cache is stale (${age}s old)" type cache]
    }

    if {[catch {
        set fh [open $path r]
        fconfigure $fh -encoding utf-8 -translation lf
        set content [read $fh]
        close $fh
    } error]} {
        catch {close $fh}
        return [dict create available 0 total 0 active 0 speed 0 lines {} error $error type cache]
    }

    set total 0
    set active 0
    set idle 0
    set uploadCount 0
    set downloadCount 0
    set uploadSpeed 0.0
    set downloadSpeed 0.0
    set unknownSpeed 0.0
    set lines {}
    set showIdle [::dZSbot::Config::Get site.commands.bw.show_idle 0]

    foreach rawLine [split $content "\n"] {
        set rawLine [string trimright $rawLine "\r"]
        if {[string trim $rawLine] eq "" || [string match "#*" [string trimleft $rawLine]]} {
            continue
        }

        set entry [ParseBwCacheLine $rawLine]
        if {![dict get $entry ok]} {
            continue
        }

        incr total
        set direction [dict get $entry direction]
        set speed [dict get $entry speed]
        set isIdle [expr {$direction eq "idle" || (![string is double -strict $speed] || $speed <= 0)}]

        if {$isIdle} {
            incr idle
        } else {
            incr active
        }

        if {$direction eq "upload"} {
            incr uploadCount
            if {[string is double -strict $speed]} {
                set uploadSpeed [expr {$uploadSpeed + $speed}]
            }
        } elseif {$direction eq "download"} {
            incr downloadCount
            if {[string is double -strict $speed]} {
                set downloadSpeed [expr {$downloadSpeed + $speed}]
            }
        } elseif {[string is double -strict $speed]} {
            set unknownSpeed [expr {$unknownSpeed + $speed}]
        }

        if {!$isIdle || $showIdle} {
            lappend lines [FormatCacheTransferLine $entry]
        }
    }

    set totalSpeed [expr {$uploadSpeed + $downloadSpeed + $unknownSpeed}]
    set summary "BW: UP $uploadCount @ [FormatSpeed $uploadSpeed] | DN $downloadCount @ [FormatSpeed $downloadSpeed] | idle $idle | total [FormatSpeed $totalSpeed]"

    return [dict create \
        available 1 \
        total $total \
        active $active \
        speed $totalSpeed \
        lines [LimitLines $lines] \
        summary $summary \
        error "" \
        type cache]
}

proc ::dZSbot::Modules::Site::ParseBwCacheLine {line} {

    set parts [split $line "\t"]
    if {[llength $parts] < 7} {
        return [dict create ok 0 error "expected 7 tab-separated fields"]
    }

    set direction [NormalizeDirection [lindex $parts 1]]
    set speed [lindex $parts 4]
    if {![string is double -strict $speed]} {
        set speed 0
    }

    return [dict create \
        ok 1 \
        timestamp [lindex $parts 0] \
        direction $direction \
        user [lindex $parts 2] \
        group [lindex $parts 3] \
        speed $speed \
        vpath [lindex $parts 5] \
        datapath [lindex $parts 6] \
        status [lindex $parts 7]]
}

proc ::dZSbot::Modules::Site::NormalizeDirection {value} {

    set direction [string tolower [string trim $value]]
    if {$direction in {up upload uploading stor}} {
        return "upload"
    }
    if {$direction in {dn down download downloading retr fxp}} {
        return "download"
    }
    if {$direction in {idle none}} {
        return "idle"
    }

    return "unknown"
}

proc ::dZSbot::Modules::Site::IoFtpdWhoSample {} {

    set messageWindow [::dZSbot::Config::Get site.ioftpd.message_window "ioFTPD::MessageWindow"]
    if {[catch {
        set online [::ioftpd who $messageWindow "status user group speed vpath"]
    } error]} {
        return [dict create available 0 total 0 active 0 speed 0 lines {} error $error type ioftpd]
    }

    set total 0
    set active 0
    set speed 0.0
    set lines {}
    set showIdle [::dZSbot::Config::Get site.commands.bw.show_idle 0]

    foreach entry $online {
        foreach {status user group userSpeed vpath} $entry {
            break
        }

        incr total
        set isActive [expr {$status eq "1"}]
        if {$isActive} {
            incr active
            if {[string is double -strict $userSpeed]} {
                set speed [expr {$speed + $userSpeed}]
            }
        }

        if {$isActive || $showIdle} {
            lappend lines [FormatTransferLine $status $user $group $userSpeed $vpath]
        }
    }

    return [dict create available 1 total $total active $active speed $speed lines $lines error "" type transfers]
}

proc ::dZSbot::Modules::Site::SiteCommandSample {} {

    set user [::dZSbot::Config::Get site.user ""]
    set password [::dZSbot::Config::Get site.password ""]

    if {$user eq "" || $password eq ""} {
        return [dict create available 0 total 0 active 0 speed 0 lines {} error "site.user/site.password not configured" type site]
    }

    set commands [::dZSbot::Config::Get site.commands.bw.site_commands {"TRAFFIC" "STATS"}]
    set output {}

    foreach command $commands {
        set result [FtpSiteCommand $command]
        if {[dict get $result ok]} {
            foreach line [ParseSiteCommandLines [dict get $result lines]] {
                lappend output "BW: $line"
            }
            if {[llength $output]} {
                return [dict create available 1 total 0 active 0 speed 0 lines [LimitLines $output] error "" type site]
            }
        } else {
            ::dZSbot::Logger::Warn "SITE $command failed: [dict get $result error]"
        }
    }

    return [dict create available 0 total 0 active 0 speed 0 lines {} error "SITE traffic commands returned no usable output" type site]
}

proc ::dZSbot::Modules::Site::FtpSiteCommand {siteCommand} {

    set host [::dZSbot::Config::Get site.host "127.0.0.1"]
    set port [::dZSbot::Config::Get site.port 5420]
    set user [::dZSbot::Config::Get site.user ""]
    set password [::dZSbot::Config::Get site.password ""]
    set transport [string tolower [::dZSbot::Config::Get site.command_transport "ftps"]]
    set timeout [::dZSbot::Config::Get site.commands.bw.timeout_ms 10000]
    set sock ""

    if {[catch {
        if {$transport eq "ftps"} {
            package require tls
        }

        set sock [socket $host $port]
        ConfigureControlSocket $sock
        set responses [list [FtpReadResponse $sock $timeout]]

        if {$transport eq "ftps"} {
            FtpWrite $sock "AUTH TLS"
            lappend responses [FtpReadResponse $sock $timeout]
            ::tls::import $sock -require 0
            ConfigureControlSocket $sock
            FtpWrite $sock "PBSZ 0"
            lappend responses [FtpReadResponse $sock $timeout]
            FtpWrite $sock "PROT P"
            lappend responses [FtpReadResponse $sock $timeout]
        }

        FtpWrite $sock "USER $user"
        lappend responses [FtpReadResponse $sock $timeout]
        FtpWrite $sock "PASS $password"
        lappend responses [FtpReadResponse $sock $timeout]
        FtpWrite $sock "SITE $siteCommand"
        lappend responses [FtpReadResponse $sock $timeout]
        catch {FtpWrite $sock "QUIT"}
        catch {FtpReadResponse $sock 1000}
        close $sock
        set sock ""
    } error]} {
        catch {close $sock}
        return [dict create ok 0 error $error lines {}]
    }

    set lines {}
    foreach response $responses {
        foreach line [dict get $response lines] {
            lappend lines $line
        }
    }

    return [dict create ok 1 lines $lines]
}

proc ::dZSbot::Modules::Site::ConfigureControlSocket {sock} {

    fconfigure $sock -blocking 1 -buffering line -translation crlf -encoding iso8859-1
}

proc ::dZSbot::Modules::Site::FtpWrite {sock command} {

    puts $sock $command
    flush $sock
}

proc ::dZSbot::Modules::Site::FtpReadResponse {sock timeoutMs} {

    set deadline [expr {[clock milliseconds] + $timeoutMs}]
    set lines {}
    set code ""

    while {[clock milliseconds] < $deadline} {
        if {[eof $sock]} {
            break
        }

        if {[catch {set line [gets $sock]} error]} {
            error $error
        }
        if {$line eq "" && [eof $sock]} {
            break
        }

        set line [string trimright $line "\r"]
        lappend lines $line

        if {[regexp {^([0-9][0-9][0-9])[- ]} $line -> currentCode]} {
            if {$code eq ""} {
                set code $currentCode
            }
            if {[regexp "^$code " $line]} {
                return [dict create code $code lines $lines]
            }
        } elseif {[llength $lines] > 0 && $code eq ""} {
            return [dict create code "" lines $lines]
        }
    }

    if {[llength $lines]} {
        return [dict create code $code lines $lines]
    }

    error "FTP response timed out"
}

proc ::dZSbot::Modules::Site::ParseSiteCommandLines {lines} {

    set result {}
    foreach line $lines {
        set clean [string trim $line]
        regsub {^[0-9][0-9][0-9][- ]} $clean "" clean
        set clean [string trim $clean " \t|"]

        if {$clean eq ""} {
            continue
        }
        if {[regexp -nocase {^(user|pass|auth tls|pbsz|prot|quit|site)} $clean]} {
            continue
        }
        if {[regexp {^[0-9][0-9][0-9]$} $clean]} {
            continue
        }

        lappend result $clean
    }

    return $result
}

proc ::dZSbot::Modules::Site::LimitLines {lines} {

    set max [::dZSbot::Config::Get site.commands.bw.max_lines 6]
    if {![string is integer -strict $max] || $max <= 0} {
        return $lines
    }

    return [lrange $lines 0 [expr {$max - 1}]]
}

proc ::dZSbot::Modules::Site::FormatTransferLine {status user group speed vpath} {

    set label [expr {$status eq "1" ? "XFER" : "IDLE"}]
    return "BW: $label | $user/$group | [FormatSpeed $speed] | $vpath"
}

proc ::dZSbot::Modules::Site::FormatCacheTransferLine {entry} {

    set direction [dict get $entry direction]
    set label [string toupper $direction]
    if {$label eq "UPLOAD"} {
        set label "UP"
    } elseif {$label eq "DOWNLOAD"} {
        set label "DN"
    } elseif {$label eq "TRANSFER"} {
        set label "XFER"
    } elseif {$label eq "UNKNOWN"} {
        set label "XFER"
    }

    set user [dict get $entry user]
    set group [dict get $entry group]
    set account $user
    if {$group ne ""} {
        set account "$user/$group"
    }

    set path [dict get $entry vpath]
    if {$path eq ""} {
        set path [dict get $entry datapath]
    }

    return "BW: $label | $account | [FormatSpeed [dict get $entry speed]] | $path"
}

proc ::dZSbot::Modules::Site::FormatFluxFtpTransferLine {entry} {

    set direction [DictGet $entry direction "unknown"]
    set label [string toupper $direction]
    if {$label eq "UPLOAD"} {
        set label "UP"
    } elseif {$label eq "DOWNLOAD"} {
        set label "DN"
    } elseif {$label eq "UNKNOWN"} {
        set label "XFER"
    }

    set user [DictGet $entry user ""]
    set group [DictGet $entry group ""]
    set account $user
    if {$group ne ""} {
        set account "$user/$group"
    }
    if {$account eq ""} {
        set account "unknown"
    }

    return "BW: $label | $account | [FormatSpeed [DictGet $entry speed_kbps 0]] | [DictGet $entry path ""]"
}

proc ::dZSbot::Modules::Site::DictGet {dictValue key default} {

    if {[catch {dict exists $dictValue $key} exists] || !$exists} {
        return $default
    }

    return [dict get $dictValue $key]
}

proc ::dZSbot::Modules::Site::FormatBytesMb {value} {

    if {![string is double -strict $value]} {
        return "N/A"
    }

    if {$value >= 1048576} {
        return [format "%.2f TB" [expr {$value / 1048576.0}]]
    }
    if {$value >= 1024} {
        return [format "%.2f GB" [expr {$value / 1024.0}]]
    }

    return [format "%.0f MB" $value]
}

proc ::dZSbot::Modules::Site::FormatSpeed {value} {

    if {![string is double -strict $value]} {
        return "N/A"
    }

    if {$value >= 1048576} {
        return [format "%.2f GB/s" [expr {$value / 1048576.0}]]
    }
    if {$value >= 1024} {
        return [format "%.2f MB/s" [expr {$value / 1024.0}]]
    }

    return [format "%.0f KB/s" $value]
}

::dZSbot::Commands::Register site !df ::dZSbot::Modules::Site::CmdDf "Show site disk free"
::dZSbot::Commands::Register site !bw ::dZSbot::Modules::Site::CmdBw "Show site transfer bandwidth"
::dZSbot::Commands::Register site !bnc ::dZSbot::Modules::Site::CmdBnc "Show BNC status"
::dZSbot::Commands::Register site !quota ::dZSbot::Modules::Site::CmdQuota "Show weekly quota uploaders"
::dZSbot::Commands::Register site !weekly ::dZSbot::Modules::Site::CmdQuota "Show weekly quota uploaders"
::dZSbot::Commands::Register site !approve ::dZSbot::Modules::Site::CmdApprove "Approve a site release"
::dZSbot::Commands::Register site !nuke ::dZSbot::Modules::Site::CmdNuke "Nuke a site release"
::dZSbot::Commands::Register site !unnuke ::dZSbot::Modules::Site::CmdUnnuke "Unnuke a site release"
::dZSbot::Commands::Register site !unuke ::dZSbot::Modules::Site::CmdUnnuke "Unnuke a site release"
::dZSbot::Commands::Register site !reqfilled ::dZSbot::Modules::Site::CmdReqFilled "Mark a site request filled"
::dZSbot::Commands::Register site !reqdel ::dZSbot::Modules::Site::CmdSiteReqDel "Delete a site request"
::dZSbot::Commands::Register site !incomplete ::dZSbot::Modules::Site::CmdIncomplete "Show incomplete releases"
::dZSbot::Commands::Register site !incompletes ::dZSbot::Modules::Site::CmdIncomplete "Show incomplete releases"

if {[llength [info commands ::unbind]]} {
    catch {::unbind pubm - * ::dZSbot::Modules::Site::PubmBncFallback}
}

::dZSbot::Modules::Site::Initialize

::dZSbot::ModuleManager::Register site [dict create \
    version $::dZSbot::Modules::Site::Version \
    description "Site status commands" \
    commands [::dZSbot::Commands::List site]]
