# Upgrade Guide

Use this guide when updating an existing dZSbot install.

## Do Not Overwrite Config Blindly

Do not replace your existing config files without comparing them first. Your
local API keys, passwords, channel names, site paths and MySQL settings live in
config files.

Recommended flow:

1. Stop or pause Eggdrop if you want a quiet upgrade.
2. Backup your current dZSbot directory.
3. Extract the new release to a temporary folder.
4. Compare `config/` from the new release with your existing `config/`.
5. Merge new settings into your existing config files.
6. Copy updated module/core files.
7. Start or reload dZSbot.
8. Run `!dzb status` in the staff channel.

## Files To Compare First

Always check:

```text
config/dzsbot.conf
config/modules/*.conf
config/adapters/*.conf
config/themes/*.conf
```

Recent releases added important settings in:

```text
config/modules/legacy.conf
config/modules/upload.conf
config/modules/pre.conf
config/themes/default.conf
```

## New Config Files

If a release adds a new config file, copy it into your live config directory and
then edit it.

Example:

```text
config/modules/legacy.conf
```

This file controls nxTools/ioNiNJA-style announces such as `NEWDATE`, `NUKE`,
`UNNUKE`, `APPROVE`, `REQFILL` and `REQDEL`.

## After Upgrade

Check startup output:

```text
dZSbot loaded and ready.
```

Check IRC:

```text
!dzb status
!bw
!df
!pres
```

If an announce is too noisy, disable only that event instead of disabling the
whole module. For example:

```tcl
::dZSbot::Config::Set legacy.announce.event.newdate.enabled 0
::dZSbot::Config::Set upload.announce.event.racer.enabled 0
```
