# dZSbot 2.0 Architecture

## Design Philosophy

dZSbot is built around a small set of architectural principles that guide every
design decision made throughout the project.

### Core Principles

> **Expected failures are handled. Unexpected failures are isolated.**

Every component must be able to fail independently without affecting the
stability of the rest of the system.

The Core is responsible for gracefully handling expected operational
failures such as missing files, unavailable databases, network timeouts,
or incomplete configuration.

Unexpected failures should be isolated to the affected module and must
never compromise the stability of the Core or other modules.

Examples:

- If Eggdrop is offline, ioFTPD must continue to operate normally.
- If an external API is unavailable, only the affected module should be impacted.
- If a module fails, the Core must continue running.
- If the Status Service is unavailable, the system should report the condition
  gracefully instead of generating runtime errors.
  
---

### Stable Core

The Core is responsible for:

- Bootstrap
- Logger
- Configuration
- Module Manager
- Health
- Metrics
- Database
- Transport

The Core provides services.

Feature modules consume those services.

---

### Modular Design

Each module has a single responsibility.

Examples:

- movies/
- tv/
- music/
- requests/
- stats/
- status/
- health/
- system/

Modules communicate with the Core instead of directly depending on each other.

---

### Domain Modules

Module names describe responsibility, not implementation details.

Content modules:

- movies: movie lookup through providers such as OMDb/TMDb.
- tv: TV lookup through providers such as TVMaze/TVDB.
- music: music lookup and release parsing for MP3, FLAC, and future formats.
- games: future game metadata.
- books: future book metadata.

Operational modules:

- pre
- requests
- stats
- status
- health
- system

Compatibility commands such as `!imdb` are aliases into the domain
modules. This keeps old dZSbot/ioNiNJA behaviour while avoiding format-specific
module names.

---

### Single Source of Truth

The Core owns the runtime state.

Status information is published once and consumed by:

- Eggdrop
- ioFTPD
- ioGUI
- Future integrations

This guarantees consistent behaviour across all components.

---

### Development Philosophy

- Finish one milestone completely before starting the next.
- Prefer maintainability over complexity.
- Document architectural decisions as the project evolves.
- Build for long-term stability rather than short-term features.
- Architecture decisions should only be changed when there is a clear technical reason to do so.
- Consistency is preferred over short-term convenience.
