# dZSbot Tcl Packages

This directory contains Tcl packages loaded before the system Tcl paths.

dZSbot supports Tcl 8.6+ and Tcl 9.0.2. The bundled DLL packages in this
directory may be runtime-specific, so a Tcl 9.0.2 Eggdrop should prefer matching
Tcl 9 packages from `/opt/tcl-9.0.2/lib` or `/opt/tcl9.0.2/lib` when available.
The startup script adds those paths automatically before falling back to Tcl 8.6
package paths.

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

Tcl 9 package builds use `cygtcl9...dll` filenames, for example:

- `cygtcl9tdbc1.1.11.dll`
- `cygtcl9tdbcmysql1.1.11.dll`
- `cygtcl9tls2.0.dll`

Keep extension DLLs matched to the Tcl runtime that Eggdrop was compiled with.
