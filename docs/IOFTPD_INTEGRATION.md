# ioFTPD Integration

This file records the relevant parts of the current `ioFTPD.ini` and how
dZSbot 2.0 should integrate with it.

## FTP Service

From `C:/ioFTPD/system/ioFTPD.ini`:

```text
[FTP_Service]
Port = 5420
Require_Encrypted_Auth = !-ioFTPD !-PRiME !-PRiMEBNC *
Require_Encrypted_Data = !-ioFTPD !-PRiME !-PRiMEBNC *
Explicit_Encryption = TRUE
Encryption_Protocol = TLS1.3
OpenSSL_Ciphers = TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384:TLS_AES_128_GCM_SHA256
```

Passive ports:

```text
[Any]
Ports = 5421-5450
```

dZSbot config mirrors this:

```tcl
::dZSbot::Config::Set site.adapter "ioftpd"
::dZSbot::Config::Set site.port 5420
::dZSbot::Config::Set site.passive_ports "5421-5450"
::dZSbot::Config::Set site.command_transport "ftps"
::dZSbot::Config::Set site.tls.required 1
::dZSbot::Config::Set site.tls.min_version "1.3"
```

## Event Hooks

Current upload-related hooks:

```text
[Events]
OnUploadComplete = TCL ..\scripts\ioNiNJA\ioNiNJA.itcl CHECK
OnUploadError    = TCL ..\scripts\ioNiNJA\ioNiNJA.itcl CHECK
OnUploadComplete = TCL ..\scripts\nxTools\nxDupe.tcl UPLOAD
OnUploadError    = TCL ..\scripts\nxTools\nxDupe.tcl UPLOADERROR
```

Current command hooks:

```text
[FTP_Pre-Command_Events]
mkd  = TCL ..\scripts\ioNiNJA\ioNiNJA.itcl PREMKD
stor = TCL ..\scripts\ioNiNJA\ioNiNJA.itcl PRESTOR
mkd  = TCL ..\scripts\nxTools\nxDupe.tcl PREMKD
stor = TCL ..\scripts\nxTools\nxDupe.tcl PRESTOR

[FTP_Post-Command_Events]
mkd  = TCL ..\scripts\nxTools\nxDupe.tcl POSTMKD
mkd  = TCL ..\scripts\ioNiNJA\ioNiNJA.itcl POSTMKD
cwd  = TCL ..\scripts\ioNiNJA\ioNiNJA.itcl CWD
```

## dZSbot Adapter Plan

The new adapter should not replace ioNiNJA/nxTools immediately. It should add
one small event bridge script that publishes normalized events to dZSbot:

```text
site.newdir
site.upload.complete
site.upload.error
site.release
```

Expected event payload:

```tcl
dict create \
    adapter ioftpd \
    section MOVIES \
    release Example.Release.2026.1080p.WEB.H264-GROUP \
    path /site/MOVIES/Example.Release.2026.1080p.WEB.H264-GROUP \
    user user \
    group group
```

Modules such as IMDb should only consume these normalized events. They should
not parse `ioFTPD.ini` directly and should not talk to ioFTPD directly.

## nxPre Compatibility

The current setup can keep using nxTools for `SITE PRE`:

```ini
[FTP_Custom_Commands]
pre = TCL ..\scripts\nxTools\nxPre.tcl PRE
editpre = TCL ..\scripts\nxTools\nxPre.tcl EDIT
```

nxPre writes log lines like:

```text
PRE: "/MP3/Release-GROUP" "PREGROUP" "user" "group" "MP3" "12" "7340032" "1"
PRE-MP3: "/MP3/Release-GROUP" "PREGROUP" "user" "group" "MP3" "12" "7340032" "1" "Artist" "Album" "Genre" "2026" "320" "CBR"
PRE-FLAC: "/MUSIC/Release-GROUP" "PREGROUP" "user" "group" "MUSIC" "12" "7340032" "1" "Artist" "Album" "Genre" "2026" "Lossless" "FLAC"
```

dZSbot parses these through `::dZSbot::SiteAdapter::ParseNxPreLine` and
publishes a normalized `site.release` event. The PRE module can import those
events into its own storage when `pre.import_site_releases` is enabled.
For FLAC, the section can still be `MUSIC`; the `PRE-FLAC` log prefix is kept
as `pre_type`, so IRC announce lines can display `PRE-FLAC`.

When running under Eggdrop, dZSbot can watch the ioFTPD log for new nxPre lines:

```tcl
::dZSbot::Config::Set site.ioftpd.nxpre_watch.enabled 1
::dZSbot::Config::Set site.ioftpd.nxpre_log_file "C:/ioFTPD/logs/ioFTPD.log"
::dZSbot::Config::Set site.ioftpd.nxpre_poll_seconds 5
::dZSbot::Config::Set site.ioftpd.nxpre_start_at_end 1
```

`site.ioftpd.nxpre_start_at_end 1` means startup begins watching from the end
of the current log file, so old historical PRE lines are not imported again.

## Upload Announcements

dZSbot also parses normal ioFTPD log lines from the same log watcher:

