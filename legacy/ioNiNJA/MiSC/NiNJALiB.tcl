namespace eval ::ioNiNJA {
    variable logPath "../logs"
    namespace export *
}

interp alias {} IsTrue {} string is true -strict
interp alias {} IsFalse {} string is false -strict


if {[catch {source "../scripts/ioNiNJA/ioNiNJA.cfg"} error]} {
	putlog -error $error
	return
}

if {[catch {source "../scripts/ioNiNJA/themes/$ioNJ(themefile)"} error]} {
	putlog -error $error
	return
}
	
if {[catch {package require http 2.7.1} error]} {
	putlog -error $error
	return
}

proc ::ioNiNJA::MAKESFV {} { global path pwd ioNJ
		set paths $pwd
		set nr 0
		while {[lindex $paths $nr] != ""} {
			set sfv_filez ""
			set temp [resolve list [lindex $paths $nr]]
			foreach dir $temp {
				lassign $dir io_fname io_type io_uid io_user io_gid io_group io_fsize mode attributes win-last-time unix-last-time win-alt-time unix-alt-time subdir-count rlink chatt uptime
				if {$io_type == "d"} {
					if {$io_fname == "." || [regexp -nocase $ioNJ(makesfv_skipdirs)  $io_fname]} { continue } 
					lappend paths [file join [lindex $paths $nr] $io_fname] 
					iputs -nobuffer "250- ADDED: [file join [lindex $paths $nr] $io_fname]"
				} elseif {$io_type == "f"} {
					if {[regexp -nocase $ioNJ(makesfv_files) $io_fname]} {
						set filename "[resolve pwd [file join [lindex $paths $nr] [file tail [lindex $paths $nr]].sfv]]"
						lappend sfv_filez "$io_fname [format %08X [crc32 [resolve pwd [file join [lindex $paths $nr] $io_fname]]]]"
						iputs -nobuffer "250- SFV: $io_fname" 
					} elseif {[regexp -nocase {\.sfv$} $io_fname]} {
						iputs -nobuffer "250- SFV-del: $io_fname" 
						file delete -force [resolve pwd [file join [lindex $paths $nr] $io_fname]]
					}
				}
			}
			set sfvfile "[file tail [lindex $paths $nr]].sfv"
			if {[set nfo [get_files [resolve pwd [lindex $paths $nr]] *.nfo]] != ""} {
				set sfvfile "[file rootname [file tail $nfo]].sfv"
			} elseif {[set m3u [get_files [resolve pwd [lindex $paths $nr]] *.m3u]] != ""} {
				set sfvfile "[file rootname [file tail $m3u]].sfv"
			}
			if {$sfv_filez != ""} {
				writefile [file join [resolve pwd [lindex $paths $nr]]  $sfvfile] [join $sfv_filez \n]
			}
			incr nr
		}
}


proc ::ioNiNJA::sfv_check {sfvfile} {global pwd ioNJ path
	set sfvdata [split [string tolower  [readfile $sfvfile]] \n]
	set newsfv ""
	set m3u ""


	foreach line $sfvdata {
		if {[string index $line 0] != ";"} {
			if {[string length [lindex $line end]] == 8 && [llength $line] >= 2} {
					 if {[lsearch -glob $newsfv "[lrange $line 0 end-1] *"] == "-1"} {
				  lappend newsfv $line
					if {$ioNJ(create_missing_files)} {
						if {![regexp -nocase {\.mu3$|\.nfo$} [string trim [lrange $line 0 end-1]]]} {
							catch {set missingfile [open $path/[lrange $line 0 end-1]${ioNJ(missingtag)} w]} error
							catch {vfs write [file join $path "[lrange $line 0 end-1]${ioNJ(missingtag)}"] 0 0 744}
							catch {close $missingfile}
						}
					}
				}
				}
			} 
	}

	set mp3s [lsearch -regexp -all -inline $newsfv {[^;](.+?\.mp3) ([0-9a-z]){8}}]
	if {$mp3s == ""} {
		set mp3s [lsearch -regexp -all -inline $newsfv {[^;](.+?\.flac) ([0-9a-z]){8}}]
		set flac 1
	}

	#
	if {$ioNJ(create_m3u) && $mp3s != ""} {
		foreach mp $mp3s {
			append m3u "[lrange $mp 0 end-1]\n"
		}
		set m3uname "[file tail [file rootname $sfvfile]].m3u"
		writefile "$path/$m3uname" $m3u
	} 


	#write new sfv file without comments
	if {$ioNJ(sfv_cleanup)} {
		writefile "$sfvfile" "[join $newsfv "\n"]"
	}

	#Type of release
	if {$mp3s != ""} {
		if {[info exists flac]} {
			writechattr 12  "FLAC"
		} else {
			writechattr 12  "AUDIO"
		}
	} elseif {[regexp -nocase {\.r[a0-9][r0-9]|\.0[0-9][0-9]} $newsfv]} {
		writechattr 12  "RAR"
	} elseif {[regexp -nocase $ioNJ(samples) $newsfv]} {
		writechattr 12  "VIDEO"
	} else {
		writechattr 12 "OTHER"
	}

	symlink_proc cd 1 ; symlink_proc sfv 0

	writechattr 35 $newsfv

	writechattr 13 [llength $newsfv]
	return
}



proc ::ioNiNJA::clean_nfo {nfofile} {
	set nfo [readfile $nfofile]
	set tempnfo ""
	regsub -all "\r\n\r\n" $nfo "\r\n" nfo
	foreach line [split $nfo \n] {
	 	lappend tempnfo "[string trimright $line]"
	}
	
	set temp [writefile $nfofile [join $tempnfo \n]]
	unset nfo
	unset tempnfo
    return
}




########################
# Symlink Proc
########################


proc ::ioNiNJA::symlink_update {source} { global ioNJ pwd path

		set symtype 1
		
		
		foreach link [readchattr 240] {
		
			if {![file exists $link]} { continue }
			
			catch {vfs chattr "$link" 1} vfsdir
					
			iputs -nobuffer "250- Checking: $link"
					
			if {$vfsdir != ""} {
					set symtype 0
		    } elseif {![catch {file link $link} templink]} {
					set symtype 1
			}
	     		

			if {$symtype} {
				  catch {file delete -force -- $link}
				  catch {file mkdir "[file dirname $link]"}
				  catch {file link -symbolic "$link" "$source"} error
			} else {
				catch {file delete -force -- $link}
				catch {file mkdir "$link"}
				catch {vfs chattr "$link" 1 "$pwd"}
				catch {vfs flush "$link"}
      			}
		}
			iputs -nobuffer "250 Checked: $link"
 	return
}


proc ::ioNiNJA::symlink_clean {} {global ioNJ user uid pwd

	if {![info exists user] && ![info exists group]} {
        if {[userfile open $ioNJ(MountUser)] != 0} {
            putlog "ioNJ-ERROR: unable to open the user \"$ioNJ(MountUser)\"";
            return 1
        } elseif {[mountfile open $ioNJ(MountFile)] != 0} {
            putlog "ioNJ-ERROR: unable to mount the VFS-file \"$ioNJ(MountFile)\""
            return 1
        }
	}


  foreach cleandir [split [string trim $ioNJ(cleanup_dirs)] \n] {
 
  	set dirs [get_dirs [resolve pwd $cleandir] *]
  	set nr 0
 	while {[lindex $dirs $nr] != ""} {
		iputs -nobuffer "250- Checking: [lindex $dirs $nr]"
 	       if {![catch {file link [lindex $dirs $nr]} templink]} { incr nr ; continue }
 	    	
  	 	   foreach dir [get_dirs [lindex $dirs $nr] "*"] {
				set delete 0
				
				if {$dir == "" || ( ![file exists $dir] )} { continue }
				
				catch {vfs chattr "$dir" 1} vfsdir
				
				if {$vfsdir != ""} {
					if {![file exists [resolve pwd $vfsdir]]} {
						set delete 1			
					}
					
				} elseif {![catch {file link $dir} templink]} {
					if {![file exists $templink]} {
						set delete 1
					}
				} elseif {[llength [glob -nocomplain -directory $dir "*"]] == [llength [glob -nocomplain -directory $dir "*.jpg"]]} {
						set delete 1
				}
			
			if {$delete} {
				catch {file delete -force [file join $dir folder.jpg]}
				catch {file delete -force [file join $dir fanart.jpg]}
				catch {file delete -force -- $dir} error
				while {[glob -nocomplain -directory $dir "*"] == ""} {
				    catch {file delete -force -- $dir} error
				    set dir [file dirname $dir]
					if {[llength [glob -nocomplain -directory $dir "*"]] == [llength [glob -nocomplain -directory $dir "*.jpg"]]} {
						catch {file delete -force [file join $dir folder.jpg]}
						catch {file delete -force [file join $dir fanart.jpg]}
					}
				}
	      	} else {
				lappend dirs $dir
			}
	      		 
  	 	   }
  	     	incr nr
  	     	after 10
  	}

	
  unset -nocomplain dirs
	}
}



#######################
## Get Stats
#######################


proc ::ioNiNJA::get_stats {} {global pwd path uid gid
 set wkup "" ; set mnup "" ; set allup "" ; set dayup ""

foreach uname [user list] {
 set user1 [resolve uid $uname] 
	if {![userfile open $user1]} {
		if {![catch {set uf [userfile bin2ascii]}]} {
			regexp -nocase {wkup (.+?)\n} $uf -> userwkup
			lappend wkup "$user1 [Calculate_Stats $userwkup]"

			regexp -nocase {monthup (.+?)\n} $uf -> usermnup
			lappend mnup "$user1 [Calculate_Stats $usermnup]"

			regexp -nocase {allup (.+?)\n} $uf -> userallup
			lappend allup "$user1  [Calculate_Stats $userallup]"

			regexp -nocase {dayup (.+?)\n} $uf -> userdayup
			lappend dayup "$user1 [Calculate_Stats $userdayup]"
		} 
	 }
}

if {![userfile open [resolve uid $uid]]} {
		if {![catch {set uf [userfile bin2ascii]}]} {
		}
}

set wkup [lsort -decreasing -integer -index end "$wkup"] 
set mnup [lsort -decreasing -integer -index end "$mnup"]
set allup [lsort -decreasing -integer -index end "$allup"]
set dayup [lsort -decreasing -integer -index end "$dayup"]
return [list $dayup $wkup $mnup $allup]
}


proc ::ioNiNJA::Calculate_Stats {tempstats} {
set totalsize 0
foreach {files size speed} $tempstats {
      if {$size == 0} { continue }
      set totalsize [format %.0f [expr $totalsize + ($size /1024.0)]]
}
return $totalsize

}



#######################
## DELETE DIR 
#######################


proc ::ioNiNJA::delete_dir {delpwd delpath} {global ioNJ pwd path
symlink_proc cd 0
symlink_proc sfv 0
symlink_proc nfo 0

vfs write $delpath 0 0 744
vfs flush $delpath
set error 0
set counter 0
	while {$error != "" && ( $counter != 50) } {
		catch {set temp [client kill virtualpath "$delpwd/*"]} temp
		catch {file delete -force -- "$delpath"} error
		incr counter
		after 200
	}
return $error
}

##### MOVE DIR
proc ::ioNiNJA::move_dir {origpwd origpath movepath} {global ioNJ pwd path
vfs write $origpath 0 0 744
vfs flush $origpath
set error 0
set counter 0	
	while {$error != "" && ( $counter != 25) } {
		catch {set temp [client kill virtualpath "$origpwd*"]} temp
		catch {file mkdir "$movepath"}
		catch {file rename "$origpath/" "$movepath/"} error
		incr counter
		after 200
	}
	catch {vfs flush [file dirname $origpath]}
}



proc ::ioNiNJA::get_flac_information {flacfile} {global pwd path args ioNJ uid gid 


	if {![file exists $flacfile]} { return } 
	
	set dir [file tail [file dirname $flacfile]]
	
	if {[regexp -nocase $ioNJ(notparent) $dir]} { 
		set subdir 1
		set dir [lindex [file split $pwd] end-1] 
	}
	
	if {![info exists uid]} {
		set uid 0
		set gid 0
	}

	set fname [file tail $flacfile]
	set fd [open $flacfile r]
	set user [resolve uid $uid]
	set ugroup [resolve gid $gid]
	fconfigure $fd -translation binary -buffering full -buffersize 1000000
	
	if {[read $fd 4] != "fLaC"} { 
		close $fd
		return 
	}
	
	close $fd
	
	
	catch {exec ../scripts/ioninja/misc/media.exe --Output=XML $flacfile} metadata
	lassign {- - - - - - - - - - - - - - - - - - - -} duration bitrate album artist producer genre description recorddate writeapp ripdate retail media channels srate bitdepth language catalog riptool trackname type
	
	foreach line [split $metadata \n] {
		switch -glob [lindex $line 0] {
			<Duration>* { set duration [regsub -all {<.+?>} $line {}]}
			<Overall_bit_rate>* { set bitrate [regsub -all {<.+?>} $line {}]}
			<Album>* { set album [htmlcodes [regsub -all {<.+?>} $line {}]]}
			<Performer>* { set artist [htmlcodes [regsub -all {<.+?>} $line {}]]}
			<Producer>* { set producer [htmlcodes [regsub -all {<.+?>} $line {}]]}
			<Genre>* { set genre [htmlcodes [regsub -all {<.+?>} $line {}]]}
			<Description>* { set description [htmlcodes [regsub -all {<.+?>} $line {}]]}
			<Recorded_date>* { set recorddate [regsub -all {<.+?>} $line {}]}
			<Writing_application>* { set writeapp [regsub -all {<.+?>} $line {}]}
			<Rip_Date>* { set ripdate [regsub -all {<.+?>} $line {}]}
			<Retail_Date>* { set retail [regsub -all {<.+?>} $line {}]}
			<Media>* { set media [regsub -all {<.+?>} $line {}]}
			<Channel_s_>* { set channels [regsub -all {<.+?>} $line {}]}
			<Sampling_rate>* { set srate [regsub -all {<.+?>} $line {}]}
			<Bit_depth>* { set bitdepth [regsub -all -nocase {<.+?>} $line {}]}
			<Language>* { set language [regsub -all {<.+?>} $line {}]}
			<Catalog>* { set catalog [regsub -all {<.+?>} $line {}]}
			<Ripping_Tool>* { set riptool [regsub -all {<.+?>} $line {}]}
			<Track_name>* { set trackname [htmlcodes [regsub -all {<.+?>} $line {}]]}
			<Release_Type>* { set type [regsub -all {<.+?>} $line {}]}
		}

	}
	
	if {$retail != "-"} {
		set year $retail
		regexp -nocase {(\d\d\d\d)} $year year
	} elseif {$recorddate != "-"} {
		set year $recorddate
		regexp -nocase {(\d\d\d\d)} $year year
	}  elseif {$ripdate != "-"} {
		set year $ripdate
		regexp -nocase {(\d\d\d\d)} $year year
	} else {
		set year 0000
	}
	
	set flacinfo  [list 0 $duration $bitrate $album $year $artist $producer $genre $description $recorddate $writeapp $ripdate $retail $media $channels $srate $bitdepth $language $catalog $riptool $trackname $type]

	writechattr 26 $flacinfo
	
	   if {$metadata != ""} {
	 	if {[regexp $ioNJ(flac_path_check) $pwd] && $ioNJ(flac_path_check) != "" } { 
			#mp3 ban report or del
			if {$ioNJ(flac_audio_year_check) && ![regexp $ioNJ(flac_allowed_years) $year]} {
				if {[string match $ioNJ(flac_del_banned_release_path) $pwd] && $ioNJ(flac_del_banned_release_path) != ""} {
					output "$ioNJ(zipscript_header)$ioNJ(zipscript_mp3_del_year)$ioNJ(zipscript_footer_skip)"
					delete_dir "$pwd" "$path"
					return
				}
				if {$ioNJ(flac_audio_year_warn)} {
					put_log "BADYEAR: [list $pwd $dir $user $ugroup $fname $year]"	
				}	
			}

			#check year and take action
			if {$ioNJ(flac_audio_genre_check) == 1 && ![regexp -nocase $ioNJ(flac_allowed_genres) $genre] && $ioNJ(flac_allowed_genres) != ""} {
				if {[regexp -nocase $ioNJ(del_banned_release_path) $pwd] && $ioNJ(del_banned_release_path) != ""} {
					output "$ioNJ(zipscript_header)$ioNJ(zipscript_mp3_alo_genre)$ioNJ(zipscript_footer_skip)"
					delete_dir "$pwd" "$path"
					return
				}
				if {$ioNJ(flac_audio_genre_warn)} {
					put_log "BADGENRE: [list $pwd $dir $user $ugroup $fname $genre]"	
				}
			} elseif {$ioNJ(flac_audio_genre_check) == 2 && [regexp -nocase $ioNJ(flac_banned_genres) $genre] && $ioNJ(flac_banned_genres) != ""} {
				if {$ioNJ(flac_del_banned_release_path) != "" && [regexp -nocase $ioNJ(flac_del_banned_release_path) $pwd]} {
					output "$ioNJ(zipscript_header)$ioNJ(zipscript_mp3_ban_genre)$ioNJ(zipscript_footer_skip)"
					delete_dir "$pwd" "$path"
					return
				} 
				if {$ioNJ(flac_audio_genre_warn)} {
					put_log "BADGENRE: [list $pwd $dir $user $ugroup $fname $genre]"	
				}
			}
		}
	    }
	return $flacinfo
}

