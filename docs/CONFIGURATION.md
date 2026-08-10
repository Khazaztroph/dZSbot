# Configuration

dZSbot uses one main config file and one config file per module.

## Main Config

```text
config/dzsbot.conf
```

Use the main config for Core and site-wide settings:

- database/MySQL settings
- active theme name
- admin status command policy
- site adapter settings
- TLS policy
- paths that belong to Core

Admin status command:

```tcl
::dZSbot::Config::Set status.admin_channel "#staff"
::dZSbot::Config::Set status.require_channel_op 1
```

Daily GitHub release checks:

```tcl
::dZSbot::Config::Set update_check.enabled 1
::dZSbot::Config::Set update_check.channel ""
::dZSbot::Config::Set update_check.interval_seconds 86400
::dZSbot::Config::Set update_check.timeout_ms 10000
```

dZSbot checks GitHub Releases at most once per interval and stores the last
check time under `runtime/`. A message is sent to the configured admin channel
only when the latest release tag is newer than the installed version. Network
and API errors are logged without posting an IRC message. Leave
`update_check.channel` empty to follow `status.admin_channel`.

With this enabled, `!dzb status` only works for channel operators in `#staff`.

## Theme Configs

```text
config/themes/<theme>.conf
```

The active theme is selected in `config/dzsbot.conf`:

```tcl
::dZSbot::Config::Set theme.name "default"
```

The default theme lives in `config/themes/default.conf`. To enable IRC colors:

```tcl
::dZSbot::Config::Set theme.irc.colors 1
```

Common color slots:

```tcl
::dZSbot::Config::Set theme.color.c1 "08"
::dZSbot::Config::Set theme.color.c2 "03"
::dZSbot::Config::Set theme.color.c3 "06"
```

Section-specific colors can override the defaults:

```tcl
::dZSbot::Config::Set theme.section.MOVIES.c1 "05"
::dZSbot::Config::Set theme.section.TV.c1 "06"
::dZSbot::Config::Set theme.section.MUSIC.c1 "10"
```

Templates can be adjusted without changing module code:

```tcl
::dZSbot::Config::Set theme.template.music.public "%tag{{tag}} %c2{{title}} ({year}) | %c3{{formats}} | {labels}"
```

IMDb details sent to the staff channel have separate templates for the header
and every detail row:

```tcl
::dZSbot::Config::Set theme.template.imdb.detail.header "IMDb details for %c2{{release}}:"
::dZSbot::Config::Set theme.template.imdb.detail.title "%bold{{title}} ({year}) | %c3{{label}} | {summary}"
::dZSbot::Config::Set theme.template.imdb.detail.genre "%c1{Genre}: {genre}"
::dZSbot::Config::Set theme.template.imdb.detail.rating "%c1{IMDb}: %c3{{rating}/10}{bar_suffix} ({votes} votes)"
::dZSbot::Config::Set theme.template.imdb.detail.director "%c1{Director}: {director}"
::dZSbot::Config::Set theme.template.imdb.detail.actors "%c1{Actors}: {actors}"
::dZSbot::Config::Set theme.template.imdb.detail.plot "%c1{Plot}: {plot}"
::dZSbot::Config::Set theme.template.imdb.detail.url "%muted{{url}}"
::dZSbot::Config::Set theme.template.tv.detail.header "TV details for %c2{{release}}:"
```

Available placeholders include `{release}`, `{title}`, `{year}`, `{label}`,
`{summary}`, `{genre}`, `{rating}`, `{votes}`, `{bar}`, `{bar_suffix}`,
`{director}`, `{actors}`, `{plot}` and `{url}`.

PRE announcements, search results, bandwidth activity and daily statistics are
also independently themeable:

