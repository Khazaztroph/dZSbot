###############################################################################
#
# dZSbot 2.0
#
# Module      : Database
# Description : Database core placeholder and runtime path validation.
#
###############################################################################

namespace eval ::dZSbot::Database {

    variable Initialized 0
    variable Path ""
}

namespace eval ::dZSbot::Database::MySQL {

    variable Handle ""
    variable Connected 0
    variable TLSActive 0
    variable Driver ""
}

proc ::dZSbot::Database::Initialize {{path ""}} {

    variable Initialized
    variable Path

    if {$path eq ""} {
        set path [file join $::dZSbot::Root database]
    }

    if {![file isdirectory $path]} {
        file mkdir $path
    }

    set Path $path
    set Initialized 1

    ::dZSbot::Health::Set database ok "initialized"
    return 1
}

proc ::dZSbot::Database::Path {} {

    variable Path
    return $Path
}

proc ::dZSbot::Database::Initialized {} {

    variable Initialized
    return $Initialized
}

proc ::dZSbot::Database::MySQL::Enabled {} {

    return [::dZSbot::Config::Get database.mysql.enabled 0]
}

proc ::dZSbot::Database::MySQL::Connected {} {

    variable Connected
    return $Connected
}

proc ::dZSbot::Database::MySQL::Handle {} {

    variable Handle
    return $Handle
}

proc ::dZSbot::Database::MySQL::Connect {} {

    variable Handle
    variable Connected
    variable TLSActive
    variable Driver

    if {$Connected && $Handle ne ""} {
        return 1
    }

    if {![Enabled]} {
        return 0
    }

    set errors {}
    if {[catch {ConnectWithTdbc} error]} {
        lappend errors "tdbc::mysql: $error"
        if {[catch {ConnectWithMysqltcl} error]} {
            lappend errors "mysqltcl: $error"
        } else {
            set errors {}
        }
    }

    if {[llength $errors]} {
        set Connected 0
        set Handle ""
        set Driver ""
        set TLSActive 0
        set error [join $errors {; }]
        ::dZSbot::Health::Set database:mysql error $error
        ::dZSbot::Logger::Error "MySQL connect failed: $error"
        return 0
    }

    set Connected 1

    set TLSActive [DetectTLS]
    if {[TLSRequired] && !$TLSActive} {
        ::dZSbot::Health::Set database:mysql error "TLS required but not active"
        ::dZSbot::Logger::Error "MySQL TLS is required but the connection is not encrypted."
        Disconnect
        return 0
    }

    set message "connected"
    if {$TLSActive} {
        set message "connected with TLS"
    }

    ::dZSbot::Health::Set database:mysql ok $message
    return 1
}

proc ::dZSbot::Database::MySQL::ConnectWithMysqltcl {} {

    variable Handle
    variable Driver

    package require mysqltcl
    set Handle [mysqlconnect {*}[ConnectionArgs]]
    set Driver mysqltcl
    return 1
}

proc ::dZSbot::Database::MySQL::ConnectWithTdbc {} {

    variable Handle
    variable Driver

    package require tdbc::mysql

    set objectName ::dZSbot::Database::MySQL::TdbcConnection
    catch {$objectName close}
    set Handle [::tdbc::mysql::connection create $objectName {*}[TdbcConnectionArgs]]
    set Driver tdbc::mysql
    return 1
}

proc ::dZSbot::Database::MySQL::ConnectionArgs {} {

    set args [list \
        -host [::dZSbot::Config::Get database.mysql.host "127.0.0.1"] \
        -port [::dZSbot::Config::Get database.mysql.port 3306] \
        -user [::dZSbot::Config::Get database.mysql.user "dzsbot"] \
        -password [::dZSbot::Config::Get database.mysql.password ""] \
        -db [::dZSbot::Config::Get database.mysql.database "dzsbot"]]

    foreach {configKey optionName} {
        database.mysql.ssl.ca -sslca
        database.mysql.ssl.cert -sslcert
        database.mysql.ssl.key -sslkey
    } {
        set value [::dZSbot::Config::Get $configKey ""]
        if {$value ne ""} {
            lappend args $optionName $value
        }
    }

    foreach {configKey optionName} {
        database.mysql.ssl.capath -sslcapath
        database.mysql.ssl.cipher -sslcipher
    } {
        set value [::dZSbot::Config::Get $configKey ""]
        if {$value ne ""} {
            lappend args $optionName $value
        }
    }

    set extraOptions [::dZSbot::Config::Get database.mysql.extra_options {}]
    if {[llength $extraOptions]} {
        set args [concat $args $extraOptions]
    }

    return $args
}