proc ::ioNiNJA::get_mp3_information {mp3file} {global ioNJ args pwd path uid gid

	if {![file exists $mp3file]} { return } 
	
	set mp3 [readchattr 25]
	
	set dir [lindex [file split $pwd] end]
	
	if {[regexp -nocase  $ioNJ(notparent) $dir]} { 
		set subdir 1
		set dir [lindex [file split $pwd] end-1] 
	}

	if {![info exists uid]} {
		set uid 0
		set gid 0
	}

	set user [resolve uid $uid]
	set ugroup [resolve gid $gid]
	set fname [file tail $mp3file]
	set lame "NA"
	set lpreset "NA"
	set vbroldnew "NA"
	set fd [open $mp3file r]
	fconfigure $fd -translation binary -buffering full -buffersize 1000000
	set idx 1
	set offset 0
	set mp3header [read $fd 10]
	seek $fd -128 end
	set id3v1 [read $fd]
	seek $fd 0

	#GET THE iD3 TAG
	binary scan $id3v1 A3 id
	if {[string equal $id TAG]} {
	         set genre 149
	         binary scan $id3v1 A3A30A30A30A4A28ccc id title artist album  year comment zero track genre
	         if {$genre == "-1"} {
	         		set genre "Unknown"
	         } elseif {$genre < 0 } {
	         		set genre [expr $genre + 256]
	         	set genre [lindex $ioNJ(genres) $genre]
	         } else {
	         	set genre [lindex $ioNJ(genres) $genre]
	         }
	         if {$genre == ""} { set genre Unknown }
	} else {
		set title "Unknown" ; set artist "Unknown" ; set album "Unknown" ; set year "0000" ; set comment "Unknown" ; set zero 0 ; set track 0 ; set genre "Unknown"
	}



	#Get THE iD3v2 TAG
	binary scan $mp3header A3B8B8B8B32 tempid3 tempversion tempsubversion flags size
	if {[string match -nocase "id3" $tempid3]} {
		binary scan $mp3header A3B8B8B8B32 tempid3 tempversion tempsubversion flags size
		set id3v2 [bin2dec $tempversion]
		if {[string index $flags 4] != 0} {
			set offset [expr [bin2dec [string range $size 1 7][string range $size 9 15][string range $size 17 23][string range $size 25 31]]+20]
		} else {
			set offset [expr [bin2dec [string range $size 1 7][string range $size 9 15][string range $size 17 23][string range $size 25 31]]+10]
		}
		seek $fd 10
		set id3v2tag [read $fd $offset]
		if {$id3v2 >= "1"} {
			 set num 0
			 if { $id3v2 >= "3" } { 
			 	set bscan A4B32
			 	set offset2 10
			 	set offset3 11
			 } elseif {$id3v2 == "2"} {
			 	set bscan A3B24
				set offset2 6
			 	set offset3 7
			 }
			 while {$id3v2tag != ""} {
					binary scan $id3v2tag $bscan ID size	
					set tempcrap [expr [bin2dec [string range $size 1 7][string range $size 9 15][string range $size 17 23][string range $size 25 31]]+$offset2]
					if {$tempcrap == $offset2} { break }
					set data [string range $id3v2tag $offset3 [expr $tempcrap-1]]
					set data [string trim [regsub -all -- {[^[:graph:] ]|ÿ|þ} $data {}]]
					switch -- $ID {
						TRCK { if {$track == ""} { set track [lindex [split $data /] 0] } }
        					COMM  { set comm [string range $data 4 end] }
        					TIT2  { set title $data }
        					TPE1  { set artist $data }
        					TALB  { set album $data }
        					MCDI  { set id3v2tag [string range $id3v2tag [expr 814 - $tempcrap] end] }
        					TYER  { if {$year == "0000" && [string is integer -strict $data] || ([string length $year] == 4)} { set year $data } }
 		       				TCON  { 
 		       					if {$genre == "Unknown"} { if {[regexp -nocase {\(([0-9]+)\)} $data -> genrenr]} { set genre [lindex $ioNJ(genres) $genrenr] } elseif {$data != ""} { set genre "$data" } } 
 		       				}
 		       				TT2  { set title $data }
						TOA  { set artist $data }
						TP1  { set artist $data }
						TRK  { if {$track == ""} { set track [lindex [split $data /] 0] } }
						CM1  { set comm [string range $data 4 end] }
						TAL  { set album $data }
		        			TYE  { if {$year == "0000" && [string is integer -strict $data] || ([string length $year] == 4)} { set year $data } }
		        			TCO  { 
						       if {$genre == "Unknown"} { if {[regexp -nocase {\(([0-9]+)\)} $data -> genrenr]} { set genre [lindex $ioNJ(genres) $genrenr] } elseif {$data != ""} { set genre "$data" } } 
 		       				}
					}
					set id3v2tag [string range $id3v2tag $tempcrap end]
					incr num
	
			}
		} 

	}	

	if {$year == "" || [string length $year] != 4} { 
		if {![regexp -nocase {([0-9]{4})} $dir -> year]} {
			set year "0000"
		}	
	}


	if {$title == ""} { set title "Unknown" }
	if {$album == ""} { set album "Unknown" }
	if {$artist == ""} { set artist "Unknown" }

	if {$ioNJ(strip_the)} { regsub -nocase {^the } $artist {} artist }
	
	regexp -nocase {(.+?) (feat|ft)} $artist -> artist crap
	
	set artist [string trim $artist]

	seek $fd $offset
	set byte1 0 ; set byte2 0 ; set byte3 0 ; set byte4 0
	while { ![eof $fd] } {
	  set head1  [read $fd 1]
	   scan $head1 %c byte1
	     if { ($byte1 & 0xFF) == 0xFF } {
	      set head2 [read $fd 1]
	       scan $head2 %c byte2
	        if { ($byte2 & 0xE0) == 0xE0 } {
		 set head3 [read $fd 2]
	          scan $head3 %c%c byte3 byte4
	            if { ([expr {($byte2 >> 3) & 0x3}] != 0x1) && ([expr {($byte2 >> 1) & 0x3}] != 0x0) && ((($byte3 >> 2) & 0x3) != 0x3) && ((($byte3 >> 4) & 0xF)  != 0xf)} {
			set mpeghead "$head1$head2$head3"
			break
	           }
	        }
	    }
	}
	if {![info exists mpeghead]} { close $fd ; putlog -error "$mp3file does not contain a mpeghead" ; return }
	binary scan $mpeghead B32 mp3head
	set Framesync [string range $mp3head 0 10] 
	set MPEGAudioversion [string range $mp3head 11 12] 
	set Layerdescription [string range $mp3head 13 14]
	set Protection [string index $mp3head 15]
	set Bitrate [string range $mp3head 16 19]
	set Samplingrate [string range $mp3head 20 21]
	set Padding [string index $mp3head 22]
	set Private  [string index $mp3head 23]
	set Chanmode  [string range $mp3head 24 25]
	set Modeextension [string range $mp3head 26 27]
	set Copyright [string index $mp3head 28]
	set Original [string index $mp3head 29]
	set Emphasis [string range $mp3head 30 31]
	
	switch -exact -- $MPEGAudioversion {
	    11 {set mpeg "1" ; set srateidx 0 }
	    10 {set mpeg "2" ; set srateidx 1 }
	    00 {set mpeg "2.5" ; set srateidx 2 }
	    01 {set mpeg "0" ; set srateidx 4 }
	}

	switch -exact -- $Layerdescription {
	    00 {set layer "0"}
	    01 {set layer "3"}
	    10 {set layer "2"}
	    11 {set layer "1"}
	}

	switch -exact -- $Protection {
	    0 {set protection "Yes"}
	    1 {set protection "No"}
	}

	switch -exact -- $mpeg.$layer {
	 1.1 { set bridx 0 }
	 1.2 { set bridx 1 }
	 1.3 { set bridx 2 }
	 2.1 { set bridx 3 }
	 2.2 { set bridx 4 }
	 2.3 { set bridx 4 }
	}


	set ioNJ(br.0000) {free free free free free }
	set ioNJ(br.0001) {32 32 32 32 8}
	set ioNJ(br.0010) {64 48 40 48 16}
	set ioNJ(br.0011) {96 56 48 56 24}
	set ioNJ(br.0100) {128 64 56 64 32}
	set ioNJ(br.0101) {160 80 64 80 40}
	set ioNJ(br.0110) {192 96 80 96 48}
	set ioNJ(br.0111) {224 112 96 112 56}
	set ioNJ(br.1000) {256 128 112 128 64}
	set ioNJ(br.1001) {288 160 128 144 80}
	set ioNJ(br.1010) {320 192 160 160 96}
	set ioNJ(br.1011) {352 224 192 176 112}
	set ioNJ(br.1100) {384 256 224 192 128}
	set ioNJ(br.1101) {416 320 256 224 144}
	set ioNJ(br.1110) {448 384 320 256 160}
	set ioNJ(br.1111) {bad bad bad bad bad}
	
	if {![info exists bridx]} { return }

	set bitrate "[lindex $ioNJ(br.$Bitrate) $bridx]"

	switch -exact -- $Samplingrate {
		00 {set srate {"44100" "22050" "11025"}}
		01 {set srate {"48000" "24000" "12000"}}
		10 {set srate {"32000" "16000" "8000"}}
		11 {set srate {Unknown Unknown Unknown}}
	}
	set srate [lindex $srate $srateidx]

	switch -exact -- $Chanmode {
		00 {set channelmode Stereo}
		01 {set channelmode "Joint Stereo"}
		10 {set channelmode "Dual channel"}
		11 {set channelmode  Mono}
	}


	if {![info exists mpeg]} { putlog -error "$mp3file dmpeg not found in file" ; return }
	if {$layer > 3} { putlog -error "$mp3file reports mpeglayer $layer" ; return}
	

	        set vbr   0
		if {$mpeg >= 2} { 
			if {$channelmode == "Mono"} { set lamestart "13" } else { set lamestart "21" }
		} elseif {$mpeg == 1} {
			if {$channelmode == "Mono"} { set lamestart "21" } else { set lamestart "36" }
		}

	      seek $fd [expr $offset + $lamestart]
	
	      if { [read $fd 4] == "Xing" } {
	        set vbr 1
	        set xingFrames 0
	        set xingBytes  0
	 	if {[binary scan [read $fd 4] I xingHeadFlags] != 1} {
			break	
		}
		if {[binary scan [read $fd 4] I xingFrames] != 1} {
			break
		}
		if {[binary scan [read $fd 4] I xingBytes] != 1} {
			break
		}
	        if { ($xingFrames > 0) && ($xingBytes  > 0) && ($xingHeadFlags > 3) } {
	          set bitrate [expr {(($xingBytes / $xingFrames) * $srate) / ($mpeg == 1 ? 144000 : 72000)}]
	        }
	      }
	      
	if {$vbr} {
	
		#find out if it's old or new vbr
	    	seek $fd [expr $offset + 165]
	    	set vbrver [read $fd 1]
	        set vbrver  [scan $vbrver %c]
	        switch -- $vbrver  {
			2 {set vbroldnew "ABR"}	    ; #abr
		      	3 {set vbroldnew "VBR-OLD"} ; #vbr old / vbr rh
		      	4 {set vbroldnew "VBR-NEW"} ; #VBR-MTRH
	      	        5 {set vbroldnew "VBR-NEW"} ; #VBR-MT
	      	}
      	
      	
	      	seek $fd [expr $offset + 155]
		set vbrquality [read $fd 1] ; # vbr quality setting
		set vbrquality [scan $vbrquality %c]
			
		seek $fd [expr $offset + 156]
		set lametemp [read $fd 10]
		binary scan $lametemp A9B8 Lame subrev
		set subver [bin2dec [string range $subrev 0 3]]
		set revision [bin2dec [string range $subrev 4 7]]
		set lame [string trim [string range $lametemp 0 8]]
		set sublame [scan [string index $lametemp 9] %c]
		seek $fd [expr $offset + 182]
		set preset [read $fd 2]
		binary scan $preset B16 temp
		set lamepreset [bin2dec $temp]
	
		if {[string index $lame end] == "."} {
	    		set lame "$lame$revision"
	 	}
	
	switch -- $lamepreset {
			1000 {set lpreset "APR"}
	      	1001 {set lpreset "APS"}
	      	1002 {set lpreset "APE"}
	      	1003 {set lpreset "API"}
	      	1004 {set lpreset "FAPS"}
	      	1005 {set lpreset "FAPE"}
	      	1006 {set lpreset "APM"}
	      	1007 {set lpreset "FAPM"}
			320  {set lpreset "INSANE"}
	      	410  {set lpreset "V9"}
	      	420  {set lpreset "V8"}
	      	430  {set lpreset "V7"}
	      	440  {set lpreset "V6"}
	      	450  {set lpreset "V5"}
	      	460  {set lpreset "V4"}
	      	470  {set lpreset "V3"}
	      	480  {set lpreset "V2"}
	      	490  {set lpreset "V1"}
	      	500  {set lpreset "V0"}
	     }
	}
	if {$Bitrate != 0000} {
		set duration [expr {int([file size $mp3file]*8 / double(1000*$bitrate))}]
	} else {
		set duration 0
	}
	close $fd
	
	if {$Original == 0} { set mp3original NO } else {  set mp3original Yes }
	if {$Padding == 0} { set mp3padding NO } else {  set mp3padding Yes }
	if {$vbr == 0} { set mp3vbr CBR } else { set mp3vbr VBR }
	
	
	
	set mp3info [list 0 $artist $album $title $bitrate $mpeg $layer $channelmode $genre $year $srate $lame $lpreset $mp3original $mp3padding $duration $track $mp3vbr $vbroldnew]
	regsub -all {[^[:graph:] ]} $mp3info {} mp3info
	writechattr 25 $mp3info

	   if {$mp3 == ""} {
	   
	 	if {[regexp $ioNJ(mp3_path_check) $pwd] && $ioNJ(mp3_path_check) != "" } { 

			#mp3 ban report or del
			if {$ioNJ(audio_year_check) && ![regexp $ioNJ(allowed_years) $year]} {
				if {[string match $ioNJ(del_banned_release_path) $pwd] && $ioNJ(del_banned_release_path) != ""} {
					output "$ioNJ(zipscript_header)$ioNJ(zipscript_mp3_del_year)$ioNJ(zipscript_footer_skip)"
					delete_dir "$pwd" "$path"
					return
				}
				if {$ioNJ(audio_year_warn)} {
					put_log "BADYEAR: [list $pwd $dir $user $ugroup $fname $year]"	
				}	
			}

			#check year and take action
			if {$ioNJ(audio_genre_check) == 1 && ![regexp -nocase $ioNJ(allowed_genres) $genre] && $ioNJ(allowed_genres) != ""} {
				if {[regexp -nocase $ioNJ(del_banned_release_path) $pwd] && $ioNJ(del_banned_release_path) != ""} {
					output "$ioNJ(zipscript_header)$ioNJ(zipscript_mp3_alo_genre)$ioNJ(zipscript_footer_skip)"
					delete_dir "$pwd" "$path"
					return
				}
				if {$ioNJ(audio_genre_warn)} {
					put_log "BADGENRE: [list $pwd $dir $user $ugroup $fname $genre]"	
				}
			} elseif {$ioNJ(audio_genre_check) == 2 && [regexp -nocase $ioNJ(banned_genres) $genre] && $ioNJ(banned_genres) != ""} {
				if {$ioNJ(del_banned_release_path) != "" && [regexp -nocase $ioNJ(del_banned_release_path) $pwd]} {
					output "$ioNJ(zipscript_header)$ioNJ(zipscript_mp3_ban_genre)$ioNJ(zipscript_footer_skip)"
					delete_dir "$pwd" "$path"
					return
				} 
				if {$ioNJ(audio_genre_warn)} {
					put_log "BADGENRE: [list $pwd $dir $user $ugroup $fname $genre]"	
				}
			}
		}
	    }
	
	return
}



#######################
## Mp3 Genres
#######################


set ioNJ(genres) {
"Blues" "Classic Rock" "Country" "Dance"
"Disco" "Funk" "Grunge" "Hip-Hop"
"Jazz" "Metal" "New Age" "Oldies"
"Other" "Pop" "R&B" "Rap"
"Reggae" "Rock" "Techno" "Industrial"
"Alternative" "Ska" "Death Metal" "Pranks"
"Soundtrack" "Euro-Techno" "Ambient" "Trip-Hop"
"Vocal" "Jazz+Funk" "Fusion" "Trance"
"Classical" "Instrumental" "Acid" "House"
"Game" "Sound Clip" "Gospel" "Noise"
"Alt. Rock" "Bass" "Soul" "Punk"
"Space" "Meditative" "Instrumental Pop" "Instrumental Rock"
"Ethnic" "Gothic" "Darkwave" "Techno-Industrial"
"Electronic" "Pop-Folk" "Eurodance" "Dream"
"Southern Rock" "Comedy" "Cult" "Gangsta Rap"
"Top 40" "Christian Rap" "Pop Funk" "Jungle"
"Native American" "Cabaret" "New Wave" "Psychedelic"
"Rave" "Showtunes" "Trailer" "Lo-Fi"
"Tribal" "Acid Punk" "Acid Jazz" "Polka"
"Retro" "Musical" "Rock & Roll" "Hard Rock"
"Folk" "Folk Rock" "National Folk" "Swing"
"Fast-Fusion" "Bebob" "Latin" "Revival"
"Celtic" "Bluegrass" "Avantgarde" "Gothic Rock"
"Progressive Rock" "Psychedelic Rock" "Symphonic Rock" "Slow Rock"
"Big Band" "Chorus" "Easy Listening" "Acoustic"
"Humour" "Speech" "Chanson" "Opera"
"Chamber Music" "Sonata" "Symphony" "Booty Bass"
"Primus" "Porn Groove" "Satire" "Slow Jam"
"Club" "Tango" "Samba" "Folklore"
"Ballad" "Power Ballad" "Rhythmic Soul" "Freestyle"
"Duet" "Punk Rock" "Drum Solo" "A Cappella"
"Euro-House" "Dance Hall" "Goa" "Drum & Bass"
"Club-House" "Hardcore" "Terror" "Indie"
"BritPop" "Negerpunk" "Polsk Punk" "Beat"
"Christian Gangsta Rap" "Heavy Metal" "Black Metal" "Crossover"
"Contemporary Christian" "Christian Rock" "Merengue" "Salsa"
"Thrash Metal" "Anime" "JPop" "Synthpop"
"Unknown"
}

#######################
## Binary To Decimal
#######################