```tcl
::dZSbot::Config::Set theme.template.pre.announce.classic "%c1{{pre_type}}: %c2{{release}} | %c3{{section}} | {group} | {files}F/{size}"
::dZSbot::Config::Set theme.template.pre.result "%c1{{prefix}}: %c2{{release}} | %c3{{section}} | {age} ago | {user}/{group} | {size} | {files}F"
::dZSbot::Config::Set theme.template.pre.activity "%tag{{section}}%tag{RACER} :: %c2{{release}} :: {racer} :: {speed_compact}"
::dZSbot::Config::Set theme.template.pre.stats.header "%c1{PRE {title} Stats}: %c2{{label}} | %c3{{releases} releases} | {files}F | %c4{{size}}"
::dZSbot::Config::Set theme.template.pre.stats.top "%c1{PRE Top {label}}: %c2{{entries}}"
::dZSbot::Config::Set theme.template.requests.added "%tag{req} %bold{{u_name}} requests %c2{{request}}."
::dZSbot::Config::Set theme.template.requests.filled "%tag{req}%tag{FILL} %bold{{u_name}} filled %c2{{request}} for %bold{{u_requester}}."
::dZSbot::Config::Set theme.template.requests.deleted "%tag{req}%tag{DEL} %bold{{u_name}} deleted %c2{{request}}."
::dZSbot::Config::Set theme.template.upload.newdir "%tag{{tag}}%tag{{section}} :: %c2{{release}} ::"
::dZSbot::Config::Set theme.template.upload.first "%tag{{section}}%tag{FIRST} in %c2{{release}} by {user} - {speed_compact} :: release size - {size_compact} ::"
::dZSbot::Config::Set theme.template.upload.half "%tag{{section}}%tag{HALF} :: %c2{{release}} :: {user} :: with {files_label} :: {percent} :: {size_compact} :: {speed_compact}{others_segment}{eta_segment}"
::dZSbot::Config::Set theme.template.upload.racer "%tag{{section}}%tag{RACER} :: %c2{{release}} :: {user} :: {speed_compact}"
::dZSbot::Config::Set theme.template.upload.leader "%tag{{section}}%tag{LEADER} :: %c2{{release}} :: {user}"
::dZSbot::Config::Set theme.template.upload.complete "%tag{{tag}}%tag{{section}} :: %c2{{release}} :: {files_label} :: {size_compact}{duration_segment}{speed_segment} :: {user}"
::dZSbot::Config::Set theme.template.upload.badfile "%tag{{reason}} :: %c4{{user}} :: %c2{{release}} :: {file}"
::dZSbot::Config::Set theme.template.upload.nfo "%tag{{section}}%tag{NFO} in %c2{{release}} by {user} - {file} ::"
::dZSbot::Config::Set theme.template.upload.doublesfv "%tag{DOUBLESFV} :: %c4{{user}} :: %c2{{release}} :: {file}"
::dZSbot::Config::Set theme.template.upload.speedtest "%tag{SPEED} :: {user} :: {size_compact} :: {speed_compact} ::"
::dZSbot::Config::Set theme.template.upload.incomplete "%tag{INCOMPLETE}%tag{{section}} %c4{{release}} by {user} ::"
```

The default theme also includes `theme.template.legacy.*` entries based on old
pzs-ng/ioNiNJA announce names, such as `legacy.wipe`, `legacy.nuke`,
`legacy.unnuke`, `legacy.newdate`, `legacy.search.*`, `legacy.nukes.*` and
`legacy.prebw`. These are template-ready for compatibility modules even when a
specific parser or command has not been implemented yet.

## Module Configs

```text
config/modules/<module>.conf
```

The module manager loads a module config before loading the module itself.

Current module config files:

- `config/modules/imdb.conf`
- `config/modules/legacy.conf`
- `config/modules/music.conf`
- `config/modules/nfo.conf`
- `config/modules/pre.conf`
- `config/modules/requests.conf`
- `config/modules/retention.conf`
- `config/modules/site.conf`
- `config/modules/tv.conf`
- `config/modules/upload.conf`

Examples:

```tcl
# config/modules/imdb.conf
::dZSbot::Config::Set omdb.api_key "YOUR_KEY_HERE"
```

```tcl
# config/modules/music.conf
::dZSbot::Config::Set music.provider "auto"
::dZSbot::Config::Set music.providers {musicbrainz lastfm discogs}
::dZSbot::Config::Set lastfm.api_key "YOUR_KEY_HERE"
::dZSbot::Config::Set discogs.auth_mode "token"
::dZSbot::Config::Set discogs.token "YOUR_TOKEN_HERE"
```

Music providers:

- `musicbrainz` - default first provider. No API key is required, but a real User-Agent is required.
- `lastfm` - optional fallback. Requires `lastfm.api_key`.
- `discogs` - optional fallback. Supports token, key/secret, OAuth, or unauthenticated mode.

