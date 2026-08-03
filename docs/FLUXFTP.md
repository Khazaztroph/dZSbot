# FluxFTP Adapter

dZSbot has a disabled-by-default FluxFTP adapter scaffold in:

```text
core/adapters/fluxftp.tcl
```

The goal is to let dZSbot consume FluxFTP through the same normalized site
adapter model as ioFTPD, glFTPD and drFTPD. Existing ioFTPD log/cache behavior
continues to work while FluxFTP endpoints are tested.

## Config

Config lives in:

```text
config/adapters/fluxftp.conf
```

Default config:

```tcl
::dZSbot::Config::Set fluxftp.enabled 0
::dZSbot::Config::Set fluxftp.base_url "http://127.0.0.1:port"
::dZSbot::Config::Set fluxftp.api_key ""
::dZSbot::Config::Set fluxftp.auth_header "Authorization"
::dZSbot::Config::Set fluxftp.auth_scheme "Bearer"
::dZSbot::Config::Set fluxftp.timeout_ms 5000
::dZSbot::Config::Set fluxftp.tls_verify 1
```

Local and remote API usage share the same setting:

```tcl
::dZSbot::Config::Set fluxftp.base_url "http://127.0.0.1:8080"
::dZSbot::Config::Set fluxftp.base_url "https://fluxftp.example.net/api"
```

For CBFTP-compatible APIs such as RaceTrade/FluxFTP on port `55477`, the API
root is normally the port itself, not `/api`:

```tcl
::dZSbot::Config::Set fluxftp.base_url "https://127.0.0.1:55477"
```

Endpoint paths are configurable until the final FluxFTP API shape is confirmed:

```tcl
::dZSbot::Config::Set fluxftp.endpoint.health "health"
::dZSbot::Config::Set fluxftp.endpoint.users "users"
::dZSbot::Config::Set fluxftp.endpoint.bandwidth "transfers"
::dZSbot::Config::Set fluxftp.endpoint.diskfree "sections"
::dZSbot::Config::Set fluxftp.endpoint.recent_uploads "uploads/recent"
::dZSbot::Config::Set fluxftp.endpoint.pre_search "pre"
```

## Adapter Functions

The scaffold exposes these normalized calls:

```tcl
::dZSbot::Adapter::FluxFTP::Health
::dZSbot::Adapter::FluxFTP::Bandwidth
::dZSbot::Adapter::FluxFTP::DiskFree
::dZSbot::Adapter::FluxFTP::Users
::dZSbot::Adapter::FluxFTP::RecentUploads
::dZSbot::Adapter::FluxFTP::PreSearch
```

They return Tcl dicts, not raw JSON. This keeps modules independent of FluxFTP's
wire format.

## PRE Strategy

PRE remains owned by dZSbot MySQL/TSV by default:

```tcl
::dZSbot::Config::Set pre.backend "mysql"
::dZSbot::Config::Set pre.fluxftp.enabled 0
::dZSbot::Config::Set pre.fluxftp.mode "off"
```

Supported modes:

```text
off
read
sync
primary
```

Use `read` to keep dZSbot local/MySQL-first and query FluxFTP only when the
local PRE database has no match:

```tcl
::dZSbot::Config::Set pre.fluxftp.enabled 1
::dZSbot::Config::Set pre.fluxftp.mode "read"
```

Use `primary` only when FluxFTP should be searched before the local PRE store.
The legacy value `on` is accepted as a read-mode alias.

## !bw And !df Through FluxFTP

The site commands can read directly from FluxFTP:

```tcl
::dZSbot::Config::Set site.commands.bw.source "fluxftp"
::dZSbot::Config::Set site.commands.df.source "fluxftp"
```

Both commands keep cache fallback enabled by default:

```tcl
::dZSbot::Config::Set site.commands.bw.fallback "cache"
::dZSbot::Config::Set site.commands.df.fallback "cache"
```

That gives a good production setup: FluxFTP is used when available, and the
existing ioFTPD/cache exporters can still answer if the API is down.

## Expected API Shape

The adapter is intentionally tolerant and accepts common JSON wrappers such as
`items`, `data`, `transfers`, `sections`, `users`, `uploads` or `releases`.

Useful endpoints to verify during RaceTrade testing:

```text
GET /health
GET /users
GET /transfers
GET /sections
GET /uploads/recent
GET /pre?query=<release>&limit=5
POST /pre
```

Once FluxFTP's final endpoint names and response bodies are confirmed, map them
in `config/adapters/fluxftp.conf`.
