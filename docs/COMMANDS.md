# Commands

dZSbot 2.0 keeps old-style IRC commands through a modern command registry.
Modules register commands with `::dZSbot::Commands::Register`, and Eggdrop gets
normal `bind pub` bindings when available.

## Registered Commands

- `!imdb <title>`, `!movie <title>`, `!movies <title>`: OMDb/IMDb movie lookup.
- `!music <artist/title/release>`: music lookup through Discogs for MP3, FLAC, and future formats.
- `!flac <artist/title/release>`: FLAC-specific compatibility lookup.
- `!musicinfo`: show music module format support.
- `!tv <show>`, `!show <show>`: TV compatibility lookup.
- `!nfo <release>`: show stored NFO summary.
- `!pre [query]`: search PRE entries.
- `!predb <query>`: search PreDB.net directly.
- `!pres`: show latest PRE entries.
- `!addpre <release> ?section? ?user? ?group? ?size_kb? ?files?`: add a PRE entry.
- `!preimport nxtools ?Pres.db path?`: import nxTools PRE entries. Requires staff/op access.
- `!df [section]`: show configured site disk free space.
- `!bw`: show live ioFTPD transfer bandwidth from the dZSbot ioFTPD cache exporter.
- `!request <release/title>`, `!req <release/title>`: add a request.
- `!requests`: list open requests.
- `!reqfill <release/title>`: mark an open request as filled.
- `!reqdel <release/title>`: delete an open request.
- `!retention`: show retention/core health.
- `!status`, `!dzsbot`: show loaded module and command counts.
- `!dzb status`: show admin runtime status. Requires channel op in the configured staff channel.

## OMDb

Set your key in `config/modules/imdb.conf`:

```tcl
::dZSbot::Config::Set omdb.api_key "YOUR_KEY_HERE"
```

The IMDb module uses `https://www.omdbapi.com/` by default.

IMDb supports movies and TV series:

- movie title lookups: `!imdb Blade Runner`
- TV series lookups: `!imdb The Last of Us`
- IMDb ID lookups: `!imdb tt0083658`
- automatic search fallback: when OMDb's exact title lookup returns “not found”,
  dZSbot searches by title/year/type and fetches the best result by IMDb ID
- cache: `omdb.cache_seconds`
- search fallback toggle: `omdb.search_fallback`
- flood protection: `omdb.max_requests` and `omdb.period_seconds`
- optional Eggdrop channel flag: `omdb.require_channel_flag`

IMDb can also react to site release events published by the site adapter. Public
summary goes to `imdb.announce.pre_channel`; detailed/admin output goes to
`imdb.announce.staff_channel`.

## Music

The music module can use multiple metadata providers when uploads or PRE events
arrive. The default chain is:

```tcl
::dZSbot::Config::Set music.providers {musicbrainz lastfm discogs}
```

MusicBrainz works without an API key. Last.fm requires `lastfm.api_key`.
Discogs remains available for richer release metadata when configured.
