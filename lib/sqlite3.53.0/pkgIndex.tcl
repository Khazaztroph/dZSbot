# -*- tcl -*-
# Tcl package index file, version 1.1
#
# Note sqlite*3* init specifically
#
if {[package vsatisfies [package provide Tcl] 9.0-]} {
    if {![file exists [file join $dir cygtcl9sqlite3.53.0.dll]]} {
        return
    }
    package ifneeded sqlite3 3.53.0 \
	    [list load [file join $dir cygtcl9sqlite3.53.0.dll] Sqlite3]
} else {
    if {![file exists [file join $dir libsqlite3.53.0.dll]]} {
        return
    }
    package ifneeded sqlite3 3.53.0 \
	    [list load [file join $dir libsqlite3.53.0.dll] Sqlite3]
}
