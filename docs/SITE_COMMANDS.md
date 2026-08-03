# Site Commands

The `site` module provides IRC commands for common site status checks:

- `!df [section]` - show free disk space for configured sections.
- `!bw` - show current ioFTPD upload/download bandwidth.

## Enable The Module

The module config lives in:

```text
config/modules/site.conf
```

The commands are enabled by default:

```tcl
::dZSbot::Config::Set site.commands.df.enabled 1
::dZSbot::Config::Set site.commands.bw.enabled 1
::dZSbot::Config::Set site.commands.reply_target "channel"
```

Set `site.commands.reply_target` to `private` if the output should be sent as a
private message instead of to the channel.

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
MOVIES	//MEV-F4S/ARKiVE/MOViES
TV	//MEV-F4S/ARKiVE/TV
MUSIC	//NAS_F4S/ARKiV/MUSiC
APPS	//MEV-F4S/ARKiVE3/APPS
TV-KiDS	//MEV-F4S/ARKiVE3/KiDS TV
UHD	//MEV-F4S/ARKiVE3/MOViES UHD
AUDiOBOOKS	//MEV-F4S/ARKiVE/AUDiOBOOKS
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
