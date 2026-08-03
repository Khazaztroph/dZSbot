# Site Adapters

dZSbot should not couple the Core directly to one FTP daemon. ioFTPD, glFTPD,
and drFTPD are treated as adapters.

## Communication Model

There are two different communication directions:

- Events from the site daemon into dZSbot.
- Commands/status queries from dZSbot back to the site daemon.

These do not need to use the same transport.

## ioFTPD

Recommended model:

- Event source: local scripts/log files generated on the same machine.
- Command transport: FTPS with explicit TLS.

Local event files do not cross the network and can be allowed even when plain
FTP is disabled. Any network command/control channel should use TLS.

## glFTPD

Recommended model:

- Event source: local scripts/logs, or a small local relay.
- Command transport: FTPS/SFTP/local command adapter depending on setup.

## drFTPD

Recommended model:

- Event source: API/log relay.
- Command transport: HTTPS API or FTPS if exposed.

## FluxFTP

FluxFTP starts as a disabled HTTP API adapter in
`core/adapters/fluxftp.tcl`. It is configured through
`config/adapters/fluxftp.conf`:

```tcl
::dZSbot::Config::Set fluxftp.enabled 0
::dZSbot::Config::Set fluxftp.base_url "http://127.0.0.1:port"
```

The same `base_url` setting is used for local and remote FluxFTP APIs. See
`docs/FLUXFTP.md` for endpoint mapping and PRE sync policy.

## TLS Policy

Configured in `config/dzsbot.conf`:

```tcl
::dZSbot::Config::Set site.adapter "ioftpd"
::dZSbot::Config::Set site.host "127.0.0.1"
::dZSbot::Config::Set site.port 5420
::dZSbot::Config::Set site.user "sitebot"
::dZSbot::Config::Set site.password "secret"
::dZSbot::Config::Set site.ioftpd.config_path "C:/ioFTPD/system/ioFTPD.ini"
::dZSbot::Config::Set site.ioftpd.log_path "C:/ioFTPD/logs"
::dZSbot::Config::Set site.ioftpd.message_window "ioFTPD::MessageWindow"
::dZSbot::Config::Set site.event_transport "local"
::dZSbot::Config::Set site.command_transport "ftps"
::dZSbot::Config::Set site.passive 1
::dZSbot::Config::Set site.passive_ports "5421-5450"
::dZSbot::Config::Set site.tls.required 1
::dZSbot::Config::Set site.tls.min_version "1.3"
::dZSbot::Config::Set site.allow_plain_event_source 1
```

This means:

- Local ioFTPD event/log/script input is allowed.
- Active network communication back to `site.host:site.port` must be secure.
- The intended minimum TLS version is TLS 1.3.

Actual TLS 1.3 support depends on the Tcl TLS/OpenSSL build or the external
adapter binary used for FTPS/SFTP/HTTPS.

For the current ioFTPD setup, see `docs/IOFTPD_INTEGRATION.md`.

## Internal Flow

```text
ioFTPD/glFTPD/drFTPD
  -> adapter
  -> ::dZSbot::Transport event
  -> modules
  -> formatter/theme
  -> Eggdrop/IRC
```

Modules should not talk directly to FTP daemons. They should consume events and
Core services.

## Release Events

Site adapters should publish release events as Tcl dict payloads:

```tcl
::dZSbot::Transport::Publish site.release [dict create \
    section MOVIES \
    release Example.Release.2026.1080p.WEB.H264-GROUP \
    path /site/MOVIES/Example.Release.2026.1080p.WEB.H264-GROUP]
```

Modules such as IMDb can then react without knowing whether the source was
ioFTPD, glFTPD, or drFTPD.
