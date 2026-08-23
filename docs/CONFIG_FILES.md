# Config Files

dZSbot uses one main config file and one config file per module. This keeps the
core stable and makes each feature easier to find.

## Main Config

```text
config/dzsbot.conf
```

Use this for site-wide settings:

- MySQL connection and TLS settings.
- Active theme name.
- Admin status channel.
- Site adapter defaults.
- ioFTPD host, port and TLS policy.
- Update check settings.

## Module Configs

```text
config/modules/<module>.conf
```

Current module config files:

```text
config/modules/imdb.conf
config/modules/ircflags.conf
config/modules/legacy.conf
config/modules/music.conf
config/modules/nfo.conf
config/modules/pre.conf
config/modules/requests.conf
config/modules/retention.conf
config/modules/site.conf
config/modules/tv.conf
config/modules/upload.conf
```

Important files:

- `legacy.conf` controls nxTools/ioNiNJA-style announces such as `NEWDATE`,
  `NUKE`, `UNNUKE`, `APPROVE`, `REQFILL` and `REQDEL`.
- `upload.conf` controls upload announces such as `NEW`, `FIRST`, `HALF`,
  `LEADER`, `COMPLETE`, `NFO`, `BADCRC` and `0SIZE`.
- `site.conf` controls `!df`, `!bw`, admin-only `!bnc` status checks and
  weekly quota/top uploader output, site action commands and `!incomplete`.
- `ircflags.conf` controls AutoIRCFlag-style mode assignment on join.
- `pre.conf` controls PRE storage, PRE search, imports and daily stats.
- `imdb.conf`, `tv.conf` and `music.conf` control metadata lookups.

## Adapter Configs

```text
config/adapters/fluxftp.conf
```

Use adapter configs for optional external APIs such as FluxFTP/RaceTrade.

## Theme Configs

```text
config/themes/default.conf
```

Theme files control colors, tags and IRC announce templates. See
[IRC Themes](IRC_THEMES.md).

## Upgrade Rule

Do not blindly overwrite existing config files during upgrades. Compare the new
config files with your current setup and merge only the new settings you need.

Good upgrade flow:

1. Backup your current `config/` directory.
2. Extract the new dZSbot release somewhere temporary.
3. Compare changed config files.
4. Copy new settings into your existing config.
5. Reload or restart Eggdrop.

See [Upgrade Guide](UPGRADE_GUIDE.md) for more detail.