proc ::ioNiNJA::bin2dec {binary} {
	set decimal 0
	for {set i 0} {$i < [string length $binary]} {incr i} {
		set next [string index $binary end-$i]
		set decimal [expr ($next << $i) | $decimal]
	}
	return $decimal
}


###################################
### Artist info and extraction
##################################
proc ::ioNiNJA::local {artist album year} { global ioNJ path pwd
	foreach pic [get_files $path *.jpg ] {
		if {[regexp -nocase {front|cover} $pic]} {
			if {[file exists "$path/folder.jpg"]} {
				catch {file delete -force "$path/folder.jpg"}
			}
			catch {file copy -force $pic [file join [file dirname $pic] folder.jpg]}
			return 1
		}
	}
	return 0
}

proc ::ioNiNJA::discogs {artist album year} { global ioNJ path pwd

		set artist [regsub -all { } "[string map [list À a Á a Â a Ã a Ä a Å a Æ a Ç c È e É e Ê e Ë e Ì i Í i Î i Ï i Ð d Ñ n Ò o Ó o Ô o Õ o Ö o Ø o Ù u Ú u Û u Ü u Ý y à a á a â a ã a ä a å a æ a ç c è e é e ê e ë e ì i í i î i ï i  ñ n ò o ó o ô o õ o ö o ø o ù u ú u û u ü u ý y ÿ y] ${artist}]" {+}]
		set search [regsub -all { } "${artist}+${album}" {+}] 
		set search [regsub -all {&} $search {and}]
		
		catch {exec ../scripts/ioNiNJA/MiSC/curl.exe --compressed  "https://www.discogs.com/search?type=all&q=${search}&f=xml"} temp

		if {[regexp -nocase {<searchresults end=".+?" numResults="0" start="1"/>} $temp]} {
			return 0
		}
		
		if {![regexp -nocase {<uri>(https://www.discogs.com/.+?/.+?/\d+)</uri>} $temp -> uri]} {
			return 0
		}

		catch {exec ../scripts/ioNiNJA/MiSC/curl.exe --compressed "${uri}"} temp
		if {[regexp -nocase {<meta property="og:image" content="([^"]+)} $temp -> img]} {
			regsub {\-90} $img {} img
			save_pic $img
			return 1
		} 
		return 0


}

proc ::ioNiNJA::backdrop {artist} { global  ioNJ path pwd

		if {[file exists [file join $path fanart.jpg]]} { return }

		if {[file exists "[file dirname [info script]]/Music/fanart/$artist/"]} {
			set fanart [lindex [get_files "[file dirname [info script]]/Music/fanart/$artist/" *] 0]
			if {$fanart != ""} {
				catch {file copy $fanart [file join $path fanart.jpg]}
				return
			}
		}
		
		catch {exec  -- ../scripts/ioNiNJA/MiSC/curl.exe "https://www.htbackdrops.com/search.php?search_terms=artist&search_terms=all&search_fields=name&cat_id=1&search_keywords=[regsub -all " " $artist {+}]"} url
		if {[set temp [regexp -nocase -all -inline -- {<img src="\./data/thumbnails/1/(.+?.jpg)"} $url]] != ""} {
			set i 0
			foreach {crap fil} $temp {
				
				if {![file exists "[file dirname [info script]]/Music/fanart/$artist/$fil"]} {
					set fanart "https://www.htbackdrops.com/data/media/1/$fil"
					catch {file mkdir [file dirname [info script]]/Music/fanart/$artist/}
					catch {exec -- ../scripts/ioNiNJA/MiSC/curl.exe $fanart --output [file dirname [info script]]/Music/fanart/$artist/$fil}
					if {![bin_ary [readfile [file dirname [info script]]/Music/fanart/$artist/$fil]]} {
						catch {file delete -force [file dirname [info script]]/Music/fanart/$artist/$fil}
						catch {exec -- ../scripts/ioNiNJA/MiSC/curl.exe $fanart --output [file dirname [info script]]/Music/fanart/$artist/$fil} temp2
						if {![bin_ary  [readfile [file dirname [info script]]/Music/fanart/$artist/$fil]]} {
							catch {file delete -force [file dirname [info script]]/Music/fanart/$artist/$fil}
						}
					}
				}
				incr i
			}
			set fanart [lindex [get_files "[file dirname [info script]]/Music/fanart/$artist/" *] 0]
			catch {file copy $fanart [file join $path fanart.jpg]}
		}
		return 0
}


proc ::ioNiNJA::audioscrobbler {artist album year} { global ioNJ path pwd

	set temp [get_url https://ws.audioscrobbler.com/2.0/?method=album.getinfo&api_key=LASTFM_API_KEY_HERE&artist=[regsub -all { } "[string map [list À a Á a Â a Ã a Ä a Å a Æ a Ç c È e É e Ê e Ë e Ì i Í i Î i Ï i Ð d Ñ n Ò o Ó o Ô o Õ o Ö o Ø o Ù u Ú u Û u Ü u Ý y à a á a â a ã a ä a å a æ a ç c è e é e ê e ë e ì i í i î i ï i  ñ n ò o ó o ô o õ o ö o ø o ù u ú u û u ü u ý y ÿ y] ${artist}]" {+}]&album=[regsub -all { } "${album}" {+}]&autocorrect=1]
	if {![regexp -nocase { <image size="mega">(http://.+?)</image>} $temp -> img]} {
       		regexp -nocase { <image size="extralarge">(.+?)</image>} $temp -> img
	}

	if {[info exists img]} {
		if {[regexp -nocase {https://images.amazon.com/.+?.jpg} $img]} {
			regsub -all -nocase {.01.MZZZZZZZ} $img {} img
		}
		save_pic $img
		if {[file exists [file join $path folder.jpg]]} {
			return 1
		} else {
			return 0
		}

	}
	

	return 0


}


proc ::ioNiNJA::amazon {artist album year} { global path pwd ioNJ
	

	regsub -nocase -all {^the } $album {} album

	
	set search [regsub -all { } "${artist}+${album}+${year}" {+}]  

	set temp [get_url "https://www.amazon.com/gp/search/ref=sr_adv_m_pop/?search-alias=popular&unfiltered=1&field-keywords=[regsub -all { } $artist {+}]&field-artist=[regsub -all { } $artist {+}]&field-title=[regsub -all { } $album {+}]&field-label=&field-binding=&sort=relevancerank&Adv-Srch-Music-Album-Submit.x=0&Adv-Srch-Music-Album-Submit.y=0"]
	if {![regexp -nocase {<div class=\"productTitle\"><a href=\"http://www.amazon.com/.+?/dp/(.+?)/.+?\"} $temp -> newurl]} {
		
		set mp3url [get_url "https://www.google.com/search?hl=en&btnI=I%27m+Feeling+Lucky&as_sitesearch=www.amazon.com&q=[::http::formatQuery "$search"]"]
		if {![regexp -nocase {<A HREF=\"http://www.amazon.com/.+?/dp/(.+?)\"} $mp3url -> newurl]} { 
			set search [regsub -all { } "${artist}+${album}" {+}]  
			set mp3url [get_url "https://www.google.com/search?hl=en&btnI=I%27m+Feeling+Lucky&as_sitesearch=www.amazon.com&q=[::http::formatQuery "$search"]"]
			if {![regexp -nocase {<A HREF=\"http://www.amazon.com/.+?/dp/(.+?)\"} $mp3url -> newurl]} { 
				return 0
			}
		}
	} 

	set newurl "https://www.amazon.com/gp/product/images/$newurl"	
	set mp3url [get_url $newurl]
	if {![regexp -nocase {<noscript><div id=\"imageViewerDiv\"><img src=\"(https://ecx.images-amazon.com/images/I/.+?._)SS.+?_\.jpg\" id=\".+?\" /></div></noscript>} $mp3url -> newurl1]} {
		if {![regexp -nocase {<div style=\".+?\"><img src=\"(https://g-ecx.images-amazon.com/images/.+?)\" width=\".+?\" height=\".+?\" border=\".+?\" /></div>} $mp3url -> newurl]} {
			return 0
		}
	}
	
	if {[info exists newurl1]} {
		set newurl "${newurl1}SL600_.jpg"
	}

	if {[regexp -nocase " " $newurl]} { return 0 }

	set pic_data [save_pic $newurl]

	
	return 1
}

proc ::ioNiNJA::get_music_artist {artist dir} { global ioNJ 

	set apic ""
	if {[regexp -nocase {^(va|v\.a|various\_artists)(\_|\-)} $dir]} { set artist "VA" }
    if {[regexp -nocase {(^ost|^o\.s\.t|\-soundtrack|\-ost|\_ost)(\_|\-)} $dir]} { set artist "OST" }
	set artist [string trim $artist]
	
	if {![regexp -nocase {^(ost|va)$} $artist]} {
		set artist_idx [audioscrobbler_artist $artist]
		set apic ""	
		if {$artist_idx != "" && [lindex $artist_idx 1] != ""} {
			set artist [lindex $artist_idx 1]
			set apic [lindex $artist_idx 2]
		}
	}
	regsub -all {/|\\|:|\*|\?|\"|\<|\>|\|} $artist {} artist
	return [list $artist $apic]

}


proc ::ioNiNJA::get_music_album {album} { global ioNJ 
	regsub -all {_|\-} $album { } album
	if {[regexp -nocase {(\(.*)} $album -> temp]} {
	 	if {[regexp -nocase {(proper|promo|repack|cd|reissue|disc|fixed|disk|release|digipak|uk|japan|remastered|explicit|real|dirty|selection|retail|edition|ltd|limited edition|advance|sampler|cds|cdm|ep|vls|12inch|read|web|trackfix|bonus)} [regsub -all {_|\.|\-} $temp { }]]} {
	 		regexp -nocase {(.+?)\(.+?} $album -> album
	 	}
	}
		 			 	
	regsub -nocase -lineanchor {\-$} [string trim $album] {} album
	regsub -nocase -lineanchor {(CD [0-9]+|CD[0-9]|[0-9]CD|promo|CDA|ltd|reissue|fixed|re release|fan edition|special edition|delux edition|limited|release|proper|repack|retail|explicit|selection|clean|dirty|remastered|advance|sampler|cds|cdm|ep|vls|12inch|read nfo|readnfo|read nfo)$} [string trim $album] {} album
	set album [string trim $album]
	set temp_alb ""
	foreach word $album {
		if {[regexp -nocase -lineanchor {^(CD|CD[0-9]|[0-9]CD|ltd|reissue|repack|retail|explicit|remastered|sampler|cds|cdm|ep|vls|12inch|read nfo|readnfo|read nfo)$} $word]} { continue }
		lappend temp_alb $word 
	}
		 			 
	set album [join $temp_alb]
	regsub -nocase -lineanchor {\-$} [string trim $album] {} album
	return $album
}


proc ::ioNiNJA::audioscrobbler_artist {artist} { global ioNJ path pwd
	set a1 [string trim $artist]
	set mbid ""
	set artist [string trim $artist]
	set artists [file join [file dirname [info script]] Artists]
	set afile [file join $artists artists.db]
	set art "-1"
	set img ""
	
	if {![file exists [file join $artists artists.db]]} {
		if {![file exists $artists]} {
			catch {file mkdir $artists}
		}
		set adb3 [open [file join $artists artists.db] w]
		close $adb3
	}

	if {[file exists $afile]} {
        set artists_idx [split [string trim [readfile $afile]] \n]
		if {[set art [lsearch -nocase -index 0 $artists_idx "$artist"]] != "-1"} {
			if {[file exists [lindex [lindex $artists_idx $art] 2]]} {
				return [lindex $artists_idx $art]
			} else {
				set artist [lindex [lindex $artists_idx $art] 1]
			}
		}
    }

	set temp [get_url https://ws.audioscrobbler.com/2.0/?method=artist.getcorrection&artist=[regsub -all { } "[string map [list À a Á a Â a Ã a Ä a Å a Æ a Ç c È e É e Ê e Ë e Ì i Í i Î i Ï i Ð d Ñ n Ò o Ó o Ô o Õ o Ö o Ø o Ù u Ú u Û u Ü u Ý y à a á a â a ã a ä a å a æ a ç c è e é e ê e ë e ì i í i î i ï i  ñ n ò o ó o ô o õ o ö o ø o ù u ú u û u ü u ý y ÿ y] ${artist}]" {+}]&api_key=LASTFM_API_KEY_HERE]
	regexp -nocase {<name>(.+?)</name>} $temp -> artist
	regexp -nocase {<mbid>(.+?)</mbid>} $temp -> mbid

	if {$mbid != ""} {
		set temp [get_url https://ws.audioscrobbler.com/2.0/?method=artist.getinfo&mbid=$mbid&api_key=LASTFM_API_KEY_HERE]
	} else {
		set temp [get_url https://ws.audioscrobbler.com/2.0/?method=artist.getinfo&artist=[regsub -all { } "${artist}" {+}]&api_key=LASTFM_API_KEY_HERE]
	}

	

    if {[regexp -nocase {<url>https://www.last.fm/music/\+noredirect/.+?</url>} $temp]} {
        if {![regexp -nocase  {<similar>.+?<name>(.+?)</name>} $temp  -> artist]} {
			return
        }
    } elseif {![regexp -nocase {<name>(.+?)</name>} $temp -> artist]} {
		return
    }
	regexp -nocase {<mbid>(.+?)</mbid>} $temp -> mbid
	regsub -all {\\|:|\*|\?|\"|\<|\>|\||/} $artist {} artist
	set artist [string map [list &amp\; & &gt\; "" &lt\; "" &quot\; ' &apos\; '] $artist]

	
	if {![regexp -nocase {<image size="mega">([^<]+)} $temp -> img]} {
		save_pic_custom $img [file join $artists ${artist}[file extension $img]]
	} elseif {[regexp -nocase {<image size="extralarge">([^<]+)} $temp -> img]} {
		save_pic_custom $img [file join $artists ${artist}[file extension $img]]
	} else {
		set img ""
	}
	
	if {$img != ""} {
		set img [file join $artists ${artist}[file extension $img]]
	}

	if {$art != "-1"} {
		writefile $afile [join [lreplace $artists_idx $art $art [list $a1 $artist $img $mbid]] \n]
		return [list $a1 $artist $img $mbid]
	} else {
		appendfile [file join $artists artists.db] [list $a1 $artist $img $mbid]
		return [list $a1 $artist $img $mbid]
	}

	return
}

#######################
### Get Total Files From zipfile and extract nfo
#######################
proc ::ioNiNJA::get_zip_info {zipfile} {global path pwd
	if {![file exists $path/file_id.diz] || [file size "$path/file_id.diz"] == 0} {
		catch {set inzip [exec ../scripts/ioNiNJA/MiSC/UNZIP32.exe -qql $zipfile]} inzip
			foreach {Length Date Time Name} $inzip {
				if {[regexp -nocase {file_id\.diz$} $Name]} {
				  catch {set temp [exec ../scripts/ioNiNJA/MiSC/UNZIP32.exe  -Cqqp $zipfile $Name > $path/$Name]} temp
				  vfs chattr "$path" 10 $Name
				}
		}
		symlink_proc cd 1
	}
		
	if {![file exists "$path/file_id.diz"]} {
		return
	} else {
		set diz "$path/file_id.diz"
	}

	if {[file size "$path/file_id.diz"] == 0} {
		catch {file delete -force "$path/file_id.diz"}
		return
	}

	regsub -all -nocase {x|o|\*} [readfile $diz] 0 diz
	regsub -all -nocase {[0-9]{1,4}/[0-9]{1,4}/[0-9]{1,4}} $diz "" diz
	set dizinfo [regexp {[^/0-9]([0-9]{1,3})(?:/|/\n)([0-9]{1,3})(?:[^/0-9]|$)} $diz -> file_nr total_files]
	if {[info exists total_files]} {
		scan $total_files %d total_files
		set total_files [format %.0f $total_files]
		catch {vfs chattr "$path" 13 $total_files}
		return
	} else {
		catch {file delete -force "$path/file_id.diz"}
		return
	}
	
}



#######################
### Get duration from timestamp
#######################

proc ::ioNiNJA::duration { secs } {
     if {![string is integer -strict $secs]} { return "0s" }
     set timeatoms [ list ]
     if { [ catch {
        foreach div { 86400 3600 60 1 } \
                mod { 0 24 60 60 } \
               name { d h m s } {
           set n [ expr {$secs / $div} ]
           if { $mod > 0 } { set n [ expr {$n % $mod} ] }
              if { $n > 1 } {
              lappend timeatoms "$n${name}"
           } elseif { $n == 1 } {
             lappend timeatoms "$n$name"
           }
        }
     } err ] } {
        return -code error "duration: $err"
     }
     return [ join $timeatoms ]
}


#######################
###Get userinfo
#######################
proc ::ioNiNJA::get_uinfo {user type} {
	if {[userfile open $user] == 0} {
		if {[set ufile [userfile bin2ascii]] != ""} {
			foreach info [split $ufile \n] {
				if {[string match -nocase $type [lindex $info 0]]} {
					return [lrange $info 1 end]
				}
			}
		} 
	}
  return ""
}


#######################
### String map crappy html codes
#######################

proc ::ioNiNJA::htmlcodes {tempfile} {
  set mapfile [string map {&#x26; & &nbsp; " " &#160; " " &#xA0; " " &iexcl; ¡ &#161; ¡ &#xA1; ¡ &cent; ¢ &#162; ¢ &#xA2; ¢ &pound; £ &#163; £ &#xA3; £ &curren; ¤ &#164; ¤ &#xA4; ¤ &yen; ¥ &#165; ¥ &#xA5; ¥ &brvbar; ¦ &#166; ¦ &#xA6; ¦ &sect; § &#167; § &#xA7; § &uml; ¨ &#168; ¨ &#xA8; ¨ &copy; © &#169; © &#xA9; © &ordf; ª &#170; ª &#xAA; ª &laquo; « &#171; « &#xAB; « &not; ¬ &#172; ¬ &#xAC; ¬ &shy; ­ &#173; ­ &#xAD; ­ &reg; ® &#174; ® &#xAE; ® &macr; ¯ &#175; ¯ &#xAF; ¯ &deg; ° &#176; ° &#xB0; ° &plusmn; ± &#177; ± &#xB1; ± &sup2; ² &#178; ² &#xB2; ² &sup3; ³ &#179; ³ &#xB3; ³ &acute; ´ &#180; ´ &#xB4; ´ &micro; µ &#181; µ &#xB5; µ &para; ¶ &#182; ¶ &#xB6; ¶ &middot; · &#183; · &#xB7; · &cedil; ¸ &#184; ¸ &#xB8; ¸ &sup1; ¹ &#185; ¹ &#xB9; ¹ &ordm; º &#186; º &#xBA; º &raquo; » &#187; » &#xBB; » &frac14; ¼ &#188; ¼ &#xBC; ¼ &frac12; ½ &#189; ½ &#xBD; ½ &frac34; ¾ &#190; ¾ &#xBE; ¾ &iquest; ¿ &#191; ¿ &#xBF; ¿ &Agrave; À &#192; À &#xC0; À &Aacute; Á &#193; Á &#xC1; Á &Acirc; Â &#194; Â &#xC2; Â &Atilde; Ã &#195; Ã &#xC3; Ã &Auml; Ä &#196; Ä &#xC4; Ä &Aring; Å &#197; Å &#xC5; Å &AElig; Æ &#198; Æ &#xC6; Æ &Ccedil; Ç &#199; Ç &#xC7; Ç &Egrave; È &#200; È &#xC8; È &Eacute; É &#201; É &#xC9; É &Ecirc; Ê &#202; Ê &#xCA; Ê &Euml; Ë &#203; Ë &#xCB; Ë &Igrave; Ì &#204; Ì &#xCC; Ì &Iacute; Í &#205; Í &#xCD; Í &Icirc; Î &#206; Î &#xCE; Î &Iuml; Ï &#207; Ï &#xCF; Ï &ETH; Ð &#208; Ð &#xD0; Ð &Ntilde; Ñ &#209; Ñ &#xD1; Ñ &Ograve; Ò &#210; Ò &#xD2; Ò &Oacute; Ó &#211; Ó &#xD3; Ó &Ocirc; Ô &#212; Ô &#xD4; Ô &Otilde; Õ &#213; Õ &#xD5; Õ &Ouml; Ö &#214; Ö &#xD6; Ö &times; × &#215; × &#xD7; × &Oslash; Ø &#216; Ø &#xD8; Ø &Ugrave; Ù &#217; Ù &#xD9; Ù &Uacute; Ú &#218; Ú &#xDA; Ú &Ucirc; Ú &#219; Û &#xDB; Û &Uuml; Ü &#220; Ü &#xDC; Ü &Yacute; Ý &#221; Ý &#xDD; Ý &THORN; Þ &#222; Þ &#xDE; Þ &szlig; ß &#223; ß &#xDF; ß &agrave; à &#224; à &#xE0; à &aacute; á &#225; á &#xE1; á &acirc; â &#226; â &#xE2; â &atilde; ã &#227; ã &#xE3; ã &auml; ä &#228; ä &#xE4; ä &aring; å &#229; å &#xE5; å &aelig; æ &#230; æ &#xE6; æ &ccedil; ç &#231; ç &#xE7; ç &egrave; è &#232; è &#xE8; è &eacute; é &#233; é &#xE9; é &ecirc; ê &#234; ê &#xEA; ê &euml; ë &#235; ë &#xEB; ë &igrave; ì &#236; ì &#xEC; ì &iacute; í &#237; í &#xED; í &icirc; î &#238; î &#xEE; î &iuml; ï &#239; ï &#xEF; ï &eth; ð &#240; ð &#xF0; ð &ntilde; ñ &#241; ñ &#xF1; ñ &ograve; ò &#242; ò &#xF2; ò &oacute; ó &#243; ó &#xF3; ó &ocirc; ô &#244; ô &#xF4; ô &otilde; õ &#245; õ &#xF5; õ &ouml; ö &#246; ö &#xF6; ö &divide; ÷ &#247; ÷ &#xF7; ÷ &oslash; ø &#248; ø &#xF8; ø &ugrave; ù &#249; ù &#xF9; ù &uacute; ú &#250; ú &#xFA; ú &ucirc; û  &#251; û &#xFB; û &uuml; ü &#252; ü &#xFC; ü &yacute; ý &#253; ý &#xFD; ý &thorn; þ &#254; þ &#xFE; þ &yuml; ÿ &#255; ÿ &#xFF; ÿ } $tempfile]
  set mapfile [string map {&#x22; ' &#x27; ' &#160; " " &#39; ' &#34; ' &#38; & &#91; ( &#92; / &#93; ) &#123; ( &#125; ) &#161; ¡ &#162; ¢ &#163; £ &#164; ¤ &#165; ¥ &#166; ¦ &#167; § &#168; ¨ &#169; © &#170; ª &#171; « &#172; ¬ &#173; ­ &#174; ® } $mapfile]
  set mapfile [string map {&#175; ¯ &#176; ° &#177; ± &#178; ² &#179; ³ &#180; ´ &#181; µ &#182; ¶ &#183; · &#184; ¸ &#185; ¹ &#186; º &#187; » &#188; ¼ &#189; ½ &#190; ¾ &#191; ¿ &#192; À &#193; Á &#194; Â } $mapfile]
  set mapfile [string map {&#195; Ã &#196; Ä &#197; Å &#198; Æ &#199; Ç &#200; È &#201; É &#202; Ê &#203; Ë &#204; Ì &#205; Í &#206; Î &#207; Ï &#208; Ð &#209; Ñ &#210; Ò &#211; Ó &#212; Ô &#213; Õ &#214; Ö } $mapfile]
  set mapfile [string map {&#215; × &#216; Ø &#217; Ù &#218; Ú &#219; Û &#220; Ü &#221; Ý &#222; Þ &#223; ß &#224; à &#225; á &#226; â &#227; ã &#228; ä &#229; å &#230; æ &#231; ç &#232; è &#233; é &#234; ê } $mapfile]
  set mapfile [string map {&quot; ' &amp; "&" &#235; ë &#236; ì &#237; í &#238; î &#239; ï &#240; ð &#241; ñ &#242; ò &#243; ó &#244; ô &#245; õ &#246; ö &#247; ÷ &#248; ø &#249; ù &#250; ú &#251; û &#252; ü &#253; ý &#254; þ } $mapfile]
  return $mapfile
}



#######################
# Sorting
#######################

proc ::ioNiNJA::sorting {symtype linkto item pwd} {global ioNJ path
	set linkto [file normalize $linkto]
	set item [file normalize $item]
	
	set item [string map [get_time [clock seconds]] $item]
	
	if {[file exists $item]} { 
		if {![catch {file link $item} templink]} {
			set templink [file normalize $templink]
			if {![file exists $templink] || ( [string match -nocase $templink $linkto] )} { 
				catch {file delete -force -- $item} error 
			} elseif {[file tail $templink] == [file tail $linkto] && ( $templink != $linkto )} {
				set item "${item}.dupe"
			}				
		} else {
			catch {file delete -force -- $item} error 
		}
	} 
			
	if {[file exists $item]} { 
		set i 0
		while {[file exists "${item} (${i})"] && $i != 100} {
			incr i	
		}
		set item "${item} (${i})"
	}
	
	
    if {!$symtype} {
 		catch {file delete -force -- $item}
		catch {file mkdir "$item"}
		catch {vfs chattr "$item" 1 "$pwd"}
		catch {vfs flush "$item"}
	} else {
		catch {file delete -force -- $item}
		catch {file mkdir "[file dirname $item]"}
		catch {file link -symbolic "$item" "$linkto"} error
	}

	set symlinks [readchattr 240]
	lappend symlinks $item
	writechattr 240 $symlinks	
 return
}




#######################
## Get URL
#######################

proc ::ioNiNJA::get_url_new {url} { global ioNJ

  if {[regexp -nocase { } [string trim $url]]} { return "" }

  if {![regexp -nocase {http://} $url]} { set url "https://${url}" }
  
  #Set proxies etc.
  if {$ioNJ(curl_proxy) != ""} {
		if {$ioNJ(curl_user_pass) != ""} {
			set CurlLine  "-U $ioNJ(curl_user_pass) -x $ioNJ(curl_proxy) --user-agent \"Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.0)\""
		} else {
			set CurlLine  "-x $ioNJ(curl_proxy) --user-agent \"Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.0)\""
		}
  } else {
		set CurlLine  "--user-agent \"Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.0)\""
  }
  
  catch {
  	set i 0
  	while {[catch {eval exec -- ../scripts/ioNiNJA/MiSC/curl.exe $CurlLine $url} tempcode] && $i != 5} {
		if {![regexp -nocase {curl\: \(\d+\)} $tempcode]} { break }
		incr i
		set tempcode ""
  	}
	if {[regexp -nocase {curl\: \(\d+\)} $tempcode]} { return "" }
  	set tempcode [htmlcodes $tempcode]
  } 
  return $tempcode 
}

proc ::ioNiNJA::get_url {url} { global ioNJ
  if {[regexp -nocase { } [string trim $url]]} { return "" }
  if {![regexp -nocase {http://} $url]} { set url "https://${url}" }
  set CurlLine [GetCurlLine]
  catch {
  	set i 0
  	while {[catch {eval exec -- ../scripts/ioNiNJA/MiSC/curl.exe $CurlLine $url} tempcode] && $i != 5} {
		if {![regexp -nocase {curl\: \(\d+\)} $tempcode]} { break }
		incr i
		set tempcode ""
  	}
	if {[regexp -nocase {curl\: \(\d+\)} $tempcode]} { return "" }
  	set tempcode $tempcode
  } 
  
  return $tempcode 
}






#######################
## Get GrpName From Rel
#######################

proc ::ioNiNJA::get_grpname {release} {global ioNJ
  if {[regexp {\-} $release]} {
  	set temps [split [string trim $ioNJ(force_groupnames)] \n]
  	if {$temps != ""} {
  		foreach temp $temps {
  			lassign $temp regex grp 
  			if {[regexp -nocase $regex $release]} { return $grp }
  		}
	}
  	if {[lindex [split $release -] end] != $release} { return [lindex [split $release -] end]}
  } 
  
  return "Unknown"
}



#######################
## Make inc symlinks
#######################

proc ::ioNiNJA::symlink_proc {type action} { global ioNJ pwd path
		set dir [lindex [file split $path] end]
		set parent [lindex [file split $path] end-1]
		set rdir [file dirname $path]
		set release [file tail $dir]
		set type2 ""
		set uinfo "0 0 777"
		catch {vfs read $path} uinfo
		lassign $uinfo uid gid mode
		set mode [string range $mode 2 5]
		if {[regexp -nocase "$ioNJ(notparent)" "[file tail $dir]"]} {
			set release "${parent}.[file tail $dir]"
			set rdir [file dirname $rdir]
			set type2 cd
		}
		

		
		switch -- $type {
			sfv  { 
				if {$type2 == "cd"} { 
						set directory $ioNJ(incomplete_indicator_cd_sfv)
				}  else {
				        set directory $ioNJ(incomplete_indicator_sfv)
				}
				if {$ioNJ(group_status)} {
					set gid [resolve group NO_SFV]
				}
			}
			
			nfo  { 
				if {$type2 == "cd"} { 
					set dir $parent 
				} 
				set directory $ioNJ(incomplete_indicator_nfo)
				if {$ioNJ(group_status)} {
					set gid [resolve group NO_NFO]
				}
			}
			
			sample  { 
				if {$type2 == "cd"} { 
					set dir $parent 
				} 
				set directory $ioNJ(incomplete_indicator_sample)
				if {$ioNJ(group_status)} {
					set gid [resolve group NO_SAMPLE]
				}
			}
			
			
		    cd {
				if {$type2 == "cd"} { 
					set directory $ioNJ(incomplete_indicator_cd) 
				}  else {
				    set directory $ioNJ(incomplete_indicator)
				}
				if {$ioNJ(group_status)} {
					set gid [resolve group INCOMPLETE]
				}

		    }
		}
		
	set dir [string map [list %di $dir %pa $parent] $directory]

	if {$action == 1} {
		catch {file mkdir "$rdir/$dir"}
		catch {vfs chattr "$rdir/$dir" 1 "$pwd"}
		if {$ioNJ(group_status)} {
			if {$type2 == ""} {
				catch {vfs write $path $uid $gid 777} error
			} else {
				catch {vfs write $path $uid $gid 777} error
				catch {vfs write [file dirname $path] $uid $gid 777} error
			}
		}
		catch {vfs flush $path }
		if {$ioNJ(sym_inc_dir) != "" && [file exists $ioNJ(sym_inc_dir)]} {
			if {![regexp -nocase $ioNJ(group_dirs) $pwd]} {
				catch {file mkdir "$ioNJ(sym_inc_dir)/$release"} error
				catch {vfs chattr "$ioNJ(sym_inc_dir)/$release" 1 "$pwd"}
				catch {vfs flush $ioNJ(sym_inc_dir)}
			}
		}
	} else {
		catch {file delete -force "$rdir/$dir"}
		catch {vfs flush $path}
		if {$ioNJ(sym_inc_dir) != "" && ![regexp -nocase $ioNJ(group_dirs) $pwd]} {
			catch {file delete -force "$ioNJ(sym_inc_dir)/$release"}
			catch {vfs flush $ioNJ(sym_inc_dir)}
		}
	}
	
	return
}


#######################
## Get Sammple Info
#######################

proc ::ioNiNJA::getsample {sample} { global path pwd ioNJ uid gid args
	set samplerelease [lindex [file split $pwd] end-1]
	set samplemessage "\n"
	catch {exec ../scripts/ioNiNJA/misc/media.exe $sample} temp
	if {$temp == ""} { return ""}
	set audiostreams 0
	set textstreams 0
	set type 0 ; set g_movie_name "N/A" ; set w_writelib "N/A" ; set v_chroma "N/A" ; set v_resolution "N/A" ; set g_performer "N/A" ; set g_format  "N/A" ; set g_bitrate "N/A" ; set g_writeapp "N/A" ; set g_writelib "N/A" ; set a_codec "N/A" ; set a_codec_prof "N/A" ; set a_bitrate "N/A" ; set a_bitrate_mode "N/A" ; set a_chans "N/A" ; set a_srate "N/A" ; set a_WriteLib "N/A" ; set a_res "N/A" ; set a_chanpos "N/A" ; set v_codec_info "N/A" ; set v_codec_family "N/A" ; set v_codec_pack "N/A" ; set v_codec_bvop "N/A" ; set v_codec_qpel "N/A" ; set v_codec_gmc "N/A" ; set v_codec_matrix "N/A" ; set v_codec "N/A" ; set v_width "N/A" ; set v_height "N/A" ; set v_ar "N/A" ; set v_br "N/A" ; set v_fr "N/A" ; set v_standard "N/A" ; set v_interlace "N/A"

	set samplemessage $ioNJ(sample_head)
	foreach line [split $temp \n] {
		if {$line == ""} { continue }
		if {[string match "General #*" $line] || ( [regexp -nocase {(^General$)} $line] ) } { 
			if {[lindex $line 1] == "#0" || ([regexp -nocase {(^General$)} $line]) } {
				set type g
			} else {
				set type 0
			}
		} elseif {[string match "Video #*" $line]  || ( [regexp -nocase {(^Video$)} $line] ) } { 
			if {[lindex $line 1] == "#1" || ([regexp -nocase {(^Video$)} $line])} {
				append samplemessage $ioNJ(sample_video_head)
				set type v
			} else {
				set type 0
			}
		} elseif {[string match "Audio #*" $line] || ([regexp -nocase {(^Audio$)} $line]) } {
			incr audiostreams
			if {[lindex $line 1] == "#1" || ([regexp -nocase {(^Audio$)} $line]) } {
				append samplemessage "$ioNJ(sample_audio_head)"
				set type a
			} else {
				set type 0
			}
		} elseif {[string match "Text #*" $line] || ([regexp -nocase {(^Text$)} $line]) } {
			incr textstreams
			if {[lindex $line 1] == "#1" || ([regexp -nocase {(^Text$)} $line]) } {
				set type t
			} else {
				set type 0
			}
		} 


		set line [split $line :]
		set first [string trim [lindex $line 0]]
		set second [string trim [join [lrange $line 1 end]]]

		if {$type == "g"} {
			switch -- $first {
			  "Copyright"  { set g_movie_cr $second        ; append samplemessage [regsub -all {%value} $ioNJ(sample_copyright) $second]}
			  "Movie name" { set g_movie_name $second        ; append samplemessage [regsub -all {%value} $ioNJ(sample_moviename) $second]}
			  "Performer"  { set g_performer $second         ; append samplemessage [regsub -all {%value} $ioNJ(sample_performer) $second]}
			  "Format" { set g_format $second                ; append samplemessage [regsub -all {%value} $ioNJ(sample_format) $second]}
			  "Bit rate" { set g_bitrate $second             ; append samplemessage [regsub -all {%value} $ioNJ(sample_bitrate) $second]}
			  "Writing application" { set g_writeapp $second ; append samplemessage [regsub -all {%value} $ioNJ(sample_writeapp) $second]}
			  "Writing library" { set g_writelib $second     ; append samplemessage [regsub -all {%value} $ioNJ(sample_writelib) $second]}
			}

		}
		if {$type == "a"} {
			switch -- $first {
			  "Format"            { set a_codec $second         ; append samplemessage [regsub -all {%value} $ioNJ(sample_audio_format) $second] }
			  "Format/Info"       { set a_codec_prof $second    ; append samplemessage [regsub -all {%value} $ioNJ(sample_audio_codecprofile) $second] }
			  "Bit rate"          { set a_bitrate $second       ; append samplemessage [regsub -all {%value} $ioNJ(sample_audio_bitrate) $second] }
			  "Bit rate mode"     { set a_bitrate_mode $second  ; append samplemessage [regsub -all {%value} $ioNJ(sample_audio_brmode) $second] }
			  "Channel(s)"        { set a_chans $second         ; append samplemessage [regsub -all {%value} $ioNJ(sample_audio_channels) $second] }
			  "Channel positions" { set a_chanpos $second       ; append samplemessage [regsub -all {%value} $ioNJ(sample_audio_chanpos) $second] }
			  "Sampling rate"     { set a_srate $second         ; append samplemessage [regsub -all {%value} $ioNJ(sample_audio_samprate) $second] }
			  "Writing library"   { set a_WriteLib $second      ; append samplemessage [regsub -all {%value} $ioNJ(sample_audio_writelib) $second] }
			  "Resolution"        { set a_res $second           ; append samplemessage [regsub -all {%value} $ioNJ(sample_audio_res) $second]}
			}

		}

		if {$type == "v"} {
			switch -- $first {
			  "Scan type"                   { set v_codec_scantype $second     ; append samplemessage [regsub -all {%value} $ioNJ(sample_video_scantype) $second] }
			  "Muxing mode"                 { set v_codec_mm $second           ; append samplemessage [regsub -all {%value} $ioNJ(sample_video_muxmode) $second] }
			  "Format"                      { set v_codec_info $second         ; append samplemessage [regsub -all {%value} $ioNJ(sample_video_format) $second] }
			  "Format/Info"                 { set v_codec_family $second       ; append samplemessage [regsub -all {%value} $ioNJ(sample_video_formatinfo) $second] }
			  "Format settings, Packed"        { set v_codec_pack $second         ; append samplemessage [regsub -all {%value} $ioNJ(sample_video_pack) $second] }
			  "Format settings, BVOP"         { set v_codec_bvop $second         ; append samplemessage [regsub -all {%value} $ioNJ(sample_video_bvop) $second] }
			  "Format settings, CABAC"      { set v_codec_cabac $second        ; append samplemessage [regsub -all {%value} $ioNJ(sample_video_cabac) $second] }
			  "Format settings, ReFrames"   { set v_codec_reframes $second     ; append samplemessage [regsub -all {%value} $ioNJ(sample_video_ReFrames) $second] }
			  "Format settings, QPel"         { set v_codec_qpel $second         ; append samplemessage [regsub -all {%value} $ioNJ(sample_video_qpel) $second] }
			  "Format settings, GMC"          { set v_codec_gmc $second          ; append samplemessage [regsub -all {%value} $ioNJ(sample_video_gmc) $second] }
			  "Format settings, Matrix"        { set v_codec_matrix $second       ; append samplemessage [regsub -all {%value} $ioNJ(sample_video_matrix) $second] }
			  "Codec"                       { set v_codec_info $second              ; append samplemessage [regsub -all {%value} $ioNJ(sample_video_codec) $second] }
			  "Width"	                	{ set v_width [string trim [regsub -all -nocase { pixels| } $second {}]]  ; append samplemessage [regsub -all {%value} $ioNJ(sample_video_width) [string trim [regsub -all -nocase { |pixels} $second {}]]] }
			  "Height"                      { set v_height [string trim [regsub -all -nocase { pixels| } $second {}]]  ; append samplemessage [regsub -all {%value} $ioNJ(sample_video_height) [string trim [regsub -all -nocase { |pixels} $second {}]]] }
			  "Display aspect ratio"        { set v_ar $second                 ; append samplemessage [regsub -all {%value} $ioNJ(sample_video_aspect) [regsub -all { } $second {;}]] }
			  "Bit rate"                    { set v_br $second                 ; append samplemessage [regsub -all {%value} $ioNJ(sample_video_bitrate) $second] }
			  "Frame rate"                  { set v_fr $second                 ; append samplemessage [regsub -all {%value} $ioNJ(sample_video_framerate) $second] }
			  "Format profile"              { set v_fp $second                 ; append samplemessage [regsub -all {%value} $ioNJ(sample_video_formatprof) $second] }
			  "Format settings, ReFrames"   { set v_rf $second                 ; append samplemessage [regsub -all {%value} $ioNJ(sample_video_resframes) $second] }
			  "Codec ID"                    { set v_codec $second                 ; append samplemessage [regsub -all {%value} $ioNJ(sample_video_codecid) $second] }
			  "Standard"                    { set v_standard $second           ; append samplemessage [regsub -all {%value} $ioNJ(sample_video_standard) $second] }
			  "Interlacement"               { set v_interlace $second          ; append samplemessage [regsub -all {%value} $ioNJ(sample_video_interlace) $second] }
			  "Resolution"                  { set v_resolution $second         ; append samplemessage [regsub -all {%value} $ioNJ(sample_video_resolution) $second] }
			  "Chroma"						{ set v_chroma [regsub -all " " $second ":"]   ; append samplemessage [regsub -all {%value} $ioNJ(sample_video_chroma) $second] }
			  "Writing library"				{ set w_writelib $second           ; append samplemessage [regsub -all {%value} $ioNJ(sample_video_writelib) $second] }
			}
		}
		
		if {$type == "t"} {
			switch -- $first {
			  "Language"                   { append samplemessage "$ioNJ(sample_text_head)" ; set t_codec_lang $second     ; append samplemessage [regsub -all {%value} $ioNJ(sample_text_lang) "$second"] }
			}
		}

	}

	append samplemessage $ioNJ(sample_footer)

	set samplemessage [string map "%ioNiNJA_VER $ioNJ(VER)" $samplemessage]

	set exchange [regexp -all -inline {%fm([\-]?)([0-9]+)\{([^\{\}]+)\}} $samplemessage]
	foreach {crap 1 2 replacing} $exchange {
		if {![string is integer -strict $2]} { continue }
			if {[string length $replacing] > $2} { 
				set replace [string range $replacing 0 [expr $2 - 1]] 
			} else { 
				set replace $replacing
			}
		   
		set samplemessage [string map [list "%fm$1$2\{$replacing\}" [format %${1}${2}s "$replace"]] $samplemessage]
	}




	if {![info exists g_format]} {
	 if {[info exists v_codec]} {
		set g_format $v_codec
	 } else {
		set g_format "default"
	 }

	}
	if {$a_chans == "2 channels" && $a_chanpos == "N/A" } { set a_chanpos "L R" }


	if {![file exists [resolve pwd $pwd]/.ioFTPD.message] && [regexp -nocase {/sample/} $pwd]} { 
		writefile $path/.ioFTPD.message "$samplemessage" 
		catch {file attributes "$path/.ioFTPD.message" -hidden 1}
	}

	if {$ioNJ(samplebar) != ""} {
		set samplebar [string map [list %sitename $ioNJ(ssn) %vcodec $v_codec %vframerate $v_fr  %vbitrate $v_br  %vheight $v_height  %vwidth $v_width  %var $v_ar  %acodec $a_codec %abrmode $a_bitrate_mode %abitrate $a_bitrate %achans $a_chans %asamplerate $a_srate %ares $a_res] $ioNJ(samplebar)]
		regsub -all {\\|:|\*|\?|\"|\<|\>|\|} $samplebar {} samplebar
		regsub -all {/} $samplebar {;} samplebar
		set sampletags [list "[file join $path $samplebar]"]
		if {[regexp -nocase {/sample/} $pwd] && $ioNJ(sample_bar_parent) != 0} {
			lappend sampletags "[file join [file dirname $path] $samplebar]"
		}

		foreach sampletag $sampletags {
			if {![file exists "$sampletag"]} { 
				if {$ioNJ(sampletype)} {
					set outfile [open "$sampletag" w]
					close $outfile
					vfs flush $path  
					catch {vfs write "$sampletag" $uid $gid 777} error 
					vfs flush $path 
				} else {
					catch {file mkdir "$sampletag"}
					catch {vfs write "$sampletag" $uid $gid 777} error
					vfs flush $path
				}
			} 
		
		}
	}

	if {[regexp -nocase "/sample" $pwd]} {
		if {[string match -nocase "*AVI*" $g_format]} {
			put_log "SAMPLE_AVI: [list $pwd [resolve uid $uid] [resolve gid $gid] $v_codec $v_fr $v_br $v_height $v_width $v_ar $v_resolution $w_writelib $v_chroma $v_interlace $v_codec_matrix $v_codec_gmc $v_codec_pack $v_codec_qpel $v_codec_bvop $a_codec $a_bitrate $a_bitrate_mode $a_chans $a_srate $a_res $a_codec_prof $a_WriteLib $a_chanpos]"
		} elseif {[string match -nocase "*Windows Media*" $g_format]} {
			put_log "SAMPLE_WMV: [list $pwd [resolve uid $uid] [resolve gid $gid] $v_codec $v_br $v_height $v_width $v_ar $v_resolution $a_codec $a_bitrate $a_chans $a_srate]"
		} elseif {[string match -nocase "*MPEG-1*" $g_format]} {
			put_log "SAMPLE_MPEG: [list $pwd [resolve uid $uid] [resolve gid $gid] $v_codec $v_fr $v_br $v_height $v_width $v_ar $v_interlace $v_codec_matrix $a_codec $a_bitrate $a_bitrate_mode $a_chans $a_srate $a_res $a_WriteLib $a_chanpos]"
		} elseif {[string match -nocase "*MPEG-2*" $g_format]} {
			put_log "SAMPLE_MPEG2: [list $pwd [resolve uid $uid] [resolve gid $gid] $v_codec $v_fr $v_br $v_height $v_width $v_ar $v_interlace $v_standard $a_codec $a_bitrate $a_bitrate_mode $a_chans $a_srate $a_chanpos]"
		} elseif {[string match -nocase "*Matroska*" $g_format]} {
			put_log "SAMPLE_MATROSKA: [list $pwd [resolve uid $uid] [resolve gid $gid] $g_bitrate $v_codec $v_fr $v_height $v_width $v_ar $a_codec $a_chans $a_srate $a_chanpos]"
		} elseif {[string match -nocase "*RealVideo*" $g_format]} {
			put_log "SAMPLE_REAL: [list $pwd [resolve uid $uid] [resolve gid $gid] $v_codec $v_fr $v_br $v_height $v_width $v_ar $v_resolution $v_ar $a_codec $a_bitrate $a_chans $a_res]"
		} elseif {[string match -nocase "*QuickTime*" $g_format]} {
			put_log "SAMPLE_QT: [list $pwd [resolve uid $uid] [resolve gid $gid] $v_codec $v_fr $v_br $v_height $v_width $v_ar $a_codec $a_bitrate $a_chans $a_srate $a_res]"
		} else {
			put_log "SAMPLE_GENERAL: [list $pwd [resolve uid $uid] [resolve gid $gid] $v_codec $v_fr $v_br $v_height $v_width $v_ar $a_codec $a_bitrate $a_bitrate_mode $a_chans $a_srate $a_res]"
		}
			vfs chattr [file dirname $path] 20 "[list $v_codec $v_fr $v_br $v_height $v_width $v_ar $a_codec $a_bitrate $a_bitrate_mode $a_chans $a_srate $a_res]"
			output $samplemessage
	} else {
		vfs chattr $path 20 "[list $v_codec $v_fr $v_br $v_height $v_width $v_ar $a_codec $a_bitrate $a_bitrate_mode $a_chans $a_srate $a_res]"
	}

	symlink_proc sample 0
	return
}


proc ::ioNiNJA::get_files {dir pattern} {return [glob -nocomplain -type f -directory $dir $pattern]}
proc ::ioNiNJA::get_dirs  {dir pattern} {return [glob -nocomplain -type d -directory $dir $pattern]}
proc ::ioNiNJA::get_dirs_time {dir pattern} { 
	set newdirs ""
	set dirs [glob -nocomplain -type d -directory "$dir" "$pattern"] 
	foreach dir $dirs {
		if {[set temptime [vfs chattr $dir 11]] == ""} {
				set temptime [file mtime $dir]
		}
	  	lappend newdirs "$temptime $dir"
  	}
	unset dirs 
	return [lsort -increasing -integer -index 0 "$newdirs"]
}

proc ::ioNiNJA::get_total_size {dir} { 

	set dirs $dir
	set new_dirs ""
	set nr 0
	set size 0
	while {[lindex $dirs $nr] != ""} {
	  	set temp [glob -nocomplain -directory [lindex $dirs $nr] "*"]
		
	 	if {$temp != ""} {
	  	   foreach dir $temp {
	  	   	if {[file isdirectory $dir]} {
	   		   	lappend new_dirs "$dir"
	   		} else {
	   			set size [format %.0f [expr ($size + ([file size $dir] / 1048576.0)) * 1.0]]
	   		}
	   		
	   	   }
	 	}
	  incr nr
	}
	return $size
}
proc ::ioNiNJA::get_file_name {} {global path

	set fname ""
	
	set rarfname [lindex [get_files $path {*{.rar,.001}}] 0]
	
	if {$rarfname != ""} {
		if {[catch {set fname [exec -- ../scripts/ioNiNJA/MiSC/unrar.exe lb [string map "/ \\" $rarfname]]} error]} {
			set fname ""
		} else {
			set fname [file rootname $fname]
		}
	}

	
	if {$fname == ""} {
		set fname [file rootname [lindex [get_files $path {*{.mkv,.avi,.asf,.m2v,.mpg,.mpeg,.divx,.wmv,.mp4,.img,.iso,.bin,.rar,.001}}] 0]]
		if {$fname == ""} { 
			set fname [file rootname [lindex [get_files $path {*{.nfo,.sfv}}] 0]]
			if {$fname == ""} { 
				set fname [lindex [file split $path] end]
			}
		}
	} 
	
	return $fname
}

#######################
# get time vars
#######################

proc ::ioNiNJA::get_time {time} {
	set return [clock format $time -format "%%a %a %%A %A %%b %b %%B %B %%C %C %%d %d %%e %e %%g %g %%G %G %%h %h %%I %I %%j %j %%k %k %%l %l %%m %m %%M %M %%p %p %%u %u %%U %U %%V %V %%w %w %%W %W %%y %y %%Y %Y"]
}


#######################
# get time vars
#######################

proc ::ioNiNJA::get_sorted_time {dirs} {
	set return_dirs ""
	
	foreach dir $dirs {
		lappend return_dirs [list $dir [file mtime $dir]]
	}
	
	return [lsort -increasing -integer -index 1 "$return_dirs"]
}

#######################
## Output to ftpd
#######################

proc ::ioNiNJA::output {message} {global ioNJ
	regsub -all %ioNiNJA_VER $message $ioNJ(VER) message
	foreach line [split [string trim $message] \n]  { 
		iputs -nobuffer "$line" 
	}
}


proc ::ioNiNJA::output2 {message} {global ioNJ
	regsub -all %ioNiNJA_VER $message $ioNJ(VER) message
	foreach line [split [string trim $message] \n]  { 
		iputs "$line" 
	}
}

proc ::ioNiNJA::outstat {message} {global ioNJ
	regsub -all %ioNiNJA_VER $message $ioNJ(VER) message
	foreach line [split [string trim $message] \n]  { 
		iputs "250- $line" 
	}
	iputs "250 Command sucessful"
}

proc ::ioNiNJA::outputerror {message} {global ioNJ
	regsub -all %ioNiNJA_VER $message $ioNJ(VER) message
	foreach line [split [string trim $message] \n]  { 
		iputs "$line" 
	}
	iputs "550 Command sucessful"
}
proc ::ioNiNJA::outputsite {message} {global ioNJ
	regsub -all %ioNiNJA_VER $message $ioNJ(VER) message
	foreach line [split [string trim $message] \n]  { 
		iputs "$line" 
	}
}



#######################
## Format Size
#######################

proc ::ioNiNJA::format_size {amount} {
	foreach dec {0 0 1 2 2 2} unit {KB MB GB TB PB EB} {
		if {abs($amount) >= 1024} {
			set amount [expr $amount / 1024.0]
		} else {break}
	}
	return [format "%.*f%s" $dec $amount $unit]
}


#######################
## Format Speed
#######################
proc ::ioNiNJA::format_speed {value} {
	if {$value > 1024 } {
		set value [format "%.1f" [expr {$value / 1024.0}]]
		set type "MB/s"
	} else {
		set value [format "%.1f" [expr $value * 1.0]]
		set type "KB/s"
	}
return "$value$type"
}

#######################
## Read File
#######################

proc ::ioNiNJA::readfile {file} {
	if {![file exists $file]} {return ""}
	set openfile [open $file r]
	set fileread [read $openfile]
	close $openfile
	unset -nocomplain openfile
	return $fileread
}



#######################
## Write File
#######################


proc ::ioNiNJA::writefile {file text} {
	set openfile [open $file w]
	puts $openfile $text
	close $openfile
	unset openfile
	return 0
}

#######################
## Append to file
#######################

proc ::ioNiNJA::appendfile {file text} {
	set openfile [open $file a+]
	puts $openfile "$text"
	close $openfile
	return 0
}


##
# Check if something is binary
##
proc ::ioNiNJA::bin_ary {data} {
 return [string trim [expr {[string first \x00 $data]>=0}]]
}

proc ::ioNiNJA::save_fanart {url} { global ioNJ path pwd
        if {![regexp -nocase {http://} $url]} { set url "https://${url}" }
		if {[regexp -nocase { } [string trim $url]]} { return "" }
		if {![regexp -nocase {http://} $url]} { set url "https://${url}" }
		set CurlLine [GetCurlLine]
        catch {eval exec -- ../scripts/ioNiNJA/MiSC/curl.exe -m 30 $CurlLine "$url" --output \"[file join $path fanart.jpg]\"} error
        return
}

proc ::ioNiNJA::save_pic {url} { global ioNJ path pwd
        if {![regexp -nocase {http://} $url]} { set url "https://${url}" }
		set CurlLine [GetCurlLine]
        catch {eval exec -- ../scripts/ioNiNJA/MiSC/curl.exe -m 30 $CurlLine "$url" --output \"[file join $path folder.jpg]\"} error
        return
}

proc ::ioNiNJA::save_pic_custom {url pic} { global ioNJ path
        if {![regexp -nocase {http://} $url]} { set url "https://${url}" }
		if {$pic == ""} { return }
		set CurlLine [GetCurlLine]
        catch {eval exec -- ../scripts/ioNiNJA/MiSC/curl.exe -m 30 $CurlLine "$url" --output \"$pic\"} error
        return
}

proc ::ioNiNJA::GetCurlLine {} {global ioNJ
          switch -- $ioNJ(curl_proxy_type) {
			0 {	return "--user-agent \"Mozilla/4.0 (compatible\; MSIE 5.01\; Windows NT 5.0)\"" }
			1 { return "--socks4 $ioNJ(curl_proxy)--user-agent \"Mozilla/4.0 (compatible\; MSIE 5.01\; Windows NT 5.0)\"" }
			2 { return "--socks4a $ioNJ(curl_proxy) --user-agent \"Mozilla/4.0 (compatible\; MSIE 5.01\; Windows NT 5.0)\"" }
			3 { return  "--socks5-hostname $ioNJ(curl_proxy) --user-agent \"Mozilla/4.0 (compatible\; MSIE 5.01\; Windows NT 5.0)\"" }
			4 { if {$ioNJ(curl_user_pass) != ""} {
					return  "-U $ioNJ(curl_user_pass) -x $ioNJ(curl_proxy) --user-agent \"Mozilla/4.0 (compatible\; MSIE 5.01\; Windows NT 5.0)\""
				} else {
					return  "-x $ioNJ(curl_proxy) --user-agent \"Mozilla/4.0 (compatible\; MSIE 5.01\; Windows NT 5.0)\""
				}
			}
			5 { return  "--socks5 $ioNJ(curl_proxy) --user-agent \"Mozilla/4.0 (compatible\; MSIE 5.01\; Windows NT 5.0)\"" }
		}
}


#######################
## Write Chattr
#######################

proc ::ioNiNJA::writechattr {raceinfo info} { global args pwd path
	set newcell 0
	set maxbytes 3499
	if {[string length $info] <= $maxbytes } {  catch {vfs chattr $path $raceinfo "$info"}  ; return }
	while {[set temp [string range $info $newcell [expr $newcell + $maxbytes]]] != ""} {
		set newcell [expr $newcell + $maxbytes + 1]
		catch {vfs chattr $path $raceinfo "$temp"}
		incr raceinfo
	}
   return
}


#######################
## Read Chattr
#######################

proc ::ioNiNJA::readchattr {x} { global args pwd path
       set maxbytes 3499
       set new [vfs chattr $path $x]
       if {[string length $new] <= $maxbytes} { return $new }
       incr x
       while {[set info [vfs chattr $path $x]] != ""} {
        	 append new $info
        	 incr x
        	 if {[string length $info] <= $maxbytes} { 
        	 	return $new 
        	 }
        	 
        }
	
 return $new
}

proc ::ioNiNJA::erasechattr {x} { global args pwd path
        while {[vfs chattr $path $x] != ""} {
        	catch {vfs chattr $path $x ""} error
        	incr x
        }
 return
}


#######################
## Read Chattr Parent
#######################

proc ::ioNiNJA::readparentchattr {x} { global args pwd path
	set p2 [file dirname $path]
	set maxbytes 1999
        set new [vfs chattr $p2 $x]
        if {[string length $new] <= $maxbytes} { return $new }
        incr x
        while {[set info [vfs chattr $p2 $x]] != ""} {
        	 append new $info
        	 incr x
        	 if {[string length $info] <= $maxbytes} { 
        	 	return $new 
        	 }
        }
	
 return $new
}


#######################
## putlog
#######################

proc ::ioNiNJA::put_log {text} {
	catch {set openfile [open ../logs/ioftpd.log a+]}
	catch {puts $openfile "[clock format [clock seconds] -format "%m-%d-%Y %H:%M:%S"] $text"}
	catch {close $openfile}
	return 0
}
proc ::ioNiNJA::put_log_err {text} {
	catch {set openfile [open ../logs/ioNiNJA.log a+]}
	catch {puts $openfile "[clock format [clock seconds] -format "%m-%d-%Y %H:%M:%S"] $text"}
	catch {close $openfile}
	return 0
}


#######################
## Add Genres
#######################

proc ::ioNiNJA::ADDGENRES {} {global ioNJ
	
	foreach genre $ioNJ(genres) {
		catch {group delete $genre}
		regsub -all " " $genre "_" genre
		catch {group create $genre} temp
	}
	output "250- All Genres added as GROUPS - OK"
}

proc ::ioNiNJA::ADDGROUPSTATUS {} {global ioNJ
	foreach genre {INCOMPLETE COMPLETE NO_NFO NO_SAMPLE OVERSIZED NO_SFV NO_DIZ EMPTY} {
		catch {group delete $genre}
		regsub -all " " $genre "_" genre
		catch {group create $genre} temp
	}
	output "250- Release Status added as GROUPS - OK"
}


proc ::ioNiNJA::INVITE {} { global uid gid args
	set nick [lindex $args 1]
	set user [resolve uid $uid]
	set group [resolve gid $gid]
	set flags [get_uinfo $user flags]
	
	if {$nick == ""} { 
		output "INVITE ERROR: No nick specified" 
		return 
	}
	
	put_log "INVITE: [list $nick $user $group $flags]"
	output "250- \"$nick\" was invited to join our chan(s)"
}

proc ::ioNiNJA::IRC_FingerprintFormat {value} {
	set clean [string toupper [string map {":" "" " " "" "-" ""} [string trim $value]]]
	if {![regexp {^[0-9A-F]+$} $clean]} { return "" }
	if {$clean == ""} { return "" }
	set parts {}
	for {set i 0} {$i < [string length $clean]} {incr i 2} {
		lappend parts [string range $clean $i [expr {$i + 1}]]
	}
	return [join $parts ":"]
}

proc ::ioNiNJA::IRC_StatusHash {status} {
	set sha1 ""
	set sha256 ""
	if {[catch {
		dict for {key value} $status {
			set cleanKey [string tolower [string map {" " "" "_" "" "-" ""} $key]]
			set formatted [IRC_FingerprintFormat $value]
			if {$formatted == ""} { continue }
			if {$cleanKey in {sha256hash sha256fingerprint certsha256}} {
				set sha256 $formatted
			} elseif {$cleanKey in {sha1hash sha1fingerprint certsha1}} {
				set sha1 $formatted
			}
		}
	}]} {
		return ""
	}

	if {$sha256 != ""} { return "SHA256 $sha256" }
	if {$sha1 != ""} { return "SHA1 $sha1" }
	return ""
}

proc ::ioNiNJA::IRC_Fingerprint {} { global ioNJ
	if {[info exists ioNJ(irc_fingerprint)] && [string trim $ioNJ(irc_fingerprint)] != ""} {
		set configured [IRC_FingerprintFormat $ioNJ(irc_fingerprint)]
		if {$configured != ""} { return $configured }
		return $ioNJ(irc_fingerprint)
	}

	if {![info exists ioNJ(irc_host)] || ![info exists ioNJ(irc_port)]} {
		return "unavailable: irc_host/irc_port not configured"
	}

	set host [string trim $ioNJ(irc_host)]
	set port [string trim $ioNJ(irc_port)]
	if {[string index $port 0] != "+"} {
		return "unavailable: IRC port is not SSL/TLS"
	}
	set port [string range $port 1 end]

	if {[catch {package require tls} error]} {
		return "unavailable: Tcl tls package missing: $error"
	}

	set sock ""
	set result ""
	if {[catch {
		if {[catch {set sock [::tls::socket -autoservername 1 -require 0 $host $port]}]} {
			set sock [::tls::socket -require 0 $host $port]
		}
		fconfigure $sock -blocking 1 -buffering line -translation crlf -encoding iso8859-1
		::tls::handshake $sock
		set status [::tls::status $sock]
		close $sock
		set sock ""
		set fingerprint [IRC_StatusHash $status]
		if {$fingerprint != ""} {
			set result $fingerprint
		} else {
			set result "unavailable: connected, no certificate hash returned"
		}
	} error]} {
		catch {close $sock}
		return "unavailable: $error"
	}

	return $result
}


proc ::ioNiNJA::IRC {} { global ioNJ
	output "\[ SITE IRC \]-------------------------------------------------------------------"
	output "| Do not share with other people!"
	output "| Users that are welcome on ircd are those who can access \"site irc\""
	output "|"
	output "| IRC host             port(ssl)       password"
	output [format "|     %-20s %-15s %s" $ioNJ(irc_host) $ioNJ(irc_port) $ioNJ(irc_password)]
	output "|"
	output "| Cert fingerprint: [IRC_Fingerprint]"
	output "|"
	output "| IRC Blowfish:"
	foreach channel $ioNJ(irc_blowfish) {
		output "|  /setkey $channel"
	}
	output "|______________________________________________________________________________|"
}


proc ::ioNiNJA::CWD {} { global path pwd uid gid args ioNJ


	if { [readchattr 3] != "1" } { return }


	if {!$ioNJ(show_complete_message)} { return }
	
	  if {[set complete [vfs chattr $path 9]] != 1} { 
	 	if {[set imdb [readchattr 30]] != ""} {
	 		if {[lindex $imdb 0] == "0" || [lindex $imdb 0] == "1"} {
				set sample        [readchattr 20]
				set message "$ioNJ(message_header_plain)"
				if {[lindex $imdb 0] == "1"} {
					set imdb [lrange $imdb 1 end]
					set replacevar " %tv_showname {[lindex $imdb 0]} %tv_season {[lindex $imdb 1]} %tv_episodenr {[lindex $imdb 2]} %tv_epdirector {[lindex $imdb 3]} %tv_epname {[lindex $imdb 4]} %tv_epfirstaired {[lindex $imdb 5]} %tv_epplot {[lindex $imdb 6]} %tv_eprating {[lindex $imdb 7]} %tv_epwriter {[lindex $imdb 8]} %tv_show_overview {[lindex $imdb 9]} %tv_show_runtime {[lindex $imdb 10]} %tv_show_status {[lindex $imdb 11]} %tv_show_rating {[lindex $imdb 12]} %tv_show_actors {[lindex $imdb 13]} %tv_show_airday {[lindex $imdb 14]} %tv_show_airtime {[lindex $imdb 15]}  %tv_show_premiere {[lindex $imdb 16]} %tv_show_genre {[lindex $imdb 17]} %tv_show_network {[lindex $imdb 18]} %tv_show_url {[lindex $imdb 19]}"
					append message "$ioNJ(message_tvinfo)"
				} elseif {[lindex $imdb 0] == "0"} {
					set imdb [lrange $imdb 1 end]
					set replacevar "%imdb_title {[lindex $imdb 0]} %imdb_url {[lindex $imdb 1]} %imdb_year {[lindex $imdb 2]} %imdb_tv {[lindex $imdb 3]} %imdb_lifetime {[lindex $imdb 4]} %imdb_ratbar {[lindex $imdb 5]} %imdb_rating {[lindex $imdb 6]} %imdb_votes {[lindex $imdb 7]} %imdb_director {[lindex $imdb 8]} %imdb_cast {[lindex $imdb 9]} %imdb_mpaa {[lindex $imdb 10]} %imdb_country {[lindex $imdb 11]} %imdb_language {[lindex $imdb 12]} %imdb_genre {[lindex $imdb 13]} %imdb_tagline {[lindex $imdb 14]} %imdb_plot {[lindex $imdb 15]}  %imdb_opengross {[lindex $imdb 16]} %imdb_opencountry {[lindex $imdb 17]} %imdb_openday {[lindex $imdb 18]} %imdb_openyear {[lindex $imdb 19]} %imdb_openscreens {[lindex $imdb 20]} %imdb_screens {[lindex $imdb 21]} %imdb_budget {[lindex $imdb 22]} %imdb_top250 {[lindex $imdb 23]} %imdb_limited {[lindex $imdb 24]} %imdb_company {[lindex $imdb 25]} %imdb_runtime {[lindex $imdb 26]}"
					append message 	"$ioNJ(message_imdbinfo)"
				}
				if {$sample != ""} {  	
					append message 	"$ioNJ(message_sample)"
					append replacevar " %video_codec {[lindex $sample 0]} %video_framerate {[lindex $sample 1]} %video_bitrate {[lindex $sample 2]} %video_height {[lindex $sample 3]} %video_width {[lindex $sample 4]} %video_aspect_ratio {[lindex $sample 5]} %video_audio_codec {[lindex $sample 6]} %video_audio_bitrate_mode {[lindex $sample 8]} %video_audio_bitrate {[lindex $sample 7]}  %video_audio_chans {[lindex $sample 9]} %video_audio_samplerate {[lindex $sample 10]} %video_audio_resolution {[lindex $sample 11]}"
				}

				append message 	"$ioNJ(message_footer)"
				## Change variables in messages
				set message [string map $replacevar $message]
				#
				set exchange [regexp -all -inline {%fm([\-]?)([0-9]+)\{([^\{\}]+)\}} $message]
				foreach {crap 1 2 replacing} $exchange {
					if {![string is integer -strict $2]} { continue }
				        if {[string length $replacing] > $2} { 
				        	set replace [string range $replacing 0 [expr $2 - 1]] 
				        } else { 
				        	set replace $replacing
				        }   
					set message [string map [list "%fm$1$2\{$replacing\}" [format %${1}${2}s "$replace"]] $message]
				}
				outstat $message
			}
	  	} 
		return
	  }
	  set make_time     [vfs chattr $path 11]
	  set release_type  [vfs chattr $path 12]
	  set total_files   [vfs chattr $path 13]
	  set sfv			[join [readchattr 35]]
	  set racestats     [readchattr 50]
	  set present_files 0
	  set sample        [readchattr 20]
	  set extrainfo     [readchattr 25]
      set extrainfo2    [readchattr 26]
	  set imdb			[readchattr 30]
	  set total_size    0
	  set total_speed   0
	  set time          [vfs chattr $path 5]
	  set user          [resolve uid $uid]
	  set ugroup        [resolve gid $gid]
	  set tagline       [get_uinfo $user tagline]
	  set dir           [lindex [file split $pwd] end]
	  set groupusers    ""
	  set replacevar    ""
	  set racers        ""
	  set groups        ""
	  set groupusers    ""
	  set totalracers   ""
	  set totalgroups   ""
	  
	  if {$make_time == ""} { return }
	  
	  if {$time == ""} { 
	  	set time [expr $make_time + 100]
	  	catch {vfs chattr $path 5 $time} 
	  }
	  
	  	#sort users and groups.
	  	foreach f_stat [resolve list "$pwd"] {
			lassign $f_stat io_fname io_type io_uid io_user io_gid io_group io_fsize mode attributes win-last-time unix-last-time win-alt-time unix-alt-time subdir-count rlink chatt uptime
			if {$io_fsize == 0  || ![string match -nocase "*$io_fname*" $sfv] || $io_fname == "."} { continue }
			incr present_files
			if {$uptime == 0} { set uptime 1 }
			if { [set io_speed [expr $io_fsize/$uptime]] == 0 } { set io_speed 1}
	  		if {[set race_idx [lsearch -glob $racers $io_user]] == "-1"} { 
	  			lappend racers $io_user
	  			lappend groupusers [list $io_user $io_group]
	  			lappend total_racers "$io_user $io_group [format %.0f [expr ($io_fsize /1024.0)]] $io_speed 1 [expr 100 / $present_files]"
	  		} else {
	  			set temp [lindex $total_racers $race_idx]
	  			set temp_files [expr [lindex $temp 4] + 1]
	  			set temp_size  [format %.0f [expr [lindex $temp 2] * 1.0 + ($io_fsize /1024.0)]]
	  			set temp_speed [format %.0f [expr ([lindex $temp 3] + $io_speed) / 2]]
	  			set temp_percent [expr ($temp_files * 100) / $present_files]
	  			set total_racers [lreplace $total_racers $race_idx $race_idx "$io_user $io_group $temp_size $temp_speed $temp_files $temp_percent"]
	  		}
	  		
	  		if {[set g_race_idx [lsearch -glob $groups $io_group]] == "-1"} { 
	  			lappend groups $io_group
	  			lappend total_groups "$io_group [format %.0f [expr ($io_fsize /1024.0)]] $io_speed 1 [expr 100 / $present_files]"
	  		} else {
	  			set temp [lindex $total_groups $g_race_idx]
	  			set temp_files [expr [lindex $temp 3] + 1]
				set temp_size  [format %.0f [expr [lindex $temp 1] * 1.0 + ($io_fsize /1024.0)]]
				set temp_speed [format %.0f [expr ([lindex $temp 2] + $io_speed) / 2]]
	  			set temp_percent [expr ($temp_files * 100) / $present_files]
	  			set total_groups [lreplace $total_groups $g_race_idx $g_race_idx "$io_group $temp_size $temp_speed $temp_files $temp_percent"]
	  		}
	  	
	  		set total_size  [format %.0f [expr $total_size * 1.0 + ($io_fsize /1024.0)]]
			set total_speed [expr $total_speed + $io_speed]
	  	}

	  	if {![info exists total_racers]} { return }
		
	  	set temp_new_race_stats [lsort -decreasing -integer -index 2 "$total_racers"]

	  	set rtop 0
	  	foreach race_stat $temp_new_race_stats {
	  		incr rtop
	  		lappend totalracers "$rtop [lindex $race_stat 0] [lindex $race_stat 1] [lindex $race_stat 2] [lindex $race_stat 3] [lindex $race_stat 4] [lindex $race_stat 5]"
	 	 }
	
		set temp_new_race_stats [lsort -decreasing -integer -index end-3 "$total_groups"]
	  	set gtop 0
	  	foreach race_stat $temp_new_race_stats {
	  		incr gtop
	  		lappend totalgroups "$gtop [lindex $race_stat 0] [lindex $race_stat 1] [lindex $race_stat 2] [lindex $race_stat 3] [lindex $race_stat 4]"
	 	 }
	
	
	
		# get dirname and change it if it's a subdir. Mostley for announce purpose but also for groupname
				
		if {[regexp -nocase  $ioNJ(notparent) $dir]} {
			set sample [readparentchattr 20]
			set extrainfo [readparentchattr 25]
			set parent [lindex [file split $pwd] end-1]
			set subdir ${dir}
			set dir "${parent}"
	   	}
		
		lassign [get_stats] racer_dayup racer_wkup racer_mnup racer_allup
		set temp_racestats ""
		foreach race_stat $totalracers {
		    set dayup [expr [lsearch -glob $racer_dayup "[lindex $race_stat 1] *"] + 1]
			set wkup  [expr [lsearch -glob $racer_wkup "[lindex $race_stat 1] *"] + 1]
			set mnup  [expr [lsearch -glob $racer_mnup "[lindex $race_stat 1] *"] + 1]
			set allup [expr [lsearch -glob $racer_allup "[lindex $race_stat 1] *"] + 1]
			lappend temp_racestats "$race_stat $dayup $wkup $mnup $allup"
		}
		
		set totalracers "$temp_racestats"
		set racestats [lsort -increasing -integer -index end-6 "$totalracers"] 
		lassign [lindex $racestats end] crap u_fastest_name u_fastest_gname crap u_fastest_speed
		lassign [lindex $racestats 0] crap u_slowest_name u_slowest_gname crap u_slowest_speed
		append replacevar " %u_slowest_name {$u_slowest_name} %u_slowest_gname {$u_slowest_gname} %u_slowest_speed {[format_speed $u_slowest_speed]} %u_fastest_name {$u_fastest_name} %u_fastest_gname {$u_fastest_gname} %u_fastest_speed {[format_speed  $u_fastest_speed]}"
			
	   
		# MP3INFO
		if {[lindex $extrainfo2 0] == "0"} { 	
			append replacevar " %audio_artist {[lindex $extrainfo2 5]} %audio_album {[lindex $extrainfo2 3]} %audio_title {[lindex $extrainfo2 end-1]} %audio_bitrate {[lindex $extrainfo2 2]} %audio_producer {[lindex $extrainfo2 6]} %audio_description {[lindex $extrainfo2 8]} %audio_genre {[lindex $extrainfo2 7]} %audio_year {[lindex $extrainfo2 4]} %audio_samplerate {[lindex $extrainfo2 15]} %audio_writeapp {[lindex $extrainfo2 10]} %audio_bitdepth {[lindex $extrainfo2 16]} %audio_language {[lindex $extrainfo2 17]} %audio_catalog {[lindex $extrainfo2 18]} %audio_duration {[lindex $extrainfo2 1]} %audio_riptool {[lindex $extrainfo2 19]} %audio_type {[lindex $extrainfo2 end]} %audio_channels {[lindex $extrainfo2 14]} %audio_media {[lindex $extrainfo2 13]} %audio_recorddate {[lindex $extrainfo2 9]} %audio_retail {[lindex $extrainfo2 12]} %audio_ripdate {[lindex $extrainfo2 11]}"
		} elseif {[lindex $extrainfo 0] == "0"} { 
			append replacevar " %audio_artist {[lindex $extrainfo 1]} %audio_album {[lindex $extrainfo 2]} %audio_title {[lindex $extrainfo 3]} %audio_bitrate {[lindex $extrainfo 4]} %audio_mpeglayer {MPEG [lindex $extrainfo 5] Layer [lindex $extrainfo 6]} %audio_chanmode {[lindex $extrainfo 7]} %audio_genre {[lindex $extrainfo 8]} %audio_year {[lindex $extrainfo 9]} %audio_samplerate {[lindex $extrainfo 10]} %audio_lame_version {[lindex $extrainfo 11]} %audio_lame_preset {[lindex $extrainfo 12]} %audio_original {[lindex $extrainfo 13]} %audio_padding {[lindex $extrainfo 14]} %audio_duration {[lindex $extrainfo 15]} %audio_track_nr {[lindex $extrainfo 16]} %audio_vbr_old_or_new {[lindex $extrainfo 18]} %audio_vbr {[lindex $extrainfo 17]}"
		} elseif {[lindex $extrainfo 0] == "3"} { 
			
		   append replacevar " %mv_genre {[lindex $extrainfo 1]} %mv_artist {[lindex $extrainfo 2]} %mv_year {[lindex $extrainfo 3]} %mv_title {[lindex $extrainfo 4]} %mv_group {[lindex $extrainfo 5]}"
		}
		#SAMPLE INFO
		  if {$sample != ""} {  	
		   	append replacevar " %video_codec {[lindex $sample 0]} %video_framerate {[lindex $sample 1]} %video_bitrate {[lindex $sample 2]} %video_height {[lindex $sample 3]} %video_width {[lindex $sample 4]} %video_aspect_ratio {[lindex $sample 5]} %video_audio_codec {[lindex $sample 6]} %video_audio_bitrate_mode {[lindex $sample 8]} %video_audio_bitrate {[lindex $sample 7]}  %video_audio_chans {[lindex $sample 9]} %video_audio_samplerate {[lindex $sample 10]} %video_audio_resolution {[lindex $sample 11]}"
		 }
		 #imdbinfo
		 if {[lindex $imdb 0] == "0"} {
			set imdb [lrange $imdb 1 end]
			append replacevar " %imdb_title {[lindex $imdb 0]} %imdb_url {[lindex $imdb 1]} %imdb_year {[lindex $imdb 2]} %imdb_tv {[lindex $imdb 3]} %imdb_lifetime {[lindex $imdb 4]} %imdb_ratbar {[lindex $imdb 5]} %imdb_rating {[lindex $imdb 6]} %imdb_votes {[lindex $imdb 7]} %imdb_director {[lindex $imdb 8]} %imdb_cast {[lindex $imdb 9]} %imdb_mpaa {[lindex $imdb 10]} %imdb_country {[lindex $imdb 11]} %imdb_language {[lindex $imdb 12]} %imdb_genre {[lindex $imdb 13]} %imdb_tagline {[lindex $imdb 14]} %imdb_plot {[lindex $imdb 15]}  %imdb_opengross {[lindex $imdb 16]} %imdb_opencountry {[lindex $imdb 17]} %imdb_openday {[lindex $imdb 18]} %imdb_openyear {[lindex $imdb 19]} %imdb_openscreens {[lindex $imdb 20]} %imdb_screens {[lindex $imdb 21]} %imdb_budget {[lindex $imdb 22]} %imdb_top250 {[lindex $imdb 23]} %imdb_limited {[lindex $imdb 24]} %imdb_company {[lindex $imdb 25]} %imdb_runtime {[lindex $imdb 26]}"
			set imdb 1
		} elseif {[lindex $imdb 0] == "1"} {
			set imdb [lrange $imdb 1 end]
			append replacevar " %tv_showname {[lindex $imdb 0]} %tv_season {[lindex $imdb 1]} %tv_episodenr {[lindex $imdb 2]} %tv_epdirector {[lindex $imdb 3]} %tv_epname {[lindex $imdb 4]} %tv_epfirstaired {[lindex $imdb 5]} %tv_epplot {[lindex $imdb 6]} %tv_eprating {[lindex $imdb 7]} %tv_epwriter {[lindex $imdb 8]} %tv_show_overview {[lindex $imdb 9]} %tv_show_runtime {[lindex $imdb 10]} %tv_show_status {[lindex $imdb 11]} %tv_show_rating {[lindex $imdb 12]} %tv_show_actors {[lindex $imdb 13]} %tv_show_airday {[lindex $imdb 14]} %tv_show_airtime {[lindex $imdb 15]}  %tv_show_premiere {[lindex $imdb 16]} %tv_show_genre {[lindex $imdb 17]} %tv_show_network {[lindex $imdb 18]} %tv_show_url {[lindex $imdb 19]}"
			set imdb 0
		}
		

		#Set the progressbar
		if {$present_files != 0 && $total_files != 0} {
			set progsigns [format %.0f [expr ($present_files * [string length $ioNJ(charbar_filled)])/$total_files]]
			if {$progsigns == 0} {
		  		set pbar $ioNJ(charbar_missing)
			} else {
				set pbar [string range $ioNJ(charbar_filled) 0 [expr $progsigns - 1]]
				set pbar "$pbar[string range $ioNJ(charbar_missing) $progsigns end]"
			}
	
		} else {
			set pbar $ioNJ(charbar_missing)
		}
	
	
	set durtimestamp [expr $time - $make_time]
	if {$durtimestamp == 0} { set durtimestamp 1 }
	set duration $durtimestamp
	set missingfiles [expr $total_files - $present_files]
	set percentdone [format %.1f [expr ((100.0 /$total_files) * $present_files)]]
	set percentleft [format %.1f [expr 100 - $percentdone]]
	set avgspeed [format %.0f [expr $total_size / $durtimestamp]]
	if {$avgspeed == 0} { set avgspeed 1 }
	set a_avgspeed [format %.0f [expr $total_size / $durtimestamp]]
	set r_avgspeed [expr $total_speed / $present_files]
	lassign [lindex $totalracers 0] crap u_winner_name  u_winner_gname u_winner_mbytes u_winner_avgspeed u_winner_files u_winner_percent
	lassign [lindex $totalgroups 0] crap g_winner_name g_winner_mbytes g_winner_avgspeed g_winner_files g_winner_percent
	set winner_idx [lsearch -glob $groupusers "$u_winner_name *"]
	set lead_groupusers [lreplace $groupusers $winner_idx $winner_idx]
	set user_idx   [lsearch -glob $groupusers "$user *"]
	set groupusers [lreplace $groupusers $user_idx $user_idx]
	set a_groupusers $groupusers
	if {$groupusers == ""} { set groupusers "NoOne NoGroup"}
	if {$total_files != $present_files } { set eta [format %.0f [expr (($total_size / $present_files) * $missingfiles) / $avgspeed]] } else { set eta 0 }
	set total_size [format %.0f $total_size]
	set esize [format %.0f [expr ($total_size / $present_files * [format %.1f $total_files])]]
	set tempesize [format %.0f [expr $esize / 1024.0]]
		
	
	append replacevar " %ioNiNJA_VER $ioNJ(VER) %sitename {$ioNJ(ssn)} %racers {$racers} %complete_eta \"[duration $eta]\" %percentdone {$percentdone} %rtop {$rtop} %gtop {$gtop} %release {$dir} %total_files {$total_files} %files_uploaded {$present_files} %missing_files {$missingfiles} %estimated_size [format_size $esize] %total_size \"[format_size $total_size]\" %average_speed \"[format_speed $a_avgspeed]\" %race_duration \"[duration $duration]\" %r_avg_speed \"[format_speed $r_avgspeed]\" %progress_bar {$pbar} %time {[clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]}"
	
	set message "$ioNJ(message_header)"
	if {$ioNJ(show_user_info)} {
		append message $ioNJ(message_user_header)
		foreach {rtop raceuser racegroup racesize racespeed racefiles racepercent dayup wkup mnup allup} [join $totalracers] {
			append message [string map [list %race_user_dayup $dayup %race_user_wkup $wkup %race_user_mnup $mnup %race_user_allup $allup %race_user_position $rtop %race_user_name $raceuser %race_user_group $racegroup %race_user_files $racefiles %race_user_size [format_size $racesize] %race_user_percent $racepercent %race_user_speed [format_speed $racespeed]] $ioNJ(message_user_body)]
		}
		append message "$ioNJ(message_user_footer)"
	}
	
	if {$ioNJ(show_group_info)} {
		append message "$ioNJ(message_group_header)"
		foreach {gtop rgroup gracesize gracespeed gracefiles gracepercent} [join $totalgroups] {
			append message [string map [list %race_group_position $gtop %race_group_name $rgroup %race_group_files $gracefiles %race_group_size [format_size $gracesize] %race_group_percent $gracepercent %race_group_speed [format_speed $gracespeed]] $ioNJ(message_group_body)]
		}
		append message 	"$ioNJ(message_group_footer)"
	}

	if {$sample != ""} {
		append message 	"$ioNJ(message_sample)"
	} 
	if {$imdb == "1"} {
		append message "$ioNJ(message_imdbinfo)"
	} elseif {$imdb == "0"} {
		append message "$ioNJ(message_tvinfo)"
	}
	if {[lindex $extrainfo2 0] == 0} {
		append message "$ioNJ(message_flac)"
	}
	if {[lindex $extrainfo 0] == 0} {
		append message "$ioNJ(message_mp3)"
	} elseif {[lindex $extrainfo 0] == 3} {
		append message 	"$ioNJ(message_mv)"
	}
	
	append message 	"$ioNJ(message_footer)"

	if {$ioNJ(custom_group_dirs_complete_message) != "" && [regexp -nocase $ioNJ(group_dirs) $pwd]} {
		if {[file exists $ioNJ(custom_group_dirs_complete_message)]} {
		  	set message  [readfile $ioNJ(custom_group_dirs_complete_message)]
		}
	}
	
	
	## Change variables in messages
	set message [string map $replacevar $message]
	#
	set exchange [regexp -all -inline {%fm([\-]?)([0-9]+)\{([^\{\}]+)\}} $message]
	foreach {crap 1 2 replacing} $exchange {
		if {![string is integer -strict $2]} { continue }
	        if {[string length $replacing] > $2} { 
	        	set replace [string range $replacing 0 [expr $2 - 1]] 
	        } else { 
	        	set replace $replacing
	        }
	       
		set message [string map [list "%fm$1$2\{$replacing\}" [format %${1}${2}s "$replace"]] $message]
	}
	
	outstat $message
	
	
	
return
}


#######################
## Resort
#######################
proc ::ioNiNJA::resort {} {global pwd path args ioNJ

		set path1 [regsub -all {\\} $path {/}]
		set pwd2 $pwd
		
		if {[regexp -nocase {mp3|imdb|tv|mv|xxx|symlinks|flac} [lindex $args 1]]} {
			set type [string toupper [lindex $args 1]]
			set dirlist  [list "[list [file tail $pwd]]"]
			set pwd [file dirname $pwd]
			set pwd2 $pwd
		} else {
			outputsite $ioNJ(resort_help) 
			return
		}
		set nr 0
		while {[lindex $dirlist $nr] != ""} {
			set pwd $pwd2
			if {[lindex [lindex $dirlist $nr] 0] == "."} { 
				incr nr
				continue 
			}	

			if {![file exists [resolve pwd [file join $pwd [lindex [lindex $dirlist $nr] 0]]]]}  { 
				incr nr
				continue 
			}
			iputs -nobuffer "RESORT $type: [file tail [lindex [lindex $dirlist $nr] 0]]"
			foreach afi [lsearch -all -exact -index 1 -inline [resolve list [file join $pwd [lindex [lindex $dirlist $nr] 0]]] "d"] {
				if {[lindex $afi 0] == "."} { continue }
				lassign $afi io_fname2 io_type2 io_uid2 io_user2 io_gid2 io_group2 io_fsize2 mode2 attributes2 win-last-time2 unix-last-time2 win-alt-time2 unix-alt-time2 subdir-count2 rlink2 chatt2 uptime2
				lappend dirlist [lreplace $afi 0 0 [file join [lindex [lindex $dirlist $nr] 0] $io_fname2]]
			}
			set pwd2 $pwd 
			set path2 $path
			set pwd [file join $pwd [lindex [lindex $dirlist $nr] 0]]
			set path [resolve pwd $pwd]
			catch {vfs chattr $path 11} temptime
			if { $temptime == ""} {
				set temptime [file mtime $path]
			}
			if {$type == "MP3"} {
				set temp_mp3 [lindex [glob -nocomplain -type f -directory $path "*.mp3"] 0]
				set temp_flac [lindex [glob -nocomplain -type f -directory $path "*.flac"] 0]
				if {$temp_mp3 != ""} { 
					catch {writechattr $path 240 ""} 
					catch {vfs chattr $path 25 ""}
					get_mp3_information "$temp_mp3" 
					::ioNiNJA::MP3::Main
				} 
			} elseif {$type == "FLAC"} {
				set temp_flac [lindex [glob -nocomplain -type f -directory $path "*.flac"] 0]
				if {$temp_flac != ""} { 
					catch {writechattr $path 240 ""} 
					catch {vfs chattr $path 26 ""}
					get_flac_information "$temp_flac"
					::ioNiNJA::FLAC::Main
				}
			} elseif {$type == "IMDB"} {
				catch {vfs chattr $path 30 ""}
				catch {writechattr $path 240 ""} 
				iMDB::imdb_readnfo
			} elseif {$type == "TV"} {
				catch {writechattr $path 240 ""} 
				ioTVDB::TV_MKD
			} elseif {$type == "XXX"} {
				catch {writechattr $path 240 ""} 
				xxxInfo::get_xxx_info
			} elseif {$type == "MV"} {
				catch {writechattr $path 240 ""} 
				MvInfo::get_mv_info
			} elseif {$type == "SYMLINKS"} {
				set symtype 1
				  catch {readchattr 240} symlinks
				foreach item $symlinks {
					if {!$symtype} {
						catch {file delete -force -- $item}
						catch {file mkdir "$item"}
						catch {vfs chattr "$item" 1 "$pwd"}
						catch {vfs flush "$item"}
					} else {						
						catch {file delete -force -- $item}
						catch {file mkdir "[file dirname $item]"}
						catch {file link -symbolic "$item" "$path"} error
					}
				} 
			}
			catch {file mtime $path $temptime} error
			incr nr
		}
  	iputs -nobuffer "RESORT DONE"
}


####
## DELETE OLD BARS
####
proc ::ioNiNJA::del_old_bars {} {global ioNJ pwd path
	set oldfiles [glob -nocomplain -directory "$path" "[string map { \[ \\[ \] \\]} $ioNJ(del_progressmeter)]"] 
	foreach progeta $oldfiles { catch {file delete -force "$progeta"} }
	set oldfiles [glob -nocomplain -directory "$path" "[string map { \[ \\[ \] \\]} $ioNJ(del_completebar)]"] 
	foreach progeta $oldfiles {catch {file delete -force "$progeta"} }
	return
}



###
# Get Mountpoints from vfs file
###
proc ::ioNiNJA::get_mountpoints {} {global pwd

	set wp ""
	foreach {vp rp} [mountpoints] {
		if {[regexp -nocase "^[string range $pwd 0 end-1]" $vp]} {
			lappend wp $rp
		}
		
	}
	
	if {$wp != ""} { return $wp }
	
	return [resolve pwd $pwd]
}



#######################
## Rescan
#######################

proc ::ioNiNJA::rescan_srr_rar_names {jsonText} {
	if {![catch {package require json}]} {
		if {![catch {set data [::json::json2dict $jsonText]}] && [dict exists $data blocks]} {
			set names {}
			foreach block [dict get $data blocks] {
				if {[dict exists $block type] && [dict get $block type] == "RARFile" && [dict exists $block name]} {
					lappend names [dict get $block name]
				}
			}
			return $names
		}
	}

	# Fallback for installations without Tcllib JSON. ReScene CLI emits block
	# properties in this stable order and JSON-escapes file names.
	set names {}
	set pattern {"type":"RARFile","size":[0-9]+,"name":"((?:\\.|[^"\\])*)"}
	foreach {match name} [regexp -all -inline -- $pattern $jsonText] {
		lappend names [string map [list "\\\\" "\\" "\\\"" "\"" "\\/" "/"] $name]
	}
	return $names
}

proc ::ioNiNJA::rescan_srr_check {files} {global pwd path ioNJ
	set srrRecords [lsearch -all -regexp -nocase -index 0 -inline $files {\.srr$}]
	if {[llength $srrRecords] == 0} {
		if {[info exists ioNJ(rescan_srr_required)] && $ioNJ(rescan_srr_required)} {
			return [dict create ok 0 status MISSING error "SRR file is required"]
		}
		return [dict create ok 1 status NONE expected 0 missing {} extra {}]
	}
	if {[llength $srrRecords] != 1} {
		return [dict create ok 0 status MULTIPLE error "multiple SRR files found"]
	}
	if {![info exists ioNJ(rescan_srr_tool)] || ![file isfile $ioNJ(rescan_srr_tool)]} {
		return [dict create ok 0 status TOOL_ERROR error "ReScene CLI not found: $ioNJ(rescan_srr_tool)"]
	}

	set srrName [lindex [lindex $srrRecords 0] 0]
	set srrPath [file join $path $srrName]
	if {[catch {exec -- $ioNJ(rescan_srr_tool) verify --json $srrPath} verifyOutput]} {
		return [dict create ok 0 status INVALID file $srrName error $verifyOutput]
	}
	if {[catch {exec -- $ioNJ(rescan_srr_tool) inspect --json $srrPath} inspectOutput]} {
		return [dict create ok 0 status INSPECT_ERROR file $srrName error $inspectOutput]
	}
	set expected [rescan_srr_rar_names $inspectOutput]
	if {[llength $expected] == 0} {
		return [dict create ok 0 status EMPTY file $srrName error "SRR contains no RAR volumes"]
	}

	set actualMap {}
	set actualRars {}
	foreach record $files {
		set name [lindex $record 0]
		dict set actualMap [string tolower $name] 1
		if {[regexp -nocase {\.rar$|\.r[0-9][0-9]$|\.rar[0-9][0-9][0-9]$} $name]} {
			lappend actualRars $name
		}
	}
	set expectedMap {}
	set missing {}
	foreach name $expected {
		set key [string tolower $name]
		dict set expectedMap $key 1
		if {![dict exists $actualMap $key]} {lappend missing $name}
	}
	set extra {}
	foreach name $actualRars {
		if {![dict exists $expectedMap [string tolower $name]]} {lappend extra $name}
	}
	return [dict create ok [expr {[llength $missing] == 0}] status [expr {[llength $missing] == 0 ? "OK" : "MISSING_VOLUMES"}] file $srrName expected [llength $expected] missing $missing extra $extra]
}

proc ::ioNiNJA::rescan_cache_file {} {global pwd ioNJ
	if {![info exists ioNJ(rescan_cache_dir)] || $ioNJ(rescan_cache_dir) == ""} {return ""}
	set bytes [encoding convertto utf-8 [string tolower $pwd]]
	set key [format %08X [zlib crc32 $bytes]]
	return [file join $ioNJ(rescan_cache_dir) "${key}.cache"]
}

proc ::ioNiNJA::rescan_cache_load {} {global pwd
	set filename [rescan_cache_file]
	if {$filename == "" || ![file isfile $filename]} {return {}}
	if {[catch {
		set handle [open $filename r]
		fconfigure $handle -encoding utf-8 -translation lf
		set data [read $handle]
		close $handle
	}]} {return {}}
	if {[catch {dict size $data}] || ![dict exists $data version] || [dict get $data version] != 1 ||
		![dict exists $data pwd] || ![string equal -nocase [dict get $data pwd] $pwd] || ![dict exists $data files]} {
		return {}
	}
	set files [dict get $data files]
	if {[catch {dict size $files}]} {return {}}
	return $files
}

proc ::ioNiNJA::rescan_cache_save {files} {global pwd
	set filename [rescan_cache_file]
	if {$filename == ""} {return}
	set temporary "${filename}.[pid].tmp"
	if {[catch {
		file mkdir [file dirname $filename]
		set handle [open $temporary w]
		fconfigure $handle -encoding utf-8 -translation lf
		puts -nonewline $handle [dict create version 1 pwd $pwd files $files]
		close $handle
		file rename -force $temporary $filename
	} error]} {
		catch {close $handle}
		catch {file delete -force $temporary}
		put_log [list RESCAN_CACHE_ERROR: $pwd $error]
	}
}

proc ::ioNiNJA::rescan {} {global pwd path args ioNJ speed

	regsub -all {\\} $path {/} path
	set originalPwd $pwd
	set originalPath $path
	set scope [string toupper [lindex $args 1]]
	set requested [string toupper [lindex $args 2]]
	# Match the glFTPD/PZS-NG command line: bare SITE RESCAN means the
	# current directory. ioNiNJA's explicit THIS/ALL forms remain available.
	if {$scope == ""} {
		set scope "THIS"
	} elseif {$scope == "QUICK" || $scope == "FULL"} {
		set requested $scope
		set scope "THIS"
	}
	if {$requested == ""} {
		set quick [expr {[info exists ioNJ(rescan_default_to_quick)] && $ioNJ(rescan_default_to_quick)}]
	} elseif {$requested == "QUICK"} {
		set quick 1
	} elseif {$requested == "FULL"} {
		set quick 0
	} else {
		iputs -nobuffer "Usage: SITE RESCAN THIS|ALL ?QUICK|FULL?"
		return
	}
	set explicitPath [join [lrange $args 3 end] " "]
	if {$explicitPath != ""} {
		regsub -all {\\} $explicitPath {/} explicitPath
		if {[string index $explicitPath 0] != "/"} {
			iputs -nobuffer "RESCAN-ERROR: explicit path must be an absolute virtual path beginning with /"
			return
		}
		if {[catch {set explicitRealPath [resolve pwd $explicitPath]} error]} {
			iputs -nobuffer "RESCAN-ERROR: cannot resolve $explicitPath ($error)"
			return
		}
		set pwd [string trimright $explicitPath /]
		if {$pwd == ""} {set pwd "/"}
		set path $explicitRealPath
	} elseif {[info exists ioNJ(rescan_root_requires_path)] && $ioNJ(rescan_root_requires_path) && $pwd == "/"} {
		iputs -nobuffer "RESCAN-ERROR: client PWD is /. Supply the selected virtual path explicitly."
		iputs -nobuffer "Usage: SITE RESCAN THIS|ALL QUICK|FULL /virtual/path"
		return
	}
	set displayMode [expr {$quick ? "QUICK" : "FULL"}]
	iputs -nobuffer "ioNiNJA Rescan: Rescanning in $displayMode mode."
	iputs -nobuffer "ioNiNJA Rescan: Use THIS|ALL QUICK|FULL for options."
	iputs -nobuffer ""
	iputs -nobuffer "Rescanning files..."
	iputs -nobuffer ""
	
	if {$scope == "ALL"} {
		set filelist [resolve list "$pwd"]
		set dirlist [lsearch -all -exact -index 1 -inline $filelist "d"]
	} elseif {$scope == "THIS"} {
		set filelist [resolve list "$pwd"]
		set dirlist $pwd
		set nosub 1
  	} else {
  		outputsite $ioNJ(rescan_help) 
		return
  	}
	
	set nr 0
	while {[lindex $dirlist $nr] != ""} {
			set sfv ""
			set zip ""
			set srr ""
			if {[lindex [lindex $dirlist $nr] 0] == "."} { 
				incr nr
				continue 
			}
			if {![info exists nosub]} {
				foreach afi [lsearch -all -exact -index 1 -inline [resolve list [file join $pwd [lindex [lindex $dirlist $nr] 0]]] "d"] {
					if {[lindex $afi 0] == "."} { continue }
					lassign $afi io_fname2 io_type2 io_uid2 io_user2 io_gid2 io_group2 io_fsize2 mode2 attributes2 win-last-time2 unix-last-time2 win-alt-time2 unix-alt-time2 subdir-count2 rlink2 chatt2 uptime2
					lappend dirlist [lreplace $afi 0 0 [file join [lindex [lindex $dirlist $nr] 0] $io_fname2]]
				}
				set files [lsearch -all -exact -index 1 -inline [resolve list [file join $pwd [lindex [lindex $dirlist $nr] 0]]] "f"]
			} else {
				set files [lsearch -all -exact -index 1 -inline [resolve list $pwd] "f"]
			}
			
			
			
			if {[set sfv [lsearch -regexp -index 0 -all [string tolower $files] {\.sfv$}]] != "" || [set zip [lsearch -regexp -index 0 -all [string tolower $files] {\.zip$}]] != "" || [set srr [lsearch -regexp -index 0 -all [string tolower $files] {\.srr$}]] != ""} {
				set pwd2 $pwd 
				set path2 $path
				if {![info exists nosub]} {
					set pwd [file join $pwd [lindex [lindex $dirlist $nr] 0]]
				}
				set path [resolve pwd $pwd]
				if {[set temptime [vfs chattr $path 11]] == ""} {
					set temptime [file mtime $path]
				}
				if {[regexp -nocase $ioNJ(skipdirs) $pwd] && (![info exists ioNJ(rescan_nocheck_dirs_allowed)] || !$ioNJ(rescan_nocheck_dirs_allowed))} {
					iputs -nobuffer "RESCAN-SKIP: $pwd is configured as a nocheck directory"
					set pwd $pwd2
					set path $path2
					incr nr
					continue
				}
				set mode [expr {$quick ? "QUICK" : "FULL"}]
				iputs -nobuffer "RESCAN-START: $pwd ($mode)"
				set rescan_cache {}
				if {$quick} {
					set rescan_cache [rescan_cache_load]
					# Remove caches written by the short-lived chattr 57 implementation.
					catch {vfs chattr $path 57 ""}
				} else {
					writechattr 5 ""
					writechattr 9 "0"
					writechattr 10 ""
					writechattr 13 0
					writechattr 14 ""
					erasechattr 25
					erasechattr 30
					erasechattr 35
					erasechattr 50
					catch {vfs chattr $path 57 ""}
				}
				set passed_f 0
				set cached_f 0
				set failed_f 0
				set missing_f 0
				set missing_names {}
				set passed_size 0
				set failed_size 0
				set speed 2000
				# SFV is authoritative. Only use SRR as the alternate scan source
				# when the release does not contain an external SFV file.
				if {$sfv == "" && [info exists ioNJ(rescan_use_srr)] && $ioNJ(rescan_use_srr)} {
					if {[catch {set srrResult [rescan_srr_check $files]} error]} {
						incr failed_f
						iputs -nobuffer "SRR-ERROR: $pwd - $error"
						put_log [list RESCAN_SRR_ERROR: $pwd $error]
					} elseif {![dict get $srrResult ok]} {
						set missingVolumesAllowed [expr {
							[dict get $srrResult status] == "MISSING_VOLUMES" &&
							(![info exists ioNJ(rescan_srr_require_volumes)] || !$ioNJ(rescan_srr_require_volumes))
						}]
						if {[dict exists $srrResult error]} {
							set srrError [dict get $srrResult error]
						} else {
							set srrError [join [dict get $srrResult missing] {, }]
						}
						if {$missingVolumesAllowed} {
							set missingCount [llength [dict get $srrResult missing]]
							iputs -nobuffer "SRR-UNPACKED: [dict get $srrResult file] - $missingCount original RAR volumes removed"
							put_log [list RESCAN_SRR_UNPACKED: $pwd $missingCount]
						} else {
							incr failed_f
							iputs -nobuffer "SRR-[dict get $srrResult status]: $pwd - $srrError"
							put_log [list RESCAN_SRR_ERROR: $pwd [dict get $srrResult status] $srrError]
							iputs -nobuffer "RESCAN-ABORT: $pwd - strict SRR validation failed"
							set pwd $pwd2
							set path $path2
							incr nr
							continue
						}
					} elseif {[dict get $srrResult status] == "OK"} {
						set extraCount [llength [dict get $srrResult extra]]
						iputs -nobuffer "SRR-OK: [dict get $srrResult file] - [dict get $srrResult expected] RAR volumes, $extraCount extra"
						if {$extraCount > 0} {
							put_log [list RESCAN_SRR_EXTRA: $pwd [dict get $srrResult extra]]
						}
					}
				}
				if {$sfv != "" && $zip == ""} {
					set sfvIndex [lindex $sfv 0]
					set sfvfile [lindex [lindex $files $sfvIndex] 0]
					set files [lreplace $files $sfvIndex $sfvIndex]
					if {!$quick || [vfs chattr $path 35] == ""} {
						if {[catch {set crc [format %08X [crc32 [file join $path $sfvfile]]]} error]} {
							incr failed_f
							put_log [list RESCAN_CRC_ERROR: $pwd $sfvfile $error]
						} elseif {[catch {ZipScript::ZipScript 1 [file join $path $sfvfile] $crc [file join $pwd $sfvfile]} error]} {
							incr failed_f
							put_log [list RESCAN_FILE_ERROR: $pwd $sfvfile $error]
						}
					}
				} elseif {$zip != ""} {
						catch {file delete -force [file join $path file_id.diz]}
						foreach zipfile [lsort -integer -decreasing $zip] {
							set zf [lindex $files $zipfile]
							set files [lreplace $files $zipfile $zipfile]
							set files [linsert $files 0 $zf]
						}
				}
				set vf1 $pwd
				set pf1 $path
				foreach afi $files {
					lassign $afi io_fname io_type io_uid io_user io_gid io_group io_fsize mode attributes win-last-time unix-last-time win-alt-time unix-alt-time subdir-count rlink chatt uptime
					if {[regexp -nocase {\.srr$} $io_fname]} {continue}
					set vf [file join $vf1 $io_fname]
					set pf  [file join $pf1 $io_fname]
					if {$io_fsize == 0} { 
						if {[regexp -nocase [subst ${ioNJ(missingtag)}\$] $io_fname]} {
							catch {file delete -force $pf}
						}
						continue 
					}
					if {$quick && [dict exists $rescan_cache $io_fname]} {
						set cached_data [dict get $rescan_cache $io_fname]
						if {![catch {set current_mtime [file mtime $pf]}] &&
							[llength $cached_data] == 3 &&
							[lindex $cached_data 0] == $io_fsize &&
							[lindex $cached_data 1] == $current_mtime} {
							incr passed_f
							incr cached_f
							set passed_size [expr {$io_fsize + $passed_size}]
							iputs -nobuffer "File: $io_fname CHECKED"
							continue
						}
					}
					if {[file exists $pf]} {
							if {[catch {set crc [format %08X [crc32 $pf]]} error]} {
								incr failed_f
								set failed_size [expr {$io_fsize + $failed_size}]
								put_log [list RESCAN_CRC_ERROR: $pwd $io_fname $error]
								continue
							}
							if {[regexp -nocase {\.flac$|\.mp3$} $pf]} {
								writechattr 9 "0"
							}
							if {[catch {ZipScript::ZipScript 1 $pf $crc $vf} error]} {
								incr failed_f
								set failed_size [expr {$io_fsize + $failed_size}]
								put_log [list RESCAN_FILE_ERROR: $pwd $io_fname $error]
								continue
							}
							set args [list CHECK $pf $crc $vf]
					} 
					if {[file exists $pf]} {
							if {![catch {set current_mtime [file mtime $pf]}]} {
								dict set rescan_cache $io_fname [list $io_fsize $current_mtime $crc]
							}
							incr passed_f 
							set passed_size [expr $io_fsize + $passed_size]
							iputs -nobuffer "File: $io_fname CHECKED"
					} else {
							incr missing_f
							dict set missing_names [string tolower $io_fname] 1
							put_log [list RESCAN_FILE_MISSING: $pwd $io_fname]
							set failed_size [expr $io_fsize + $failed_size]
					}
				}
				
				rescan_cache_save $rescan_cache
				catch {file mtime $path $temptime} error
				# ZipScript creates zero-byte *.missing markers for SFV entries which
				# are absent. Count those after the scan, including newly-created tags.
				foreach missingRecord [lsearch -all -exact -index 1 -inline [resolve list $pwd] "f"] {
					set missingName [lindex $missingRecord 0]
					set missingSize [lindex $missingRecord 6]
					if {$missingSize == 0 && [regexp -nocase [subst ${ioNJ(missingtag)}\$] $missingName]} {
						regsub -nocase [subst ${ioNJ(missingtag)}\$] $missingName "" missingBase
						dict set missing_names [string tolower $missingBase] 1
					}
				}
				set missing_f [dict size $missing_names]
				set total_f [expr {$passed_f + $failed_f + $missing_f}]
				iputs -nobuffer ""
				iputs -nobuffer ""
				iputs -nobuffer [format " Passed : %d" $passed_f]
				iputs -nobuffer [format " Failed : %d" $failed_f]
				iputs -nobuffer [format " Missing: %d" $missing_f]
				iputs -nobuffer [format "  Total : %d" $total_f]
				put_log [list RESCAN: $pwd $mode $passed_f $cached_f $passed_size $failed_f $missing_f $failed_size]
				set pwd $pwd2
				set path $path2
			}
			incr nr
	}
	set pwd $originalPwd
	set path $originalPath
}

proc ::ioNiNJA::NJVER {} {global ioNJ
	outputsite "Running ioNiNJA $ioNJ(VERLONG)"
}
