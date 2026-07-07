# Core

The Core is the stable runtime foundation for dZSbot 2.0. It owns startup,
shared state, health, metrics, transport, and module loading.

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
