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

## Module Configs

```text
config/modules/<module>.conf
```

The module manager loads a module config before loading the module itself.

Current module config files:

- `config/modules/imdb.conf`
- `config/modules/music.conf`
- `config/modules/nfo.conf`
- `config/modules/pre.conf`
- `config/modules/requests.conf`
- `config/modules/retention.conf`
- `config/modules/tv.conf`

Examples:

```tcl
# config/modules/imdb.conf
::dZSbot::Config::Set omdb.api_key "YOUR_KEY_HERE"
```

```tcl
# config/modules/music.conf
::dZSbot::Config::Set discogs.auth_mode "token"
::dZSbot::Config::Set discogs.token "YOUR_TOKEN_HERE"
```

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

```tcl
# config/modules/pre.conf
::dZSbot::Config::Set pre.backend "mysql"
::dZSbot::Config::Set pre.mysql.table "predb"
```

This keeps `config/dzsbot.conf` small and makes each module easier to configure.
