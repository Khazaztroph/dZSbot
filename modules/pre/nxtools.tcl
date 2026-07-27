namespace eval ::dZSbot::Modules::Pre::NxTools {}

proc ::dZSbot::Modules::Pre::NxTools::CandidatePaths {path} {
    set candidates [list $path]

    if {[regexp {^([A-Za-z]):[\\/](.*)$} $path -> drive rest]} {
        set drive [string tolower $drive]
        set rest [string map [list "\\" "/"] $rest]
        lappend candidates "/cygdrive/$drive/$rest"
    }

    set normalized {}
    foreach candidate $candidates {
        if {[catch {file normalize $candidate} normal] == 0} {
            lappend normalized $normal
        }
    }

    set result {}
    foreach candidate [concat $candidates $normalized] {
        if {$candidate ne "" && [lsearch -exact $result $candidate] < 0} {
            lappend result $candidate
        }
    }
    return $result
}

proc ::dZSbot::Modules::Pre::NxTools::OpenPresDb {dbName path} {
    set errors {}

    foreach candidate [::dZSbot::Modules::Pre::NxTools::CandidatePaths $path] {
        if {![file exists $candidate]} {
            lappend errors "$candidate: not found"
            continue
        }

        set snapshot [file join $::dZSbot::Root runtime nxtools-pres-import.db]
        if {[catch {file mkdir [file dirname $snapshot]} error]} {
            lappend errors "$snapshot: unable to create runtime directory: $error"
        } elseif {[catch {file copy -force $candidate $snapshot} error]} {
            lappend errors "$candidate: snapshot failed: $error"
        } elseif {[catch {sqlite3 $dbName $snapshot} error]} {
            lappend errors "$snapshot: open failed: $error"
        } else {
            return [dict create ok 1 path $candidate snapshot $snapshot errors $errors]
        }

        catch {$dbName close}
        if {[catch {sqlite3 $dbName $candidate} error]} {
            lappend errors "$candidate: direct open failed: $error"
        } else {
            return [dict create ok 1 path $candidate snapshot "" errors $errors]
        }
    }

    return [dict create ok 0 path $path error "unable to open nxTools Pres.db: [join $errors {; }]"]
}

proc ::dZSbot::Modules::Pre::NxTools::ImportPres {{path ""} {limit ""}} {

    if {$path eq ""} {
        set path [::dZSbot::Config::Get pre.import.nxtools.path "C:/ioFTPD/scripts/nxTools/data/Pres.db"]
    }
    if {$limit eq ""} {
        set limit [::dZSbot::Config::Get pre.import.nxtools.limit 0]
    }

    if {[catch {package require sqlite3} error]} {
        return [dict create ok 0 imported 0 skipped 0 failed 0 error "sqlite3 package is required for nxTools import: $error"]
    }

    set dbName ::dZSbot::Modules::Pre::NxTools::PresDb
    catch {$dbName close}

    set opened [::dZSbot::Modules::Pre::NxTools::OpenPresDb $dbName $path]
    if {![dict get $opened ok]} {
        return [dict create ok 0 imported 0 skipped 0 failed 0 error [dict get $opened error]]
    }

    ::dZSbot::Logger::Info "PRE import opened nxTools database: [dict get $opened path]"

    set imported 0
    set skipped 0
    set failed 0
    set seen {}
    set sql "SELECT TimeStamp, UserName, GroupName, Area, Release, Files, Size FROM Pres ORDER BY TimeStamp ASC"
    if {[string is integer -strict $limit] && $limit > 0} {
        append sql " LIMIT $limit"
    }

    if {[catch {
        $dbName eval $sql row {
            set release $row(Release)
            if {$release eq ""} {
                incr skipped
                continue
            }

            set releaseKey [string tolower [string trim $release]]
            if {[dict exists $seen $releaseKey]} {
                incr skipped
                continue
            }
            dict set seen $releaseKey 1

            if {[catch {
                set known [::dZSbot::Modules::Pre::Store::Exists $release]
            } knownError]} {
                ::dZSbot::Logger::Warn "PRE import duplicate check failed for '$release': $knownError"
                incr failed
                continue
            }
            if {$known} {
                incr skipped
                continue
            }

            set entry [dict create \
                section [string toupper $row(Area)] \
                relname $release \
                u_name $row(UserName) \
                g_name $row(GroupName) \
                nukereason "" \
                pretime $row(TimeStamp) \
                predate [clock format $row(TimeStamp) -format {%Y%m%d}] \
                preage 0 \
                size $row(Size) \
                files $row(Files)]

            if {[catch {::dZSbot::Modules::Pre::Store::AddEntry $entry} addError]} {
                ::dZSbot::Logger::Warn "PRE import insert failed for '$release': $addError"
                incr failed
            } else {
                incr imported
            }
        }
    } error]} {
        catch {$dbName close}
        return [dict create ok 0 imported $imported skipped $skipped failed $failed error $error]
    }

    catch {$dbName close}
    ::dZSbot::Logger::Info "PRE import finished: $imported imported, $skipped skipped, $failed failed."
    return [dict create ok 1 imported $imported skipped $skipped failed $failed error "" path [dict get $opened path] snapshot [dict get $opened snapshot]]
}
