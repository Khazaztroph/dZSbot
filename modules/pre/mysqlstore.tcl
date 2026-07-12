namespace eval ::dZSbot::Modules::Pre::MySQLStore {

    variable Fields {id section relname u_name g_name nukereason pretime predate preage size files}
    variable SchemaReady 0
}

proc ::dZSbot::Modules::Pre::MySQLStore::Table {} {

    return [::dZSbot::Config::Get pre.mysql.table "predb"]
}

proc ::dZSbot::Modules::Pre::MySQLStore::QuoteName {name} {

    return "`[string map [list "`" "``"] $name]`"
}

proc ::dZSbot::Modules::Pre::MySQLStore::Ensure {} {

    variable SchemaReady

    if {![::dZSbot::Database::MySQL::Connect]} {
        return 0
    }

    if {$SchemaReady} {
        return 1
    }

    set table [QuoteName [Table]]
    set sql "
CREATE TABLE IF NOT EXISTS $table (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `section` varchar(32) NOT NULL DEFAULT '',
  `relname` varchar(255) NOT NULL DEFAULT '',
  `u_name` varchar(255) NOT NULL DEFAULT '',
  `g_name` varchar(255) NOT NULL DEFAULT '',
  `nukereason` text NULL,
  `pretime` bigint NOT NULL DEFAULT 0,
  `predate` int NOT NULL DEFAULT 0,
  `preage` bigint NOT NULL DEFAULT 0,
  `size` bigint unsigned DEFAULT NULL,
  `files` int unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_relname` (`relname`),
  KEY `idx_g_name` (`g_name`),
  KEY `idx_pretime` (`pretime`),
  KEY `idx_preage` (`preage`),
  KEY `idx_section` (`section`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"

    if {![::dZSbot::Database::MySQL::Exec $sql]} {
        return 0
    }

    if {!$SchemaReady && [::dZSbot::Config::Get pre.mysql.auto_upgrade_schema 0]} {
        if {![EnsureColumns]} {
            return 0
        }
    }

    set SchemaReady 1
    ::dZSbot::Health::Set "database:mysql:[Table]" ok "ready"
    return 1
}

proc ::dZSbot::Modules::Pre::MySQLStore::ColumnExists {column} {

    set table [Table]
    set sql "SHOW COLUMNS FROM [QuoteName $table] LIKE [SqlString $column]"
    return [expr {[llength [::dZSbot::Database::MySQL::SelectFlat $sql]] > 0}]
}

proc ::dZSbot::Modules::Pre::MySQLStore::EnsureColumns {} {

    set table [QuoteName [Table]]
    set columns {
        id "`id` bigint unsigned NOT NULL AUTO_INCREMENT"
        section "`section` varchar(32) NOT NULL DEFAULT ''"
        relname "`relname` varchar(255) NOT NULL DEFAULT ''"
        u_name "`u_name` varchar(255) NOT NULL DEFAULT ''"
        g_name "`g_name` varchar(255) NOT NULL DEFAULT ''"
        nukereason "`nukereason` text NULL"
        pretime "`pretime` bigint NOT NULL DEFAULT 0"
        predate "`predate` int NOT NULL DEFAULT 0"
        preage "`preage` bigint NOT NULL DEFAULT 0"
        size "`size` bigint unsigned DEFAULT NULL"
        files "`files` int unsigned DEFAULT NULL"
    }

    foreach {name definition} $columns {
        if {![ColumnExists $name]} {
            if {![::dZSbot::Database::MySQL::Exec "ALTER TABLE $table ADD COLUMN $definition"]} {
                ::dZSbot::Logger::Error "PRE MySQL schema missing required column '$name'."
                return 0
            }
        }
    }

    foreach {name definition} $columns {
        set sql "ALTER TABLE $table MODIFY COLUMN $definition"
        if {![::dZSbot::Database::MySQL::Exec $sql]} {
            ::dZSbot::Logger::Error "PRE MySQL schema upgrade failed for column '$name'."
            return 0
        }
    }

    return 1
}

proc ::dZSbot::Modules::Pre::MySQLStore::SqlString {value} {

    if {$value eq ""} {
        return "''"
    }

    return "'[::dZSbot::Database::MySQL::Escape $value]'"
}

proc ::dZSbot::Modules::Pre::MySQLStore::SqlNumber {value {default 0}} {

    if {$value eq ""} {
        return $default
    }

    if {[string is integer -strict $value] || [string is double -strict $value]} {
        return [expr {$value}]
    }

    return $default
}

proc ::dZSbot::Modules::Pre::MySQLStore::Add {entry} {

    if {![Ensure]} {
        ::dZSbot::Logger::Warn "PRE MySQL unavailable while adding '[dict get $entry relname]'."
        return [FallbackAdd $entry]
    }

    set now [clock seconds]
    if {![dict exists $entry pretime] || [dict get $entry pretime] eq ""} {
        dict set entry pretime $now
    }
    if {![dict exists $entry predate] || [dict get $entry predate] eq ""} {
        dict set entry predate [clock format [dict get $entry pretime] -format {%Y%m%d}]
    }
    if {![dict exists $entry preage] || [dict get $entry preage] eq ""} {
        dict set entry preage 0
    }

    set table [QuoteName [Table]]
    set sql [format {
INSERT INTO %s (`section`, `relname`, `u_name`, `g_name`, `nukereason`, `pretime`, `predate`, `preage`, `size`, `files`)
VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
} \
        $table \
        [SqlString [dict get $entry section]] \
        [SqlString [dict get $entry relname]] \
        [SqlString [dict get $entry u_name]] \
        [SqlString [dict get $entry g_name]] \
        [SqlString [dict get $entry nukereason]] \
        [SqlNumber [dict get $entry pretime]] \
        [SqlNumber [dict get $entry predate]] \
        [SqlNumber [dict get $entry preage]] \
        [SqlNumber [dict get $entry size] "NULL"] \
        [SqlNumber [dict get $entry files] "NULL"]]

    if {![::dZSbot::Database::MySQL::Exec $sql]} {
        ::dZSbot::Logger::Warn "PRE MySQL insert failed for '[dict get $entry relname]'."
        return [FallbackAdd $entry]
    }

    return $entry
}

proc ::dZSbot::Modules::Pre::MySQLStore::FallbackAdd {entry} {

    if {[::dZSbot::Config::Get pre.mysql.fallback_to_tsv 1]} {
        ::dZSbot::Logger::Warn "PRE falling back to TSV storage."
        return [::dZSbot::Modules::Pre::Store::Add $entry]
    }

    error "PRE MySQL storage failed and TSV fallback is disabled"
}

proc ::dZSbot::Modules::Pre::MySQLStore::Search {query {limit 10}} {

    variable Fields

    if {![Ensure]} {
        return [::dZSbot::Modules::Pre::Store::Search $query $limit]
    }

    set table [QuoteName [Table]]
    set limit [SqlNumber $limit 10]
    set where ""

    if {[string trim $query] ne ""} {
        set escaped [::dZSbot::Database::MySQL::Escape "%[string trim $query]%"]
        set where "WHERE `relname` LIKE '$escaped'"
    }

    set sql "SELECT `id`, `section`, `relname`, `u_name`, `g_name`, `nukereason`, `pretime`, `predate`, `preage`, `size`, `files` FROM $table $where ORDER BY `pretime` DESC, `id` DESC LIMIT $limit"

    return [::dZSbot::Database::MySQL::SelectRows $sql $Fields]
}
