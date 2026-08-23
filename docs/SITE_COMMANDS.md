# Site Commands

The `site` module provides IRC commands for common site status checks:

- `!df [section]` - show free disk space for configured sections.
- `!bw` - show current ioFTPD upload/download bandwidth.
- `!bnc [name]` - show configured BNC, IRC and FTP connection status for admins.
- `!quota`, `!weekly` - show weekly quota and top uploader status.
- `!approve`, `!nuke`, `!unnuke`, `!reqfilled`, `!reqdel` - forward site actions.
- `!incomplete` - show incomplete releases from cache.

## Enable The Module

The module config lives in:

```text
config/modules/site.conf
```

The commands are enabled by default:

```tcl
::dZSbot::Config::Set site.commands.df.enabled 1
::dZSbot::Config::Set site.commands.bw.enabled 1
::dZSbot::Config::Set site.commands.bnc.enabled 1
::dZSbot::Config::Set site.commands.quota.enabled 1
::dZSbot::Config::Set site.commands.reply_target "channel"
::dZSbot::Config::Set site.commands.df.reply_target "private"
::dZSbot::Config::Set site.commands.bnc.reply_target "private"
```

Set `site.commands.reply_target` to `private` if the output should be sent as a
private message instead of to the channel. `site.commands.df.reply_target` and
`site.commands.bnc.reply_target` override the global site setting for `!df` and
`!bnc`.

## Disk Free: !df

`!df` can read disk status from a cache file. This is the recommended Windows
and Eggdrop setup because Eggdrop's Tcl `exec` can have trouble creating
temporary stderr files in some Cygwin/service environments.

Create a section file for the exporter:

```text
C:/ioFTPD/scripts/dzsbot-df-sections.tsv
```

Example content:

```text
MOVIES	D:/FTP-ROOT-DIR/MOVIES
TV	D:/FTP-ROOT-DIR/TV
MUSIC	D:/FTP-ROOT-DIR/MUSIC
APPS	D:/FTP-ROOT-DIR/APPS
TV-KiDS	D:/FTP-ROOT-DIR/TV-KiDS
UHD	D:/FTP-ROOT-DIR/UHD
AUDIOBOOKS	D:/FTP-ROOT-DIR/AUDIOBOOKS
```

Run the exporter with PowerShell:

```text
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:/ioFTPD/scripts/dzsbot_df.ps1 -SectionsFile C:/ioFTPD/scripts/dzsbot-df-sections.tsv -OutputFile C:/ioFTPD/logs/dzsbot-df.tsv
```

Or use the bundled batch wrapper:

```text
C:/ioFTPD/scripts/dzsbot_df.bat
```

Configure dZSbot:

```tcl
::dZSbot::Config::Set site.commands.df.source "cache"
::dZSbot::Config::Set site.commands.df.fallback "cache"
::dZSbot::Config::Set site.commands.df.cache_file "C:/ioFTPD/logs/dzsbot-df.tsv"
::dZSbot::Config::Set site.commands.df.cache_max_age_seconds 300
```

With FluxFTP API enabled, `!df` can read sections directly from FluxFTP:

```tcl
::dZSbot::Config::Set site.commands.df.source "fluxftp"
```

If the API is unavailable, dZSbot falls back to the cache file when
`site.commands.df.fallback` is `cache`.

For local/direct mode, configure the sections that `!df` should report:

```tcl
::dZSbot::Config::Set site.df.sections {
    {MOVIES "D:/ioFTPD/FTP-ROOT-DIR/MOVIES"}
    {TV "//nas/site/TV"}
    {MUSIC "E:/FTP/MUSIC"}
}
```

Use forward slashes in Windows paths. Tcl treats backslashes as escape
characters, so `D:/ioFTPD/FTP-ROOT-DIR/MOVIES` is safer than
`D:\ioFTPD\FTP-ROOT-DIR\MOVIES`.

A dict-style config is also supported:

```tcl
::dZSbot::Config::Set site.df.sections [dict create \
    MOVIES "D:/ioFTPD/FTP-ROOT-DIR/MOVIES" \
    TV "//nas/site/TV" \
    MUSIC "E:/FTP/MUSIC"]
```

IRC examples:

```text
!df
!df movies
```

If you use cache mode, `site.df.sections` may still be kept as documentation in
`site.conf`, but the exporter TSV is what controls the live disk checks.

## Bandwidth: !bw

`!bw` uses a cache file written by ioFTPD. This is the recommended method
because `SITE TRAFFIC` and `SITE STATS` report site statistics/status, not
reliable live transfer speed during FXP.

