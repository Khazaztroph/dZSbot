###############################################################################
#
# dZSbot 2.0
#
# Module      : Version
# Description : Core version information
#
# Inspired by ioNiNJA - Built for today.
#
###############################################################################

namespace eval ::dZSbot {

    variable Name         "dZSbot"
    variable Version      "2.0.7"
    variable Build        "20260727"

    variable TclRequired  "8.6"
    variable EggRequired  "1.10"

    #
    # Return version string.
    #
    proc VersionString {} {

        variable Name
        variable Version
        variable Build

        return "${Name} ${Version} (Build ${Build})"
    }
}
