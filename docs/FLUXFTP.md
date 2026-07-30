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
::dZSbot::Config::Set fluxftp.base_url "http://127.0.0.1:port/api"
::dZSbot::Config::Set fluxftp.api_key ""
::dZSbot::Config::Set fluxftp.auth_header "Authorization"
::dZSbot::Config::Set fluxftp.auth_scheme "Bearer"
::dZSbot::Config::Set fluxftp.timeout_ms 5000
::dZSbot::Config::Set fluxftp.tls_verify 1
```

Local and remote API usage share the same setting:

```tcl
::dZSbot::Config::Set fluxftp.base_url "http://127.0.0.1:8080/api"
::dZSbot::Config::Set fluxftp.base_url "https://fluxftp.example.net/api"
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

PRE remains owned by dZSbot MySQL/TSV for now:

```tcl
::dZSbot::Config::Set pre.backend "mysql"
::dZSbot::Config::Set pre.fluxftp.enabled 0
::dZSbot::Config::Set pre.fluxftp.mode "off"
```

Future modes:

```text
off
read
write
sync
primary
```

Start with `read` or `write` after FluxFTP PRE endpoints are tested. Avoid
`primary` until the API has been proven stable in production.

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
in `config/adapters/fluxftp.conf` and wire `!bw`, `!df` and optional PRE sync to
the adapter.