Copy the exporter to ioFTPD:

```text
C:/ioFTPD/scripts/dzsbot_ioftpd_bw.tcl
```

Add the command under `[FTP_Custom_Commands]` in `C:/ioFTPD/system/ioFTPD.ini`:

```ini
dzsbw = TCL ..\scripts\dzsbot_ioftpd_bw.tcl BW C:/ioFTPD/logs/dzsbot-bw.tsv
```

Allow the command in the matching site command permissions section:

```ini
dzsbw = 1M
```

Reload ioFTPD:

```text
SITE REHASH
```

Then test from FTP/admin:

```text
SITE DZSBW
```

This should create or update:

```text
C:/ioFTPD/logs/dzsbot-bw.tsv
```

Configure dZSbot to read the same file:

```tcl
::dZSbot::Config::Set site.commands.bw.source "cache"
::dZSbot::Config::Set site.commands.bw.fallback "cache"
::dZSbot::Config::Set site.commands.bw.cache_file "C:/ioFTPD/logs/dzsbot-bw.tsv"
::dZSbot::Config::Set site.commands.bw.cache_max_age_seconds 15
::dZSbot::Config::Set site.commands.bw.max_lines 6
```

With FluxFTP API enabled, `!bw` can read live transfers directly from FluxFTP:

```tcl
::dZSbot::Config::Set site.commands.bw.source "fluxftp"
```

If FluxFTP does not answer, dZSbot falls back to the cache file when
`site.commands.bw.fallback` is `cache`.

IRC example:

```text
!bw
```

Expected output:

```text
BW: UP 1 @ 2.00 MB/s | DN 1 @ 1.00 MB/s | idle 1 | total 3.00 MB/s
BW: UP | user | 2.00 MB/s | /MOVIES/Example.Release-GRP
BW: DN | user | 1.00 MB/s | /TV/Example.Show-GRP
```

## BNC Status: !bnc

`!bnc` checks configured connectivity targets. Normal entries check whether a
TCP port accepts a connection. A target using `eggdrop 0` reports the active IRC
connection Eggdrop is already using, which is the best choice for a remote ZNC.
Use it for ZNC/BNC, IRC server and FTP/ioFTPD reachability checks. The command
is admin-only and uses the same access policy as `!dzb status`:

```tcl
::dZSbot::Config::Set status.admin_channel "#staff"
::dZSbot::Config::Set status.require_channel_op 1
```

Configure targets in `config/modules/site.conf`:

```tcl
::dZSbot::Config::Set site.commands.bnc.enabled 1
::dZSbot::Config::Set site.commands.bnc.timeout_ms 3000
::dZSbot::Config::Set site.commands.bnc.targets {
    {ZNC eggdrop 0}
    {IRC irc.example.net 6697}
    {FTP 127.0.0.1 5420}
}
```

IRC examples:

```text
!bnc
!BNC prime
```

Expected output:

```text
BNC: 3/3 online
BNC: ZNC | OK | leon.seedhost.eu:+29025 | online 2h 14m
BNC: IRC | OK | irc.example.net:6697 | 32ms
BNC: FTP | OK | 127.0.0.1:5420 | 2ms
```

## Weekly Quota: !quota

`!quota` and `!weekly` read a TSV cache file and print a weekly uploader list.
By default the command is admin-only through the same access policy as
`!dzb status` and `!bnc`.

Configure it in `config/modules/site.conf`:

```tcl
::dZSbot::Config::Set site.commands.quota.enabled 1
::dZSbot::Config::Set site.commands.quota.admin_only 1
::dZSbot::Config::Set site.commands.quota.channel "#monstra"
::dZSbot::Config::Set site.commands.quota.cache_file "C:/ioFTPD/logs/dzsbot-quota.tsv"
::dZSbot::Config::Set site.commands.quota.cache_max_age_seconds 3600
::dZSbot::Config::Set site.commands.quota.server_name "SomeServer"
::dZSbot::Config::Set site.commands.quota.required_gb 121.18
::dZSbot::Config::Set site.commands.quota.period_label "Weekly"
::dZSbot::Config::Set site.commands.quota.rule_label "20% top-1"
::dZSbot::Config::Set site.commands.quota.days_left ""
::dZSbot::Config::Set site.commands.quota.week_reset_day 1
::dZSbot::Config::Set site.commands.quota.limit 13
::dZSbot::Config::Set site.commands.quota.dayup_limit 3
::dZSbot::Config::Set site.commands.quota.fail_line "FAIL Who will die this time? R.I.P"
```

