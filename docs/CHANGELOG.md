## 2.0.7 - 2026-07-27

- Added cache-based `!df` disk-free reporting for Windows/Eggdrop setups where
  direct Tcl `exec` stderr handling is unreliable.
- Added `scripts/dzsbot_df.ps1`, `scripts/dzsbot_df.bat` and an example section
  TSV for scheduled disk-free cache updates.
- Improved `!bw` with a tested ioFTPD-side cache exporter based on ioFTPD's
  internal `client who` status for live transfer speed.
- Added `docs/SITE_COMMANDS.md` with setup and troubleshooting for `!df` and
  `!bw`.

## 2.0.6 - 2026-07-26

- Added an OMDb title-search fallback for exact-title misses. The best
  title/year/type match is resolved to an IMDb ID before full metadata is
  fetched, fixing releases such as `Bad.Boy.in.Love.2024.720p.WEB.H264-AFO`.
- Added the `site` module with `!df` for configured disk-free sections.
- Added `!bw` for active ioFTPD transfer and bandwidth status.
- Changed the recommended `!bw` source to a fresh ioFTPD-side cache exporter so
  live FXP speeds come from `client who` instead of `SITE TRAFFIC`/`SITE STATS`.
- Added `config/modules/site.conf` for site command settings and disk paths.
- Added regression coverage for site command registration, disk free checks and
  ioFTPD transfer sampling.

## 2.0.5 - 2026-07-26

- Added MusicBrainz and Last.fm providers with a configurable fallback chain
  that retains Discogs support.
- Improved movie, TV and music release parsing, provider formatting and
  automatic metadata announcements.
- Added optional PreDB.net lookups through `https://api.predb.net/`.
- Added `!predb <query>` for direct remote PRE searches.
- Made `!pre <query>` fall back to PreDB.net only when the local MySQL/TSV
  database has no matching releases.
- Normalized remote release metadata to the existing PRE result format,
  including conversion from PreDB.net MB sizes to dZSbot's internal KB unit.
- Kept local PRE searches available when the remote API is disabled,
  unavailable or times out.
- Improved PRE storage, latest-result delivery, activity filtering, theme
  output and MySQL fallback behavior.
- Improved bundled Tcl package discovery for Tcl 8.6 and Tcl 9 installations.
- Added dZSbot/ioFTPD icon assets and ioFTPD 8.1 free-space maintenance
  scripts.
- Added regression coverage for remote response normalization and local-first
  fallback behavior, metadata parsing and PRE activity/statistics.

## 2.0.4 - 2026-07-19

- Made PRE-BW release-specific by matching `ioftpd who` paths to the PRE event,
  excluding unrelated site traffic and suppressing idle samples by default.
- Added theme templates for classic PRE announcements, PRE search results,
  bandwidth activity and daily PRE statistics.
- Added theme templates for IMDb/TV detail headers and all detail rows sent to
  the staff channel.
- Fixed automatic OMDb lookups for movie and TV uploads by separating the
  release year from the title and sending it through OMDb's `y` parameter.
- Improved scene-release parsing so video, audio, language, region and release
  group tags are excluded from IMDb searches.
- Added Nordic language/region handling for tags such as `NORDiC`, `SWEDISH`,
  `DANISH`, `NORWEGIAN`, `FINNISH`, `SUBBED`, `DUBBED` and `DUAL`.
- Added regression coverage for numbered movie titles and Nordic releases,
  including `Zodiac.2007.NORDiC.1080p.BluRay.x264-GROUP`.

## 2026-07-18

- Added Tcl 9.0.2 runtime support for Cygwin/Eggdrop builds.
- dZSbot now prefers `/opt/tcl-9.0.2/lib` or `/opt/tcl9.0.2/lib` when present,
  while keeping Tcl 8.6.18 paths as fallback.
- Documented Tcl 9 TDBC/MySQL package layout and Windows ASR/DLL loading notes.

## 2026-06-28

Project started.

A complete rewrite of the original sitebot architecture,
inspired by ioNiNJA but designed for modern Eggdrop, Tcl 8.6+/9.0
and modular development.
