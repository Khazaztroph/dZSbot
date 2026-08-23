ircchan: #ioNiNJA on EFNET for support & bugreports
http://www.flashfxp.com/forum/showthread.php?t=12691 (forum for bugs)
http://www.flashfxp.com/forum/forumdisplay.php?f=38 (to get latest ioFTPD)

#### Thanks to:
neoxed (NXTools AlcoBot etc)
cornflake (ioSFV)
the pzs-ng team (ZipScript for glftpd and cufptd)
YiL (ioFTPD developer)
SRR creator.
Mediainfo creator
and alot of other people


PS. 

You can turn off all the art downloading. To turn off ARTIST picture just change:
set ioNJ(artist_pic) {
c:/_Sorted/Music/1. Artists#/%artist_first/%artist/
c:/_Sorted/Music/2. Artists/%artist/
c:/_Sorted/Music/5. Release/%artist/
}

to

set ioNJ(artist_pic) ""
    
	
  


  This release is for beta testers only, so DO NOT EXPECT IT TO BE STABLE!
  Report the bugs you find on forum (http://www.flashfxp.com/forum/showthread.php?t=12691) or in #ioNiNJA on efnet
  Reporting bugs makes sure that they get fixed so plz take the time to do so.

  I take no responsibility for anything, if your computer burns to dust or blows up, it's on you!
  
  Read the license.txt for more info 

#######################################
## 1. INSTALLATION                   ##
#######################################

For update See changelog at the end of the file

1. unpack ioNiNJA to "path to ioftpd\scripts\ioNiNJA\"
   copy init.itcl to "../ioFTPD/scripts/"
   if it already exists copy file content from "../ioftpd/scripts/ioNiNJA/init.itcl"
   to the end of the existing file
  
   The copy the content inside ..ioFTPD/scripts/ioNiNJA/Libs/ to ..\ioFTPD\lib\tcl8.5
   
2. ADD TO IOFTPD.ini

under [Events]:
OnUploadComplete        = TCL ..\scripts\ioNiNJA\ioNiNJA.itcl CHECK
OnUploadError	 	= TCL ..\scripts\ioNiNJA\ioNiNJA.itcl CHECK

under [FTP_Pre-Command_Events]:
stor        = TCL ..\scripts\ioNiNJA\ioNiNJA.itcl PRESTOR
mkd         = TCL ..\scripts\ioNiNJA\ioNiNJA.itcl PREMKD
dele = TCL ..\scripts\ioNiNJA\ioNiNJA.itcl PREDELE


under [FTP_Post-Command_Events]:
dele = TCL ..\scripts\ioNiNJA\ioNiNJA.itcl
cwd  = TCL ..\scripts\ioNiNJA\ioNiNJA.itcl CWD
mkd =  TCL ..\scripts\ioNiNJA\ioNiNJA.itcl POSTMKD
rmd  = TCL ..\scripts\ioNiNJA\ioNiNJA.itcl POSTRMD



under [FTP_Custom_Commands]:
rescan      = TCL ..\scripts\ioNiNJA\ioNiNJA.itcl RESCAN
addgroups   = TCL ..\scripts\ioNiNJA\ioNiNJA.itcl ADDGENRES
addgrpstat  = TCL ..\scripts\ioNiNJA\ioNiNJA.itcl ADDGRPSTA
invite      = TCL ..\scripts\ioNiNJA\ioNiNJA.itcl INVITE
zsver       = TCL ..\scripts\ioNiNJA\ioNiNJA.itcl VERSION
resort      = TCL ..\scripts\ioNiNJA\ioNiNJA.itcl RESORT
symclean    = TCL ..\scripts\ioNiNJA\ioNiNJA.itcl SYMCLEAN
makesfv     = TCL ..\scripts\ioNiNJA\ioNiNJA.itcl MAKESFV
unpack 	    = TCL ..\scripts\ioNiNJA\plugins\unpack_complete.itcl
xdupe	    = TCL ..\scripts\ioNiNJA\ioNiNJA.itcl XDUPE
bot         = TCL ..\scripts\ioNiNJA\plugins\botchk.itcl


rescan      = 1M
addgroups   = 1M
addgrpstat  = 1M
invite      = *
zsver       = 1M
resort      = 1M
symclean    = 1M
makesfv     = 1M
unpack 	    = 1M
xdupe	    = *
bot         = *


!!!!!!!!!!!!!!!!!!!!REMOVE ALL OTHER INVITES!!!!!!!!!!!!!!



Scheduler:
#To get symclean to work on schedule add this under the schedule in ioFTPD.ini (Would be a good idea to check if it works with site symclean first)
ioSymClean = 59 23 * * TCL ..\scripts\ioNiNJA\ioNiNJA.itcl SYMCLEAN

#If you're using botchk.itcl you can add this to make it check if bot is running every 10 minutes
botchk = 0,10,20,30,40,50 * * * TCL ..\scripts\botchk.itcl

If you're using ioTV.itcl plugin, add this.
NJioTV    = 58 * * * TCL ..\scripts\ioNiNJA\plugins\ioTV.itcl  UPDATE_SERIES



3.
edit ioNiNJA.cfg
edit ..\Themes\PZS-NG.theme to fit your needs (it works as it is)
read the cookies readme in \themes for more info about themes (not always up to date)

-Change group of dirs with mp3/flac in them to the genre of mp3s inside it do this.
To chgrp of mp3dirs to the mp3files genre you need to enable this in the cfg.
and issue "site addgroups" This will add all genres as groups on your ftp.

-Change group to status. Incomplete etc. execute "site addgrpstat" beforehand.


4. WINDROP

  1. Copy the INCLUDED eggdrop to desired dir and edit the eggdrop.conf
  2. edit dZSbot.conf to fit your needs
  3. edit and add all the plug-ins you want to eggdrop.conf



RESTART EVERYTHING
Cross your fingers and hope it works!


#######################################
## 2. Troubleshooting & FAQ           ##
#######################################

1. Theme is broken who do i bitch at?

   Not me! I only maintain ioNiNJA.zst 

2. How do i report bugs?

   Either at forum: http://www.flashfxp.com/forum/showthread.php?t=12691
   Or irc: #ioNiNJA @ EFnet

3. Where do i get help configuring this script?

  NO end user support is given at the moment.

4. I have problem with windrop.

   Get used to it, windrop is crap but unfortunately the only thing available. 
   
5. I have problems with zip files not containing .diz files not being marked as complete

   Well, zip files needs diz files in order for the script to know how many files to expect.
   There are ways around it i know, unfortunately none of them are any good. Read the ioninja.cfg
   and you can exclude certain dirs from expecting diz files.
   
6. Can you write a special script just for me?

   Unfortunately, no. It just takes up too much time. But asking in chan on irc for new features
   etc is allowed. But respect "No" for a final answer.

7. What is a bug?

   If you do not know, it probably doesn't matter.
   
8. How do i use colors in themes on the bot?

   %c1{things you want colored} %b{things you want to be bold} %u{underlined} 
   %c1{things you want colored} would use color1 defined at the top of theme or if section specific colors are used it would use that.
   %c1{%b{%sitename}} would make %sitename bold and in color1 defined in script

   
9. I keep getting "FTP connection failed - server closed connection" in telenet?
   
   Exclude the sitebot username in ioftpd.ini from timeout
   
10. Can I change the interval in which the sitebot checks the bnc's?
      
   Not at the moment.
   
11. I'm using ntfs junctions but it creates problems with windows explorer when moving/removing the links
    
  http://elsdoerfer.name/=ntfslink
  That program hooks into windows explorer to handle links correctly.
  If you're using windows7 or win2008 it should be ok. 
  
12. What is NTFS junctions? and what makes them better or worse then ioftpd symlinks?
      
    Ntfs junctions is basically symlinks in windows. In other words the links works as regular folders in a windows environment.
    There are some restrictions to it. For instance NTFS junctions can not point to a network drive. But they can be shared over
    network to other computers.
    One things that's better with this type of symlink is that it works as a REAL directory. ioFTPD symlinks will only send you to the
    original dir and they don't work under a windows environment.
    In windows vista Microsoft added the ability to use symlinks that work over network unfortunately they can not be shared over networks, hence
    making them pretty useless since most symlinks are most useful on servers for creating a nice folder structure. I might add support
    for this format later on but right now the ntfs junctions actually work better.
    
    If you're only going to use ioFTPD for a server then the ioftpd symlinks might fit you best. If you going to use the server to get media from
    I would recommend junctions
    
    
 13. Why did you move most of the additions to plug-ins?
       
     It grew too much and got to big for it's own good.
     The plug-ins also run in background, meaning you wont have to wait for imdb lookup to complete when uploading nfo etc.
     
     
 14. I want custom posters to my tv shows!
            
     ioNiNJA actually saves all the posters in scripts/ioninja/posters/
     replace the one you want or create new ones. For fanart, name the file show-fanart.jpg
     This only works for tv shows
 
 15. When downloading music covers i sometimes get the wrong one.
     
     This feature is based on name lookup and is far from perfect. 
     It works on most retail albums and singles.
     
     
 16. When running io as a service i can't get my bot to announce !bw !speed etc.
      
     Check botchk in plugin folder for launching the bot. This let's ioFTPD execute the bot.
      
 17. Help my bot wont start!
    
     Use Included windrop.

 18. I get the message "05-07-2009 18:57:04 Error converting string: /pwd/" in system error.log

     This is not really an error, ignore it or go yell at YiL, Whatever you do, DON'T report it as a bug!

 19. I can't get !request, !site etc... to work from irc

     You need to have invite enabled and NickDb.tcl loaded


 20. The scripts in /eggdrop/sitebot/plugins doesn't work.

     These are very old and not really written by me, so though luck.


    BEFORE REPORTING BUGS
    
    If you experience problems with the script then change ioNiNJA.cfg to the default one, don't change anything and see if
    the problem still exists. If it doesn't, the fault is probably in your own cfg file. Also check system error.log to see if it contains
    a error. Read the error before asking for help, most often it's easy to resolve.



#######################################
## 3. TODO                           ##
#######################################

1. Well, as long as it works..... I have a limited amount of time available and the script seems to work. No plans on altering it at the moment. 



#######################################
## 4. CHANGELOG                      ##
#######################################

2014-11-02
The script still seems to be working for most people, not much that I want to change at the moment.
So what is new in this release?
Nothing has changed except a few fixes that were not included in the beta4 release. No need to update if it still works.
 * Updated media.exe and mediainfo.dll in /misc. Replace those to update. (not tested, so hopefully they still work).
 * The Ninja.lib (/misc/) and imdb.tcl (/scripts) were replaced with updated versions that has been previously posted in the thread.

2026-06-28
ioNiNJA v1.0b7
--------------

Fixes
------
- Improved POST_MKD error handling.
- Prevents unhandled 'vfs read' failures when target directory is unavailable.
- Added graceful error handling and logging.
- Improved overall stability during directory creation events.


