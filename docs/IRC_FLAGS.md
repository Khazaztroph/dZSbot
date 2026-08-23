# Auto IRC Flags

The `ircflags` module can give IRC modes to users when they join a channel,
similar in spirit to the old `AutoIRCFlag.tcl`.

It uses Eggdrop handle flags, not the old pzs-ng NickDb rights system.

Config:

```tcl
::dZSbot::Config::Set ircflags.enabled 0
::dZSbot::Config::Set ircflags.channels {#pre #spam #monstra #staff}

::dZSbot::Config::Set ircflags.rules {
    {o {n m o} {#staff}}
    {v {v} {#pre #spam #monstra}}
}
```

Rule format:

```text
{mode {eggdrop_flags} {optional channels}}
```

Examples:

- `{o {n m o} {#staff}}` gives `+o` to owners/masters/ops in `#staff`.
- `{v {v} {#pre #spam}}` gives `+v` to users with Eggdrop `+v`.

The bot must be opped in the channel to set modes.
