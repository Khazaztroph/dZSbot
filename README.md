# dZBot
dZSbot is a modular framework for Eggdrop, designed for modern ioFTPD environments.

Inspired by ioNiNJA, built for today.

## Runtime

dZSbot supports Tcl 8.6+ and is tested with Tcl 9.0.2 on Cygwin/Eggdrop.

Normal Eggdrop start:

```text
eggdrop.exe eggdrop.conf
```

Debug/foreground start:

```text
eggdrop.exe -t eggdrop.conf
```

Use `eggdrop.exe -m eggdrop.conf` only when creating a fresh Eggdrop userfile.

## Documentation

Start with the [Documentation Index](docs/README.md).

- [Install](INSTALL.md)
- [Quick Start](docs/QUICK_START.md)
- [Config Files](docs/CONFIG_FILES.md)
- [Legacy Bundle](docs/LEGACY_BUNDLE.md)
- [IRC Themes](docs/IRC_THEMES.md)
- [ioFTPD / nxTools Events](docs/IOFTPD_INTEGRATION.md)
- [FluxFTP API](docs/FLUXFTP.md)
- [Commands](docs/COMMANDS.md)
- [MySQL / TSV Storage](docs/MYSQL_TSV_STORAGE.md)
- [Upgrade Guide](docs/UPGRADE_GUIDE.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