Set `site.commands.quota.channel` to force output into a fixed channel. Leave it
empty to reply where the command was used.

The TSV format is:

```text
user	status	weekly_gb	today_gb	optional_day_rank
```

Example:

```text
aCe	pass	605.92	169.76
foyel	pass	509.75	114.82
rrimul	pass	481.37	139.27
trax	pass	471.39	90.47
NasBanH	pass	416.25	129.11
```

If `optional_day_rank` is omitted, dZSbot calculates `#1 DAYUP`, `#2 DAYUP`
and so on from `today_gb`, controlled by `site.commands.quota.dayup_limit`.

IRC example:

```text
!quota
!weekly
```

Expected output:

```text
[ SomeServer]-[ QUOTA 121.18/GB ]-[ Weekly 20% top-1 ]-[ 4 DAYS LEFT ]
01: aCe pass with 605.92 GB | today: 169.76 GB (#1 DAYUP)
02: foyel pass with 509.75 GB | today: 114.82 GB
03: rrimul pass with 481.37 GB | today: 139.27 GB (#2 DAYUP)
FAIL Who will die this time? R.I.P
```

Auto announce the same top uploader output at a fixed interval:

```tcl
::dZSbot::Config::Set site.commands.quota.auto.enabled 1
::dZSbot::Config::Set site.commands.quota.auto.channel "#monstra"
::dZSbot::Config::Set site.commands.quota.auto.interval_seconds 7200
```

## Site Actions

These IRC commands forward to the FTP server as `SITE` commands over the
configured site command transport:

```text
!approve <release/path>
!nuke <release/path> <multiplier> <reason>
!unnuke <release/path> <reason>
!unuke <release/path> <reason>
!reqfilled <request/release>
!reqdel <request/release>
```

Configure command names and access:

```tcl
::dZSbot::Config::Set site.commands.actions.enabled 1
::dZSbot::Config::Set site.commands.actions.admin_only 1
::dZSbot::Config::Set site.commands.actions.reply_target "private"
::dZSbot::Config::Set site.commands.actions.command.APPROVE "APPROVE"
::dZSbot::Config::Set site.commands.actions.command.NUKE "NUKE"
::dZSbot::Config::Set site.commands.actions.command.UNNUKE "UNNUKE"
::dZSbot::Config::Set site.commands.actions.command.REQFILL "REQFILL"
::dZSbot::Config::Set site.commands.actions.command.REQDEL "REQDEL"
```

## Incomplete List

`!incomplete [section|release]` reads a TSV cache and shows incomplete releases.

```tcl
::dZSbot::Config::Set site.commands.incomplete.enabled 1
::dZSbot::Config::Set site.commands.incomplete.cache_file "C:/ioFTPD/logs/dzsbot-incomplete.tsv"
::dZSbot::Config::Set site.commands.incomplete.cache_max_age_seconds 3600
::dZSbot::Config::Set site.commands.incomplete.sections {MOVIES TV FLAC XXX-PAY}
::dZSbot::Config::Set site.commands.incomplete.limit 20
```

Cache format:

```text
timestamp	section	release	path	user	group
```

## Optional Scheduler

If you want ioFTPD to update the bandwidth cache automatically, add this line to
the existing `[Scheduler]` section:

```ini
DZSBW = * * * * TCL ..\scripts\dzsbot_ioftpd_bw.tcl BW C:/ioFTPD/logs/dzsbot-bw.tsv
```

For disk-free cache updates, run the batch wrapper every 5 minutes:

```ini
DZSDF = 0,5,10,15,20,25,30,35,40,45,50,55 * * * EXEC ..\scripts\dzsbot_df.bat
```

Do not add a second `[Scheduler]` header. ioFTPD's scheduler is normally
minute-based, so set the bandwidth cache age higher for scheduler-only setups:

```tcl
::dZSbot::Config::Set site.commands.bw.cache_max_age_seconds 75
```

## Troubleshooting

`500 'SITE DZSBW': Command not understood.`

The command is missing under `[FTP_Custom_Commands]`, or ioFTPD has not reloaded
the config.

`Command failed (script): fatal script error.`

The exporter ran but crashed inside ioFTPD. Check:

```text
C:/ioFTPD/logs/dzsbot-bw-error.log
```

`BW: unavailable (BW cache file not found...)`

Run `SITE DZSBW` once and confirm that `C:/ioFTPD/logs/dzsbot-bw.tsv` exists.

`BW: unavailable (BW cache is stale...)`

Run `SITE DZSBW` again, or use the scheduler and increase
`site.commands.bw.cache_max_age_seconds`.