Discogs auth modes:

- `token` - recommended for dZSbot. Uses `Authorization: Discogs token=...`.
- `query_token` - legacy-compatible token in the query string.
- `key_secret` - uses `discogs.consumer_key` and `discogs.consumer_secret`.
- `oauth` - uses a completed OAuth access token and access token secret.
- `none` - unauthenticated requests, limited and not recommended for search.

OAuth endpoint defaults:

```tcl
::dZSbot::Config::Set discogs.oauth.request_token_url "https://api.discogs.com/oauth/request_token"
::dZSbot::Config::Set discogs.oauth.authorize_url "https://www.discogs.com/oauth/authorize"
::dZSbot::Config::Set discogs.oauth.access_token_url "https://api.discogs.com/oauth/access_token"
```

```tcl
# config/modules/requests.conf
::dZSbot::Config::Set requests.storage [file join $::dZSbot::Root database requests.tsv]
::dZSbot::Config::Set requests.list_limit 10
```

Upload announces can be enabled globally, filtered by event name, and toggled
one by one. Current defaults announce important state changes and integrity
events, while leaving noisy per-file `racer` output disabled:

```tcl
::dZSbot::Config::Set upload.announce.enabled 1
::dZSbot::Config::Set upload.announce.events {newdir first half leader complete badfile nfo doublesfv speedtest incomplete}
::dZSbot::Config::Set upload.announce.event.racer.enabled 0
::dZSbot::Config::Set upload.announce.event.complete.enabled 1
```

```tcl
# config/modules/pre.conf
::dZSbot::Config::Set pre.backend "mysql"
::dZSbot::Config::Set pre.mysql.table "predb"
```

```tcl
# config/modules/site.conf
::dZSbot::Config::Set site.df.sections {
    {MOVIES "D:/ioFTPD/FTP-ROOT-DIR/MOVIES"}
    {TV "//nas/site/TV"}
    {MUSIC "E:/FTP/MUSIC"}
}
```

Use forward slashes in Windows and UNC paths. Tcl treats backslashes as escape
characters, so forward slashes avoid broken list values such as `unmatched open
quote in list`. A dict-style configuration is also supported:

```tcl
::dZSbot::Config::Set site.df.sections [dict create \
    MOVIES "D:/ioFTPD/FTP-ROOT-DIR/MOVIES" \
    TV "//nas/site/TV" \
    MUSIC "E:/FTP/MUSIC"]
```

The `site` module provides `!df` and `!bw`. Disk free uses the configured
section paths. Bandwidth uses a small ioFTPD-side cache exporter by default.
See `docs/SITE_COMMANDS.md` for the complete setup guide.

```tcl
::dZSbot::Config::Set site.commands.df.source "cache"
::dZSbot::Config::Set site.commands.df.cache_file "C:/ioFTPD/logs/dzsbot-df.tsv"
::dZSbot::Config::Set site.commands.df.cache_max_age_seconds 300
::dZSbot::Config::Set site.commands.bw.source "cache"
::dZSbot::Config::Set site.commands.bw.cache_file "C:/ioFTPD/logs/dzsbot-bw.tsv"
::dZSbot::Config::Set site.commands.bw.cache_max_age_seconds 15
```

Install `scripts/dzsbot_ioftpd_bw.tcl` on the ioFTPD side and run it from
ioFTPD, writing to the same `site.commands.bw.cache_file`. The command can be
called as:

```text
TCL ..\scripts\dzsbot_ioftpd_bw.tcl BW C:/ioFTPD/logs/dzsbot-bw.tsv
```

`site.commands.bw.source` also accepts `ioftpd` when dZSbot runs inside the
ioFTPD Tcl environment. `site`, `ftp`, and `ftps` remain available as manual
diagnostic fallbacks, but they are not recommended for live bandwidth because
`SITE TRAFFIC`/`SITE STATS` normally report site statistics/status instead of
current transfer speed.

The FTP control connection is configured for Tcl 9 compatibility with CRLF
translation and `iso8859-1` encoding. Do not use Tcl 8's old
`-encoding binary` form for FTP control sockets.

This keeps `config/dzsbot.conf` small and makes each module easier to configure.
