# dZSbot Documentation

Start here when installing, configuring or troubleshooting dZSbot.

## Quick Start

- [Install](../INSTALL.md)
- [Quick Start](QUICK_START.md)

Install dZSbot, load it from Eggdrop and verify the basic runtime.

## Config Files

- [Config Files](CONFIG_FILES.md)
- [Configuration Reference](CONFIGURATION.md)

Where each config file lives, what it controls and which files should be
merged carefully during upgrades.

## IRC Themes

- [IRC Themes](IRC_THEMES.md)

Colors, bold text, tags, templates and how to change announce output without
editing module code.

## ioFTPD / nxTools Events

- [ioFTPD / nxTools Events](IOFTPD_INTEGRATION.md)
- [Legacy Bundle](LEGACY_BUNDLE.md)

How dZSbot reads ioFTPD and nxTools log events for uploads, PRE, NEWDATE,
NUKE, requests and legacy compatibility announces.

## FluxFTP API

- [FluxFTP API](FLUXFTP.md)

FluxFTP/RaceTrade API setup for fast live status, `!bw`, `!df` and optional
PRE search fallback.

## Commands

- [Commands](COMMANDS.md)
- [Site Commands: !df and !bw](SITE_COMMANDS.md)
- [Auto IRC Flags](IRC_FLAGS.md)
- [Requests](REQUESTS.md)
- [PRE](PRE.md)

IRC commands and command-specific setup.

## MySQL / TSV Storage

- [MySQL / TSV Storage](MYSQL_TSV_STORAGE.md)
- [Database Reference](DATABASE.md)

How dZSbot stores PRE data and requests, how MySQL fallback works and what is
needed for Tcl/MySQL DLLs.

## Upgrade Guide

- [Upgrade Guide](UPGRADE_GUIDE.md)

How to update dZSbot without overwriting local configuration.

## Troubleshooting

- [Troubleshooting](TROUBLESHOOTING.md)

Common problems, where to look first and which config file usually controls
the behavior.

## Developer Reference

- [Architecture](ARCHITECTURE.md)
- [Architecture Philosophy](ARCHITECTURE_PHILOSOPHY.md)
- [Core](CORE.md)
- [Developer Guide](DEVELOPER_GUIDE.md)
- [Plugin API](PLUGIN_API.md)
- [Site Adapters](SITE_ADAPTERS.md)
- [Transport](TRANSPORT.md)
- [Health](HEALTH.md)
- [Contributing](CONTRIBUTING.md)
- [Changelog](CHANGELOG.md)
