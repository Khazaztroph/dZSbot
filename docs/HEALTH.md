# Health

The health service tracks component state and writes a heartbeat file for
external tools.

## Set Component State

```tcl
::dZSbot::Health::Set core ok "initialized"
::dZSbot::Health::Set module:imdb error "API timeout"
```

Known states are free-form, but the summary treats `error`, `critical`, and
`failed` as unhealthy, and `warn` as degraded.

## Heartbeat

Boot writes:

```text
runtime/heartbeat.json
```

The heartbeat contains overall state, component states, messages, and update
timestamps.
