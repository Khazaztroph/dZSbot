## 2.1.1 - 2026-08-04

- Fixed `!pres` and `!pre` in MySQL mode when PRE import had written rows to
  the TSV fallback store. MySQL is still preferred, but empty MySQL reads now
  fall back to TSV when `pre.mysql.fallback_to_tsv` is enabled.
- Added automatic one-shot MySQL reconnect/retry for queries and writes when an
  idle connection is closed by the server.
- Added configurable PRE stats periods through `pre.daily_stats.periods`, with
  built-in day, week and month summaries.
- Added regression coverage for MySQL-mode reads from TSV fallback storage.
- Added regression coverage for MySQL reconnect retry and multi-period PRE
  stats.

## 2.1.0 - 2026-08-03

- Promoted FluxFTP/RaceTrade support from scaffold to a usable adapter path for
  `!bw`, `!df` and PRE fallback reads.
- Added HTTPS transport registration for Tcl's `http` package and support for
  local self-signed FluxFTP TLS with `fluxftp.tls_verify 0`.
- Added Basic Auth support without requiring an external `base64` Tcl package.
- Made FluxFTP bandwidth lookup try CBFTP-compatible endpoints such as
  `transferjobs`, `spreadjobs` and `jobs` when `transfers` is unavailable.
- Normalized active CBFTP/RaceTrade jobs as `XFER` so IRC bandwidth output can
  show live race activity even when the API does not expose UP/DN direction.
- Renamed PRE bandwidth activity output from `PRE-BW` to `RACE`.
- Updated FluxFTP and site command documentation for RaceTrade/CBFTP-style API
  roots that use `https://host:port` rather than `/api`.

## 2.0.9 - 2026-07-30

- Improved IMDb upload parsing for `Custom` and regional subtitle tags.
- Added possessive-title and yearless OMDb search retries for scene names that
  omit apostrophes, such as `The.Devils.Mouth.2026`.
- Added an initial disabled FluxFTP HTTP API adapter under
  `core/adapters/fluxftp.tcl`, with configuration, tests and documentation.
- Added the approved dZSbot v2 logo variants in PNG and transparent ICO
  formats for Discord and future ioFTPD releases.

## 2.0.8 - 2026-07-27

- Fixed `!preimport nxtools` duplicate handling for MySQL by checking exact
  release names before insert.
- Added case-insensitive duplicate detection for both MySQL and TSV storage.
- Skipped repeated releases within the same nxTools `Pres.db` import and across
  repeated imports.
- Added a persistent daily GitHub Releases check based on the FluxFTP update
  checker.
- Added admin-channel notifications when a newer dZSbot release is available,
  while keeping network and API errors out of IRC.
- Added regression coverage for PRE duplicate detection, semantic version
  comparison, update caching, scheduling and notifications.
- Made startup tolerant of partial upgrades where `bootstrap.tcl` is updated
  before `core/updatecheck.tcl` or the main `dZSbot.tcl` entrypoint.

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

- Made RACE activity release-specific by matching `ioftpd who` paths to the PRE event,
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
