# Requests

The requests module keeps a small local request queue.

## Config

Configured in `config/modules/requests.conf`:

```tcl
::dZSbot::Config::Set requests.storage [file join $::dZSbot::Root database requests.tsv]
::dZSbot::Config::Set requests.list_limit 10
```

Legacy `request.storage` is still accepted as a fallback for older local configs
and tests.

## Commands

```text
!request <release/title>
!req <release/title>
!requests
!reqfill <release/title>
!reqdel <release/title>
```

Examples:

```text
!request Example.Release.2026
!requests
!reqfill Example.Release
!reqdel Example.Release
```

The module stores request state as TSV and keeps formatting separate from
storage, following the same module structure as PRE.
