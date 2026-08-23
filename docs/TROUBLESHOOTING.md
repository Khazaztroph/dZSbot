# Troubleshooting

This page lists common symptoms and the first place to look.

## dZSbot Does Not Load

Check Eggdrop startup output and dZSbot logs. The expected end state is:

```text
dZSbot loaded and ready.
```

If a Tcl package fails to load, check:

```text
lib/
auto_path
Eggdrop root DLLs
Tcl 8.6 vs Tcl 9 package compatibility
```

## !dzb status Does Not Reply

`!dzb status` is normally restricted to channel operators in the configured
staff channel.

Check:

```tcl
::dZSbot::Config::Set status.admin_channel "#staff"
::dZSbot::Config::Set status.require_channel_op 1
```

## !bw Is Unavailable

If using FluxFTP:

```tcl
::dZSbot::Config::Set fluxftp.enabled 1
::dZSbot::Config::Set site.commands.bw.source "fluxftp"
```

Check the FluxFTP API URL, port, TLS mode and API password/token.

If using ioFTPD cache:

```text
SITE DZSBW
C:/ioFTPD/logs/dzsbot-bw.tsv
```

See [Site Commands](SITE_COMMANDS.md).

## !df Shows No Matching Section

Check `config/modules/site.conf` and make sure sections are configured as a
proper Tcl list or dict.

Use forward slashes:

```tcl
::dZSbot::Config::Set site.df.sections {
    {MOVIES "//NAS/FTP/MOVIES"}
    {TV "D:/FTP/TV"}
}
```

## !bnc Shows No Targets

Add BNC/IRC/FTP connectivity targets in `config/modules/site.conf`:

```tcl
::dZSbot::Config::Set site.commands.bnc.targets {
    {ZNC eggdrop 0}
    {IRC irc.example.net 6697}
    {FTP 127.0.0.1 5420}
}
```

Use `{ZNC eggdrop 0}` when the bot is already connected through ZNC. That checks
Eggdrop's current IRC connection instead of opening a second TCP connection to
the BNC.

`!bnc` is admin-only. Run it in the configured staff channel as an op, or adjust:

```tcl
::dZSbot::Config::Set status.admin_channel "#staff"
::dZSbot::Config::Set status.require_channel_op 1
```

## !quota Is Unavailable

`!quota` reads:

```text
C:/ioFTPD/logs/dzsbot-quota.tsv
```

unless `site.commands.quota.cache_file` points somewhere else. Confirm that the
file exists, is fresh enough for `site.commands.quota.cache_max_age_seconds`,
and uses this tab-separated format:

```text
user	status	weekly_gb	today_gb	optional_day_rank
```

## NEWDATE Is Too Noisy

`NEWDATE` is a legacy nxTools/ioFTPD event. Disable only that announce:

```tcl
::dZSbot::Config::Set legacy.announce.event.newdate.enabled 0
```

The rest of the legacy parser remains active.

## RACE Posts Too Often

Per-file racer output is disabled by default. Confirm:

```tcl
::dZSbot::Config::Set upload.announce.event.racer.enabled 0
```

## PRE Import Fails

Check that the nxTools `Pres.db` path exists and that Tcl can load `sqlite3`.

```text
!preimport nxtools
!preimport nxtools C:/ioFTPD/scripts/nxTools/data/Pres.db
```

If MySQL is enabled, check that `tdbc::mysql` loads and the MySQL client DLLs
are visible to Eggdrop.

## MySQL Server Has Gone Away

dZSbot retries once after a lost MySQL connection. If the message repeats often,
check MySQL timeout settings, network stability and whether the server restarts
or closes idle sessions too aggressively.

## IMDb Or Music Lookup Fails

Check API keys:

```tcl
::dZSbot::Config::Set omdb.api_key "YOUR_KEY"
::dZSbot::Config::Set lastfm.api_key "YOUR_KEY"
::dZSbot::Config::Set discogs.token "YOUR_TOKEN"
```

MusicBrainz does not need an API key, but it should have a real User-Agent in
`config/modules/music.conf`.
