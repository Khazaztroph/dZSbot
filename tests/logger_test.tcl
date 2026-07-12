set root [file normalize [pwd]]

source [file join $root core version.tcl]
source [file join $root core logger.tcl]

::dZSbot::Logger::Initialize

::dZSbot::Logger::Info "Information"
::dZSbot::Logger::Warn "Warning"
::dZSbot::Logger::Error "Error"

::dZSbot::Logger::Debug "Invisible"

::dZSbot::Logger::DebugMode 1

::dZSbot::Logger::Debug "Visible"

puts "Info  : [::dZSbot::Logger::Counter info]"
puts "Warn  : [::dZSbot::Logger::Counter warn]"
puts "Error : [::dZSbot::Logger::Counter error]"
puts "Debug : [::dZSbot::Logger::Counter debug]"