proc ::dZSbot::Database::MySQL::TdbcConnectionArgs {} {

    set args [list \
        -host [::dZSbot::Config::Get database.mysql.host "127.0.0.1"] \
        -port [::dZSbot::Config::Get database.mysql.port 3306] \
        -user [::dZSbot::Config::Get database.mysql.user "dzsbot"] \
        -password [::dZSbot::Config::Get database.mysql.password ""] \
        -database [::dZSbot::Config::Get database.mysql.database "dzsbot"]]

    foreach {configKey optionName} {
        database.mysql.ssl.ca -ssl_ca
        database.mysql.ssl.cert -ssl_cert
        database.mysql.ssl.key -ssl_key
        database.mysql.ssl.capath -ssl_capath
        database.mysql.ssl.cipher -ssl_cipher
    } {
        set value [::dZSbot::Config::Get $configKey ""]
        if {$value ne ""} {
            lappend args $optionName $value
        }
    }

    set extraOptions [::dZSbot::Config::Get database.mysql.extra_options {}]
    if {[llength $extraOptions]} {
        set args [concat $args $extraOptions]
    }

    return $args
}

proc ::dZSbot::Database::MySQL::TLSRequired {} {

    return [::dZSbot::Config::Get database.mysql.ssl.required 0]
}

proc ::dZSbot::Database::MySQL::TLSActive {} {

    variable TLSActive
    return $TLSActive
}

proc ::dZSbot::Database::MySQL::DetectTLS {} {

    variable Handle

    set cipher [SelectFlat "SHOW STATUS LIKE 'Ssl_cipher'"]
    if {[llength $cipher] >= 2 && [lindex $cipher 1] ne ""} {
        return 1
    }

    set version [SelectFlat "SHOW STATUS LIKE 'Ssl_version'"]
    if {[llength $version] >= 2 && [lindex $version 1] ne ""} {
        return 1
    }

    return 0
}

proc ::dZSbot::Database::MySQL::Disconnect {} {

    variable Handle
    variable Connected
    variable Driver

    if {$Handle ne ""} {
        if {$Driver eq "tdbc::mysql"} {
            catch {$Handle close}
        } else {
            catch {mysqlclose $Handle}
        }
    }

    set Handle ""
    set Connected 0
    set Driver ""
    set ::dZSbot::Database::MySQL::TLSActive 0
}

proc ::dZSbot::Database::MySQL::Escape {value} {

    variable Driver

    if {[Connect] && [llength [info commands ::mysqlescape]]} {
        return [mysqlescape $value]
    }

    return [string map [list "\\" "\\\\" "'" "\\'"] $value]
}

proc ::dZSbot::Database::MySQL::Exec {sql} {

    variable Handle
    variable Driver

    if {![Connect]} {
        return 0
    }

    if {$Driver eq "tdbc::mysql"} {
        set command [list TdbcExec $sql]
    } else {
        set command [list mysqlexec $Handle $sql]
    }

    if {[catch $command error]} {
        ::dZSbot::Health::Set database:mysql error $error
        ::dZSbot::Logger::Error "MySQL exec failed: $error"
        return 0
    }

    return 1
}

proc ::dZSbot::Database::MySQL::TdbcExec {sql} {

    variable Handle

    if {![catch {info object methods $Handle -all} methods] && [lsearch -exact $methods evaldirect] >= 0} {
        $Handle evaldirect $sql
        return 1
    }

    set statement [$Handle prepare $sql]
    if {[catch {set resultSet [$statement execute]} error options]} {
        catch {$statement close}
        return -options $options $error
    }

    catch {$resultSet close}
    catch {$statement close}
    return 1
}

proc ::dZSbot::Database::MySQL::SelectFlat {sql} {

    variable Handle
    variable Driver

    if {![Connect]} {
        return {}
    }

    if {$Driver eq "tdbc::mysql"} {
        set command [list TdbcSelectFlat $sql]
    } else {
        set command [list mysqlsel $Handle $sql -flatlist]
    }

    if {[catch $command rows]} {
        ::dZSbot::Health::Set database:mysql error $rows
        ::dZSbot::Logger::Error "MySQL query failed: $rows"
        return {}
    }

    return $rows
}

proc ::dZSbot::Database::MySQL::TdbcSelectFlat {sql} {

    variable Handle

    set flat {}
    foreach row [$Handle allrows -as lists $sql] {
        foreach value $row {
            lappend flat $value
        }
    }

    return $flat
}

proc ::dZSbot::Database::MySQL::SelectRows {sql columns} {

    set flat [SelectFlat $sql]
    set rows {}
    set width [llength $columns]

    if {$width == 0} {
        return $rows
    }

    foreach values [Chunk $flat $width] {
        set row {}
        for {set i 0} {$i < $width} {incr i} {
            dict set row [lindex $columns $i] [lindex $values $i]
        }
        lappend rows $row
    }

    return $rows
}

proc ::dZSbot::Database::MySQL::Chunk {values width} {

    set chunks {}
    set count [llength $values]

    for {set index 0} {$index < $count} {incr index $width} {
        lappend chunks [lrange $values $index [expr {$index + $width - 1}]]
    }

    return $chunks
}
