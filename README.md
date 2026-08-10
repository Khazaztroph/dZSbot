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

## Do not overwrite your existing config files blindly.
## Compare the new config files with your current setup and merge only the new
## settings you need.

## Documentation

- [Site Commands: !df and !bw](docs/SITE_COMMANDS.md)
- [Developer Guide](docs/DEVELOPER_GUIDE.md)
- [Architecture Philosophy](docs/ARCHITECTURE_PHILOSOPHY.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Core](docs/CORE.md)
- [Configuration](docs/CONFIGURATION.md)
- [Commands](docs/COMMANDS.md)
- [Database](docs/DATABASE.md)
- [PRE](docs/PRE.md)
- [Requests](docs/REQUESTS.md)
- [Site Adapters](docs/SITE_ADAPTERS.md)
- [ioFTPD Integration](docs/IOFTPD_INTEGRATION.md)
