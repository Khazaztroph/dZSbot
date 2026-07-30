###############################################################################
#
# dZSbot 2.0
#
# Adapter     : FluxFTP
# Description : HTTP API adapter scaffold for FluxFTP.
#
###############################################################################

namespace eval ::dZSbot::Adapter::FluxFTP {

    variable Version "0.1.0"
    variable HttpGetCommand ""
}

proc ::dZSbot::Adapter::FluxFTP::Enabled {} {
    return [::dZSbot::Config::Get fluxftp.enabled 0]
}

proc ::dZSbot::Adapter::FluxFTP::BaseUrl {} {
    return [string trimright [::dZSbot::Config::Get fluxftp.base_url "http://127.0.0.1:port/api"] "/"]
}

proc ::dZSbot::Adapter::FluxFTP::Endpoint {name defaultPath} {
    return [::dZSbot::Config::Get "fluxftp.endpoint.$name" $defaultPath]
}

proc ::dZSbot::Adapter::FluxFTP::Url {path {params {}}} {
    if {[regexp {^https?://} $path]} {
        set url $path
    } else {
        set url "[BaseUrl]/[string trimleft $path /]"
    }

    if {[llength $params]} {
        EnsureHttp
        append url ? [::http::formatQuery {*}$params]
    }

    return $url
}

proc ::dZSbot::Adapter::FluxFTP::EnsureHttp {} {
    package require http
}

proc ::dZSbot::Adapter::FluxFTP::Headers {} {
    set headers [list Accept application/json User-Agent [::dZSbot::Config::Get fluxftp.user_agent "dZSbot/2.0 FluxFTPAdapter"]]
    set apiKey [::dZSbot::Config::Get fluxftp.api_key ""]
    set authHeader [::dZSbot::Config::Get fluxftp.auth_header "Authorization"]
    set authScheme [::dZSbot::Config::Get fluxftp.auth_scheme "Bearer"]

    if {[string trim $apiKey] ne ""} {
        if {$authScheme eq ""} {
            lappend headers $authHeader $apiKey
        } else {
            lappend headers $authHeader "$authScheme $apiKey"
        }
    }

    return $headers
}

proc ::dZSbot::Adapter::FluxFTP::GetJson {path {params {}}} {
    if {![Enabled]} {
        return [dict create ok 0 code 0 error "FluxFTP adapter is disabled" data {}]
    }

    variable HttpGetCommand
    set url [Url $path $params]

    if {$HttpGetCommand ne ""} {
        return [{*}$HttpGetCommand $url [Headers]]
    }

    if {[catch {
        package require http
        package require json
        set token [::http::geturl $url -timeout [::dZSbot::Config::Get fluxftp.timeout_ms 5000] -headers [Headers]]
        set status [::http::status $token]
        set code [::http::ncode $token]
        set body [::http::data $token]
        ::http::cleanup $token
    } error]} {
        catch {::http::cleanup $token}
        return [dict create ok 0 code 0 error $error data {}]
    }

    if {$status ne "ok" || $code < 200 || $code >= 300} {
        return [dict create ok 0 code $code error "HTTP $code ($status)" data $body]
    }

    if {[catch {set parsed [::json::json2dict $body]} error]} {
        return [dict create ok 0 code $code error "invalid JSON: $error" data $body]
    }

    return [dict create ok 1 code $code error "" data $parsed]
}

proc ::dZSbot::Adapter::FluxFTP::Health {} {
    set response [GetJson [Endpoint health "health"]]
    if {![dict get $response ok]} {
        return [dict create ok 0 adapter fluxftp status error error [dict get $response error]]
    }

    set data [dict get $response data]
    return [dict create ok 1 adapter fluxftp status [DictGet $data status ok] version [DictGet $data version ""] raw $data]
}

proc ::dZSbot::Adapter::FluxFTP::Bandwidth {} {
    set response [GetJson [Endpoint bandwidth "transfers"]]
    if {![dict get $response ok]} {
        return [dict create ok 0 adapter fluxftp error [dict get $response error] transfers {}]
    }

    set transfers [NormalizeTransferList [Items [dict get $response data] {transfers bandwidth items data}]]
    set summary [SummarizeTransfers $transfers]
    dict set summary ok 1
    dict set summary adapter fluxftp
    dict set summary transfers $transfers
    return $summary
}

proc ::dZSbot::Adapter::FluxFTP::DiskFree {} {
    set response [GetJson [Endpoint diskfree "sections"]]
    if {![dict get $response ok]} {
        return [dict create ok 0 adapter fluxftp error [dict get $response error] sections {}]
    }

    return [dict create \
        ok 1 \
        adapter fluxftp \
        sections [NormalizeDiskFreeList [Items [dict get $response data] {sections diskfree drives items data}]]]
}

proc ::dZSbot::Adapter::FluxFTP::Users {} {
    set response [GetJson [Endpoint users "users"]]
    if {![dict get $response ok]} {
        return [dict create ok 0 adapter fluxftp error [dict get $response error] users {}]
    }

    return [dict create \
        ok 1 \
        adapter fluxftp \
        users [NormalizeUserList [Items [dict get $response data] {users items data}]]]
}

proc ::dZSbot::Adapter::FluxFTP::RecentUploads {} {
    set response [GetJson [Endpoint recent_uploads "uploads/recent"]]
    if {![dict get $response ok]} {
        return [dict create ok 0 adapter fluxftp error [dict get $response error] uploads {}]
    }

    return [dict create \
        ok 1 \
        adapter fluxftp \
        uploads [NormalizeUploadList [Items [dict get $response data] {uploads recent items data}]]]
}

proc ::dZSbot::Adapter::FluxFTP::PreSearch {query {limit 5}} {
    set response [GetJson [Endpoint pre_search "pre"] [list query $query limit $limit]]
    if {![dict get $response ok]} {
        return [dict create ok 0 adapter fluxftp error [dict get $response error] releases {}]
    }

    return [dict create \
        ok 1 \
        adapter fluxftp \
        releases [NormalizePreList [Items [dict get $response data] {releases pre items data}]]]
}

proc ::dZSbot::Adapter::FluxFTP::Items {data keys} {
    if {[IsDict $data]} {
        foreach key $keys {
            if {[dict exists $data $key]} {
                return [dict get $data $key]
            }
        }
    }

    return $data
}

proc ::dZSbot::Adapter::FluxFTP::NormalizeTransferList {items} {
    set result {}
    foreach item [AsList $items] {
        if {![IsDict $item]} {
            continue
        }

        lappend result [dict create \
            direction [NormalizeDirection [FirstValue $item {direction type status mode} "unknown"]] \
            user [FirstValue $item {user username account} ""] \
            group [FirstValue $item {group user_group} ""] \
            speed_kbps [Number [FirstValue $item {speed_kbps speed kbps transfer_speed transferSpeed} 0]] \
            path [FirstValue $item {path virtual_path virtualPath vpath file} ""] \
            raw $item]
    }

    return $result
}

proc ::dZSbot::Adapter::FluxFTP::SummarizeTransfers {transfers} {
    set uploadCount 0
    set downloadCount 0
    set idleCount 0
    set uploadSpeed 0.0
    set downloadSpeed 0.0

    foreach transfer $transfers {
        set direction [dict get $transfer direction]
        set speed [dict get $transfer speed_kbps]

        if {$direction eq "upload"} {
            incr uploadCount
            set uploadSpeed [expr {$uploadSpeed + $speed}]
        } elseif {$direction eq "download"} {
            incr downloadCount
            set downloadSpeed [expr {$downloadSpeed + $speed}]
        } else {
            incr idleCount
        }
    }

    return [dict create upload_count $uploadCount download_count $downloadCount idle_count $idleCount upload_speed_kbps $uploadSpeed download_speed_kbps $downloadSpeed total_speed_kbps [expr {$uploadSpeed + $downloadSpeed}]]
}

proc ::dZSbot::Adapter::FluxFTP::NormalizeDiskFreeList {items} {
    set result {}
    foreach item [AsList $items] {
        if {![IsDict $item]} {
            continue
        }

        lappend result [dict create \
            name [string toupper [FirstValue $item {name section path} "UNKNOWN"]] \
            path [FirstValue $item {path mount root} ""] \
            free_mb [Number [FirstValue $item {free_mb freeMB free available_mb available} 0]] \
            used_mb [Number [FirstValue $item {used_mb usedMB used} 0]] \
            total_mb [Number [FirstValue $item {total_mb totalMB total size_mb size} 0]] \
            raw $item]
    }

    return $result
}

proc ::dZSbot::Adapter::FluxFTP::NormalizeUserList {items} {
    set result {}
    foreach item [AsList $items] {
        if {![IsDict $item]} {
            continue
        }

        lappend result [dict create user [FirstValue $item {user username name} ""] group [FirstValue $item {group primary_group} ""] status [FirstValue $item {status state} "unknown"] path [FirstValue $item {path cwd virtual_path} ""] raw $item]
    }

    return $result
}

proc ::dZSbot::Adapter::FluxFTP::NormalizeUploadList {items} {
    set result {}
    foreach item [AsList $items] {
        if {![IsDict $item]} {
            continue
        }

        set release [FirstValue $item {release name relname} ""]
        lappend result [dict create \
            adapter fluxftp \
            source FluxFTP \
            release $release \
            relname $release \
            section [string toupper [FirstValue $item {section area category} "UNKNOWN"]] \
            path [FirstValue $item {path virtual_path} ""] \
            user [FirstValue $item {user username} ""] \
            group [FirstValue $item {group user_group} ""] \
            files [FirstValue $item {files file_count} ""] \
            size [FirstValue $item {size size_kb sizeKB} ""] \
            raw $item]
    }

    return $result
}

proc ::dZSbot::Adapter::FluxFTP::NormalizePreList {items} {
    set result {}
    foreach item [NormalizeUploadList $items] {
        dict set item source FluxFTP-PRE
        lappend result $item
    }

    return $result
}

proc ::dZSbot::Adapter::FluxFTP::NormalizeDirection {value} {
    set text [string tolower [string trim $value]]
    if {$text in {up upload uploading stor 2}} {
        return upload
    }
    if {$text in {dn down download downloading retr fxp 1}} {
        return download
    }
    if {$text in {idle none 0 3}} {
        return idle
    }

    return unknown
}

proc ::dZSbot::Adapter::FluxFTP::FirstValue {dictValue keys default} {
    foreach key $keys {
        if {[dict exists $dictValue $key]} {
            set value [dict get $dictValue $key]
            if {$value ne ""} {
                return $value
            }
        }
    }

    return $default
}

proc ::dZSbot::Adapter::FluxFTP::DictGet {dictValue key default} {
    if {[IsDict $dictValue] && [dict exists $dictValue $key]} {
        return [dict get $dictValue $key]
    }

    return $default
}

proc ::dZSbot::Adapter::FluxFTP::Number {value} {
    if {[string is double -strict $value]} {
        return $value
    }

    return 0
}

proc ::dZSbot::Adapter::FluxFTP::AsList {value} {
    if {[catch {llength $value}]} {
        return {}
    }

    return $value
}

proc ::dZSbot::Adapter::FluxFTP::IsDict {value} {
    return [expr {![catch {dict size $value}]}]
}

proc ::dZSbot::Adapter::FluxFTP::SetHttpGetCommand {command} {
    variable HttpGetCommand
    set HttpGetCommand $command
}

::dZSbot::SiteAdapter::Register fluxftp [dict create \
    description "FluxFTP HTTP API adapter" \
    event_sources {api} \
    command_transports {http https} \
    namespace ::dZSbot::Adapter::FluxFTP \
    version $::dZSbot::Adapter::FluxFTP::Version]
