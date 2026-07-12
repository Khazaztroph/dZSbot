# dZSbot Developer Guide

Version 1.0

## Vision

dZSbot 2.0 is a modern rewrite of dZSbot for Eggdrop and ioFTPD environments.
The goal is to keep the practical command behaviour from older dZSbot/ioNiNJA
setups while rebuilding the internals around a stable core, isolated modules,
and clear APIs.

The project should feel familiar to existing users, but easier to maintain,
extend, test, and reason about.

## Core Principles

- Every component has a single responsibility.
- Expected failures are handled.
- Unexpected failures are isolated.
- The Core provides services.
- Feature modules consume Core services.
- Runtime state has one owner.
- Module names describe responsibility, not implementation details.
- Compatibility commands are aliases, not architecture.
- Maintainability wins over cleverness.

## Architecture

The Core is intentionally small and stable. It owns startup, logging,
configuration, health, metrics, command registration, module loading, and
internal transport.

Modules are loaded by the module manager. A broken module should never bring
down the Core or unrelated modules.

The current Core services are:

- `Logger`: logging through Eggdrop with a tclsh fallback.
- `Config`: runtime configuration values.
- `Database`: database/runtime path initialization.
- `Theme`: theme state.
- `Commands`: Eggdrop command compatibility layer.
- `SiteAdapter`: site daemon adapter policy and registry.
- `Transport`: internal event bus.
- `Metrics`: counters and runtime values.
- `Health`: component state and heartbeat output.
- `ModuleManager`: module discovery, loading, and registry.

## Folder Structure

```text
core/
  bootstrap.tcl
  commands.tcl
  siteadapter.tcl
  config.tcl
  database.tcl
  health.tcl
  logger.tcl
  metrics.tcl
  packages.tcl
  modulemanager.tcl
  theme.tcl
  transport.tcl
  version.tcl

modules/
  imdb/
  music/
  nfo/
  pre/
  requests/
  retention/
  tv/

config/
database/
docs/
runtime/
tests/
tools/
```

## Domain Modules

Module names describe what the module is responsible for, not which file format
or provider it happens to use.

Good module names:

- `movies`
- `tv`
- `music`
- `games`
- `books`
- `pre`
- `requests`
- `stats`
- `status`
- `health`
- `system`

Avoid format-specific top-level module names such as `mp3`, `flac`, or `tmdb`.
Those belong inside domain modules.

Example:

```text
modules/music/
  music.tcl
  mp3.tcl
  flac.tcl
  parser.tcl
  formatter.tcl
```

This lets `music` support MP3 and FLAC today, then M4A, AAC, OGG, or Opus later
without renaming the module.

## Compatibility Commands

Old commands should keep working where possible. They are registered through
`::dZSbot::Commands::Register` and mapped into modern modules.

Examples:

- `!imdb`, `!movie`, and `!movies` map to movie lookup.
- `!music` maps to the `music` module and covers MP3, FLAC, and future formats.
- `!flac` is kept as a format-specific compatibility alias where needed.
- `!req` maps to the `requests` module.

This preserves user muscle memory while keeping the internal design clean.

## Module API

A module entry point lives at:

```text
modules/<name>/<name>.tcl
```

The module should register commands and then register itself:

```tcl
::dZSbot::Commands::Register music !music ::dZSbot::Modules::Music::CmdMusic

::dZSbot::ModuleManager::Register music [dict create \
    version 0.1.0 \
    description "Music lookup module" \
    commands [::dZSbot::Commands::List music]]
```

Modules should use Core services instead of calling Eggdrop directly.

## Logger

Only `core/logger.tcl` should call `putlog` directly.

Modules should use:

```tcl
::dZSbot::Logger::Info "message"
::dZSbot::Logger::Warn "message"
::dZSbot::Logger::Error "message"
::dZSbot::Logger::Debug "message"
```

IRC replies should go through:

```tcl
::dZSbot::Commands::Reply $nick $chan "message"
```

## Config

Configuration is stored through `::dZSbot::Config`.

Example:

```tcl
::dZSbot::Config::Set omdb.api_key "YOUR_KEY_HERE"
::dZSbot::Config::Get omdb.api_key ""
```

Secrets such as API keys belong in config, not in module source files. Core and
site-wide settings live in `config/dzsbot.conf`; module settings live in
`config/modules/<module>.conf`.

## Theme System

The theme system is a Core service for IRC-friendly output. It loads the active
theme from `config/themes/<name>.conf`, supports mIRC color codes, bold text,
section-specific color overrides, and simple templates.

Modules should keep content formatting local, but use `::dZSbot::Theme::Render`
for public announce lines where users expect a consistent look.

Example:

```tcl
::dZSbot::Theme::Render music.public [dict create \
    section MUSIC \
    title "Artist - Album" \
    year 2026 \
    formats "FLAC" \
    labels "Example Records"]
```

## Retention Engine

Retention belongs in its own module because it is operational behaviour, not
content metadata. It should report status through Core health and use shared
storage/database services as those mature.

## FTP Adapters

ioFTPD, glFTPD, and drFTPD integration should be treated as adapter layers. The
Core should not depend directly on a single FTP daemon implementation.

Future adapters can publish events into the Core transport layer:

```text
ioFTPD -> adapter -> transport event -> modules
```

This keeps Eggdrop, ioFTPD, ioGUI, and future integrations consuming the same
runtime truth.

Network communication back to a site daemon should use the configured secure
transport policy. For ioFTPD setups where local event/log input is allowed but
all remote control traffic must use TLS 1.3, use `site.event_transport local`
and `site.command_transport ftps`.

## Startup UX

Eggdrop startup should show a clear loading status:

```text
[dZSbot]
Version: dZSbot 2.0.0-dev (Build 20260628)

Loading Core...
Loading Logger...
Loading Database...
Loading Theme...
Loading Modules...

Movies.........OK
Music..........OK
TV.............OK

dZSbot loaded and ready.
```

The exact modules shown depend on what is present and loaded.

## Roadmap

Current direction:

- Finish Core bootstrap and startup status.
- Keep logger, config, metrics, health, transport, and command APIs stable.
- Build module compatibility for old dZSbot/ioNiNJA commands.
- Complete OMDb-backed movie lookup.
- Expand music parsing around MP3 and FLAC.
- Add real TV provider support.
- Mature retention, PRE, NFO, and request storage.
- Keep MySQL optional, with automatic table creation and TLS support where used.
- Add supervisor/status integrations.
- Add a future web status API.

## Design Decisions

- `music` is the module, while MP3 and FLAC are supported formats.
- Movie lookup keeps `!imdb` compatibility, but provider logic should stay
  replaceable.
- The Core should not contain feature logic.
- Modules should fail independently.
- Documentation should be updated as decisions are made.

This guide is the project memory. When a design decision becomes stable, it
should be written here or linked from here.

The high-level architecture philosophy is kept in
`docs/ARCHITECTURE_PHILOSOPHY.md`.