```text
NEWDIR: "user" "group" "/SECTION/Release-GROUP" "realpath"
UPDATE_*: ...
RACE_*: ...
NEWLEADER_*: ...
HALFWAY_RACE_*: ...
HALFWAY_NORACE_*: ...
COMPLETE_STAT_RACE_FLAC: /SECTION/Release-GROUP/ Release-GROUP 82865 5 ...
BAD_FILE_CRC: ...
BAD_FILE_0SIZE: ...
NFO: ...
DOUBLESFV: ...
SPEEDTEST: ...
INCOMPLETE: ...
WIPE: ...
CLOSE: ...
OPEN: ...
GIVE: ...
TAKE: ...
APPROVE: ...
APPROVEADD: ...
APPROVEDEL: ...
NUKE: ...
UNNUKE: ...
REQUEST: ...
REQFILL: ...
REQDEL: ...
REQWIPE: ...
NEWDATE: ...
```

These publish normalized `site.newdir` and `site.upload.complete` events. The
Upload module announces them to `upload.announce.channel`, or to a routed
section channel when `upload.announce.section_channels` is configured. PRE and
metadata modules such as IMDb/Music use their own `#pre` channel settings and
can still react to `site.newdir`.
For `COMPLETE_STAT_RACE_*`, dZSbot reads ioNiNJA's average upload speed
(`a_avgspeed`) and adds it to the IRC complete line.

nxTools compatibility events publish normalized `site.legacy.*` events. The
Legacy module announces them with pzs-ng/ioNiNJA-style templates from
`theme.template.legacy.*`, controlled by `config/modules/legacy.conf`. Legacy
events can use the same section routing as uploads, which is useful for keeping
music/XXX activity in one channel, Nordic in another, and the rest in an ops
channel.

Config:

```tcl
::dZSbot::Config::Set upload.announce.enabled 1
::dZSbot::Config::Set upload.announce.channel "#spam"
::dZSbot::Config::Set upload.announce.default_channel "#opers"
::dZSbot::Config::Set upload.announce.section_channels {
    {#spam {MUSIC FLAC MP3 XXX XXX-PAY}}
    {#monstra {TV-HD-NORDIC TV-SD-NORDIC X264-NORDIC X265-NORDIC UHD-NORDIC *-NORDIC}}
}
::dZSbot::Config::Set upload.announce.events {newdir first half leader complete badfile nfo doublesfv speedtest incomplete}
::dZSbot::Config::Set upload.announce.event.racer.enabled 0
::dZSbot::Config::Set upload.announce.sections {*}
```

Make sure Eggdrop also joins every routed announce channel:

```tcl
channel add #spam
channel add #monstra
channel add #opers
```

Example complete output:

```text
[COMPLETE][TV-1080P] :: Release-GROUP :: 15f :: 1.36GB :: 1m 46s :: avg. 7.36MB/s :: user
```

Example integrity/error output:

```text
[badcrc] :: user :: Release-GROUP :: broken.r00
[0size] :: user :: Release-GROUP :: empty.r00
[MOVIE-1080P][NFO] in Release-GROUP by user - release.nfo ::
[DOUBLESFV] :: user :: Release-GROUP :: release.sfv
[INCOMPLETE][MOVIE-1080P] Release-GROUP by user ::
```

## Live Bandwidth

`!bw` should use the dZSbot ioFTPD cache exporter. This avoids the old
`SITE TRAFFIC`/`SITE STATS` problem where IRC received site statistics or
status text instead of actual live transfer speed, especially during FXP.

Install `scripts/dzsbot_ioftpd_bw.tcl` under `C:/ioFTPD/scripts`:

```text
C:/ioFTPD/scripts/dzsbot_ioftpd_bw.tcl
```

Register it under `[FTP_Custom_Commands]`:

```ini
dzsbw = TCL ..\scripts\dzsbot_ioftpd_bw.tcl BW C:/ioFTPD/logs/dzsbot-bw.tsv
```

Allow the command under the matching permissions section:

```ini
dzsbw = 1M
```

Run it manually with:

```text
SITE DZSBW
```

dZSbot then reads the same file:

```tcl
::dZSbot::Config::Set site.commands.bw.source "cache"
::dZSbot::Config::Set site.commands.bw.cache_file "C:/ioFTPD/logs/dzsbot-bw.tsv"
::dZSbot::Config::Set site.commands.bw.cache_max_age_seconds 15
```

The cache format is tab-separated and intentionally small:

```text
timestamp direction user group speed_kbps virtual_path data_path status
```

`!bw` summarizes the file as upload, download, idle and total speed, then prints
the active transfers up to `site.commands.bw.max_lines`.

If the exporter should also update automatically, add it to the existing
`[Scheduler]` section. Do not add a second `[Scheduler]` header:

```ini
DZSBW = * * * * TCL ..\scripts\dzsbot_ioftpd_bw.tcl BW C:/ioFTPD/logs/dzsbot-bw.tsv
DZSDF = 0,5,10,15,20,25,30,35,40,45,50,55 * * * EXEC ..\scripts\dzsbot_df.bat
```

ioFTPD's scheduler is normally minute-based. For scheduler-only setups, set
`site.commands.bw.cache_max_age_seconds` to at least `75`.

## Security

Local event scripts/log reads are acceptable because they do not cross the
network. Any active network command/query from dZSbot back to ioFTPD must use
explicit FTPS on port `5420` with TLS 1.3 policy.
