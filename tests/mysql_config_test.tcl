set root [file normalize [pwd]]

source [file join $root dZSbot.tcl]

::dZSbot::Config::Set database.mysql.host "db.example.test"
::dZSbot::Config::Set database.mysql.port 3307
::dZSbot::Config::Set database.mysql.user "tester"
::dZSbot::Config::Set database.mysql.password "secret"
::dZSbot::Config::Set database.mysql.database "dzsbot_test"
::dZSbot::Config::Set database.mysql.ssl.required 1
::dZSbot::Config::Set database.mysql.ssl.ca "/path/to/ca.pem"
::dZSbot::Config::Set database.mysql.ssl.cert "/path/to/client-cert.pem"
::dZSbot::Config::Set database.mysql.ssl.key "/path/to/client-key.pem"
::dZSbot::Config::Set database.mysql.ssl.cipher "TLS_AES_256_GCM_SHA384"
::dZSbot::Config::Set database.mysql.extra_options [list -compress 1]

puts [::dZSbot::Database::MySQL::ConnectionArgs]
puts [::dZSbot::Database::MySQL::TdbcConnectionArgs]
puts "TLS required: [::dZSbot::Database::MySQL::TLSRequired]"
