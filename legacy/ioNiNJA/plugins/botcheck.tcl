proc get_process_info_tcl9 {exeName} {
	set script {
		param([string]$exe)
		$name = [IO.Path]::GetFileNameWithoutExtension($exe)
		$process = Get-Process -Name $name -ErrorAction SilentlyContinue |
			Select-Object -First 1
		if ($null -eq $process) { exit 0 }
		$started = [DateTimeOffset]$process.StartTime
		[Console]::Out.Write("{0}`t{1}" -f \
			$process.Id, $started.ToUnixTimeSeconds())
	}
	set output [exec -- powershell.exe -NoLogo -NoProfile -NonInteractive \
		-Command "& {$script}" -exe $exeName]
	return [split $output "\t"]
}

set edf(eggdrop_name) "eggdrop.exe"

set edf(eggdrop_dir) "../eggdrop"

#eggdrop.conf filename
set edf(botscript) "eggdrop.conf"

#Userfile filename
set edf(userfile) "ioNiNjA.user"


if {![file exists $edf(eggdrop_dir)] || [file isfile $edf(eggdrop_dir)]} {
	puts "Error: $edf(eggdrop_dir) does not exist or is not a dir"
}

if {![file exists [file join $edf(eggdrop_dir) $edf(botscript)]] || ![file isfile [file join $edf(eggdrop_dir) $edf(botscript)]]} {
	puts "Error: [file join $edf(eggdrop_dir) $edf(botscript)] does not exist or is not a file"
}

cd $edf(eggdrop_dir)

file copy -f [file join $edf(eggdrop_dir) $edf(botscript)] [file join $edf(eggdrop_dir) ${edf(botscript)}.bak]


#checkrunning
	set processInfo [get_process_info_tcl9 $edf(eggdrop_name)]
	set pro [lindex $processInfo 0]
	puts $pro
	if {$pro == ""} { continue } 
	set uptime [format_duration [expr {[clock seconds] - [lindex $processInfo 1]}]]
	puts "eggdrop.exe $announce(UPTIME_EXE)"

return
