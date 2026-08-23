# Quick Start

This is the short path for getting dZSbot running under Eggdrop.

## Requirements

- Eggdrop 1.10 or newer.
- Tcl 8.6 or newer.
- Tcl 9.0.2 is supported when Tcl packages and DLLs match that runtime.
- ioFTPD, FluxFTP/RaceTrade or another supported site source.

## Install

1. Extract dZSbot under the Eggdrop scripts directory, for example:

```text
C:/ioFTPD/eggdrop/scripts/dZSbot
```

2. Load dZSbot from `eggdrop.conf`:

```tcl
source scripts/dZSbot/dZSbot.tcl
```

3. Start Eggdrop normally:

```text
eggdrop.exe eggdrop.conf
```

Use foreground/debug mode only when testing:

```text
eggdrop.exe -t eggdrop.conf
```

Use `-m` only when creating a fresh Eggdrop userfile.

## First Config

Start with these files:

```text
config/dzsbot.conf
config/modules/site.conf
config/modules/pre.conf
config/modules/upload.conf
config/modules/legacy.conf
config/themes/default.conf
```

Set your admin channel:

```tcl
::dZSbot::Config::Set status.admin_channel "#staff"
```

Set your site port if needed:

```tcl
::dZSbot::Config::Set site.port 5420
```

## Verify

In IRC:

```text
!dzb status
!bw
!df
!pres
```

`!dzb status` requires channel operator status in the configured staff channel
when `status.require_channel_op` is enabled.

## Next Steps

- Configure upload and legacy announces in [Config Files](CONFIG_FILES.md).
- Configure colors and output in [IRC Themes](IRC_THEMES.md).
- Configure `!bw` and `!df` in [Site Commands](SITE_COMMANDS.md).
- Configure FluxFTP/RaceTrade in [FluxFTP API](FLUXFTP.md).
- Configure MySQL or TSV storage in [MySQL / TSV Storage](MYSQL_TSV_STORAGE.md).
