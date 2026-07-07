set root [file normalize [pwd]]

set ::auto_path [linsert $::auto_path 0 [file join $root lib]]
foreach localLib [glob -nocomplain -type d [file join $root lib *]] {
    set ::auto_path [linsert $::auto_path 0 $localLib]
}

source [file join $root core version.tcl]
source [file join $root core logger.tcl]
source [file join $root core packages.tcl]

::dZSbot::Logger::Initialize
::dZSbot::Packages::CheckTcl

foreach packageName {http json tls base64 sha1 oauth sqlite3 tdbc tdbc::mysql} {
    set loaded [::dZSbot::Packages::Require $packageName]
    puts "$packageName $loaded"
}

namespace eval ::http {
    variable urlTypes
}

::dZSbot::Packages::EnsureHttps
set httpsHandler [lindex $::http::urlTypes(https) 1]
if {[lindex $httpsHandler 0] ne "::dZSbot::Packages::HttpsSocket"} {
    error "Expected dZSbot HTTPS socket wrapper"
}

puts "Loaded packages: [::dZSbot::Packages::Loaded]"
