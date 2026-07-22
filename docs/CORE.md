# Core

The Core is the stable runtime foundation for dZSbot 2.0. It owns startup,
shared state, health, metrics, transport, and module loading.

## Tcl Runtime

dZSbot supports Tcl 8.6+ and is prepared for Tcl 9.0.2 on modern Cygwin/Eggdrop
builds. Tcl 8.6 remains the minimum runtime so existing Eggdrop setups can keep
running, but Tcl 9.0.2 is supported when Eggdrop and the required extension
packages are built against the same Tcl runtime.

At startup, `dZSbot.tcl` adds the local `lib/` directory first and then prefers
these Tcl 9.0.2 package paths when they exist:

```text
/opt/tcl-9.0.2/lib
/opt/tcl9.0.2/lib
```

The Tcl 8.6.18 paths remain available as fallback. Avoid mixing Tcl 8 extension
DLLs with Tcl 9, especially for `tdbc`, `tdbc::mysql`, `sqlite3`, and `tls`.

## Starting Eggdrop

dZSbot does not require Eggdrop's `-t` flag during normal operation. Use `-t`
when troubleshooting startup, Tcl packages, MySQL, TLS, or module loading.

Common start modes:

```text
eggdrop.exe eggdrop.conf       normal background operation
eggdrop.exe -t eggdrop.conf    foreground test/debug mode
eggdrop.exe -m eggdrop.conf    create the userfile/first owner account
```

Use `-m` only when creating a fresh Eggdrop userfile. Once the userfile exists,
normal operation should use `eggdrop.exe eggdrop.conf`.

## Boot Order

`dZSbot.tcl` loads the core files in this order:

1. `version.tcl`
2. `logger.tcl`
3. `packages.tcl`
4. `config.tcl`
5. `metrics.tcl`
6. `health.tcl`
7. `database.tcl`
8. `theme.tcl`
9. `commands.tcl`
10. `transport.tcl`
11. `modulemanager.tcl`
12. `bootstrap.tcl`

`::dZSbot::Bootstrap::Start` initializes the core, loads config, initializes
database/theme services, discovers modules, publishes `core.ready`, writes
`runtime/heartbeat.json`, and reports that the bot is ready.

Before a module is sourced, `::dZSbot::ModuleManager` loads
`config/modules/<module>.conf` when that file exists.

## Core Services

- `::dZSbot::Logger` writes Eggdrop logs with a tclsh fallback.
- `::dZSbot::Config` stores runtime configuration values.
- `::dZSbot::Database` initializes runtime database paths.
- `::dZSbot::Theme` stores active theme state.
- `::dZSbot::Commands` registers Eggdrop-compatible commands.
- `::dZSbot::Packages` validates Tcl/package dependencies.
- `::dZSbot::Metrics` stores counters and simple values.
- `::dZSbot::Health` tracks component/module status and heartbeat output.
- `::dZSbot::Transport` provides an internal event bus.
- `::dZSbot::ModuleManager` discovers, loads, and registers modules.

## Failure Model

Expected operational failures are logged and reflected in health state.
Unexpected module failures are caught by the module manager or transport layer
so the core can keep running.
