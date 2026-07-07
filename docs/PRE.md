# PRE

The old sitebot used two PRE-related sources:

- nxTools SQLite files such as `Pres.db` for `!pres`.
- a MySQL-backed `PreTime.tcl` module/plugin for pretime lookup.

dZSbot 2.0 does not require MySQL for PRE. The new PRE module uses local TSV
storage by default and creates the file automatically. It can also use MySQL
when enabled.

## Storage

Configured in `config/modules/pre.conf`:

```tcl
::dZSbot::Config::Set pre.storage [file join $::dZSbot::Root database pre.tsv]
::dZSbot::Config::Set pre.backend "tsv"
::dZSbot::Config::Set pre.mysql.table "predb"
::dZSbot::Config::Set pre.mysql.fallback_to_tsv 1
::dZSbot::Config::Set pre.search_limit 5
::dZSbot::Config::Set pre.pres_limit 10
::dZSbot::Config::Set pre.import.nxtools.path "C:/ioFTPD/scripts/nxTools/data/Pres.db"
```

The storage fields follow the old `predb.sql` shape:

```text
id section relname u_name g_name nukereason pretime predate preage size files
```

Common PRE sections can include:

```text
MOVIES TV MUSIC MP3 FLAC AUDIOBOOKS GAMES PC CONSOLE EBOOKS
```

The section list is configured in `config/modules/pre.conf`:

```tcl
::dZSbot::Config::Set pre.sections {MOVIES TV MUSIC MP3 FLAC AUDIOBOOKS GAMES PC CONSOLE EBOOKS}
::dZSbot::Config::Set pre.announce.sections {MOVIES TV MUSIC MP3 FLAC AUDIOBOOKS GAMES PC CONSOLE EBOOKS}
```

Generic PRE announce lines are handled by the PRE module, so sections without a
metadata provider still appear in IRC:

```text
[PRE] Example.Game-RELOADED | PC | GAMEGROUP | 88F/12.00 GB
[PRE] Example.Ebook.2026-GROUP | EBOOKS | BOOKGROUP | 3F/10.00 MB
```

## Commands

```text
!addpre <release> ?section? ?user? ?group? ?size_kb? ?files?
!pre [query]
!preimport nxtools ?Pres.db path?
!pres
```

Examples:

```text
!addpre Example.Release.2026 MOVIES user GROUP 7340032 42
!pre Example
!preimport nxtools
!pres
```

`!preimport nxtools` reads nxTools `Pres.db` and writes missing entries into
the active dZSbot PRE backend. If `pre.backend` is `mysql`, the import writes to
MySQL. Existing releases are skipped.

## Daily Stats

PRE can announce a daily top summary in IRC:

```tcl
::dZSbot::Config::Set pre.daily_stats.enabled 1
::dZSbot::Config::Set pre.daily_stats.channel "#pre"
::dZSbot::Config::Set pre.daily_stats.time "23:59"
::dZSbot::Config::Set pre.daily_stats.window_hours 24
::dZSbot::Config::Set pre.daily_stats.top_limit 5
```

Example output:

```text
PRE Daily Stats: last 24h | 32 releases | 418F | 88.20 GB
PRE Top Groups: #1 GROUP (12) | #2 OTHER (8)
PRE Top Sections: #1 MUSIC (15) | #2 MOVIES (10)
```

## PRE Activity

PRE can announce bandwidth activity after nxPre writes a `PRE:` event. This is
similar to the old PreBW plugin and samples `ioftpd who` at configured
intervals.

```tcl
::dZSbot::Config::Set pre.activity.enabled 1
::dZSbot::Config::Set pre.activity.channel "#pre"
::dZSbot::Config::Set pre.activity.intervals {5 10 15 25 30}
```

Example output:

```text
PRE-BW: [MUSIC] Release-GROUP | 5s: 2@1.50 MB/s
PRE-BW: [MUSIC] Release-GROUP | 10s: 3@2.10 MB/s
```

When the bot is tested outside Eggdrop/ioFTPD, the feature marks itself as
disabled instead of failing.

## Why Not MySQL

MySQL is optional infrastructure, not a requirement for the module to work. The
Core should stay usable on a fresh setup without needing an external database
import first.

To enable MySQL:

```tcl
::dZSbot::Config::Set database.mysql.enabled 1
::dZSbot::Config::Set database.mysql.host "127.0.0.1"
::dZSbot::Config::Set database.mysql.port 3306
::dZSbot::Config::Set database.mysql.user "dzsbot"
::dZSbot::Config::Set database.mysql.password "secret"
::dZSbot::Config::Set database.mysql.database "dzsbot"
::dZSbot::Config::Set pre.backend "mysql"
```

The `database.mysql.*` settings stay in `config/dzsbot.conf`; the `pre.*`
settings stay in `config/modules/pre.conf`.

On load, PRE connects and runs `CREATE TABLE IF NOT EXISTS` for the configured
table.

If MySQL is unavailable, PRE logs a warning. With
`pre.mysql.fallback_to_tsv 1`, it falls back to TSV so the bot keeps running.
Set it to `0` if you want MySQL failures to be hard errors during testing.

For encrypted MySQL connections, see `docs/DATABASE.md`.
