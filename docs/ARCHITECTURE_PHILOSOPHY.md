# dZSbot Architecture Philosophy

The goal of dZSbot is not to become another collection of Tcl scripts.
The goal is to build a platform where every component has a single
responsibility.

## Core

The Core is responsible for everything that is shared.

Examples:

- Configuration loading
- Logging
- Database access
- Module loading
- Event dispatching
- Transport
- Metrics
- Health checks
- Version handling

Modules must never duplicate these services.

## Modules

A module should contain only business logic.

A module should never:

- create its own logger
- read configuration files directly
- open database connections
- create runtime directories
- implement its own reload logic

Instead it requests these services from the Core.

A module should be small and easy to understand.

## Configuration

There is exactly one configuration location:

```text
config/
```

Global configuration belongs there. Each module may have one configuration file
under:

```text
config/modules/
```

No configuration files should exist inside module directories.

## Runtime

Everything created while dZSbot is running belongs under:

```text
runtime/
```

Examples:

- cache
- pid files
- sockets
- temporary files

Runtime data should never mix with source code.

## Logs

All logging is centralized under:

```text
logs/
```

The Core logger controls logging. Modules never create their own logging
systems.

## Themes

Themes are global.

Modules never contain their own themes. The Theme Manager decides how
announcements are rendered.

## Database

Database access is handled exclusively by the Core.

Modules never connect directly to MySQL. The Core exposes database services
through the Module API.

## Error Handling

Core principle:

```text
Expected failures are handled. Unexpected failures are isolated.
```

A failing module must never stop the Core. A failing external service must never
crash unrelated modules.

## Reload

Reloading is a Core responsibility.

```text
.dzs reload
```

The Core reloads configuration and notifies modules. Modules should only
implement callbacks if needed.

## Folder Structure

Every directory has exactly one purpose.

```text
core/        Shared platform services
modules/     Business logic only
config/      Configuration
runtime/     Runtime generated files
logs/        Logs
database/    Database schema and migrations
docs/        Documentation
tests/       Tests
tools/       Development tools
```

Nothing should exist in a directory that does not belong there.

## Design Goal

A new developer should immediately understand where something belongs.

If someone asks:

```text
Where should this file go?
```

there should only be one correct answer.
