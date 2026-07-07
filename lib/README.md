# dZSbot Tcl Packages

This directory contains Tcl packages loaded before the system Tcl paths.

Bundled runtime packages:

- `http` - HTTP client used by OMDb and Discogs lookups.
- `json` - JSON parser used by API modules.
- `tls` - HTTPS/TLS socket support.
- `base64` - Encoding support used by OAuth signing.
- `sha1` - HMAC-SHA1 support used by OAuth signing.
- `oauth` - OAuth 1.0a header support for providers such as Discogs.
- `sqlite3` - SQLite reader used for nxTools `Pres.db` imports.
- `tdbc` - Tcl database connectivity base package.
- `tdbc::mysql` - MySQL/MariaDB driver for modern MySQL support.

`mysqltcl` is still supported by Core when it is installed globally, but it is
not bundled here because no matching local `mysqltcl` runtime package was found.
When `mysqltcl` is unavailable, dZSbot falls back to `tdbc::mysql`.
