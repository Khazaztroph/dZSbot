# Legacy Bundle

dZSbot releases include ioNiNJA and nxTools under `legacy/` so a GitHub
download can be used as a complete sitebot bundle.

```text
dZSbot Core
modules/
core/
config/
legacy/
  init.itcl
  nxLib.tcl
  ioNiNJA/
  nxTools/
```

## Why They Are Bundled

ioNiNJA and nxTools still provide important ioFTPD-side behavior, especially
upload checks, PRE, dupe, request, nuke, newdate and legacy site events.
`init.itcl` and `nxLib.tcl` are included because they are loaded from the
ioFTPD scripts root and are required for the legacy stack to start.

dZSbot reads those events through modern adapters and modules, but bundling the
legacy tools makes new installs easier and keeps known-compatible files in one
place.

## Clean Release Rules

The bundled `legacy/` copy should not contain:

- `nxTools/data/*.db`
- local backup folders
- real API keys
- passwords or tokens
- private site paths or group lists

The bundled configs use example paths such as:

```text
C:/ioFTPD/FTP-ROOT-DIR/MOVIES/
```

Users should edit these for their own site.

## Install

Copy:

```text
legacy/init.itcl -> C:/ioFTPD/scripts/init.itcl
legacy/nxLib.tcl -> C:/ioFTPD/scripts/nxLib.tcl
legacy/ioNiNJA -> C:/ioFTPD/scripts/ioNiNJA
legacy/nxTools -> C:/ioFTPD/scripts/nxTools
```

Copy dZSbot itself to:

```text
C:/ioFTPD/eggdrop/scripts/dZSbot
```

Then configure:

```text
config/dzsbot.conf
config/modules/*.conf
C:/ioFTPD/scripts/init.itcl
C:/ioFTPD/scripts/ioNiNJA/ioNiNJA.cfg
C:/ioFTPD/scripts/nxTools/nxTools.cfg
C:/ioFTPD/scripts/nxTools/nxPre.cfg
```

## Upgrade

When upgrading, merge config changes instead of overwriting live config files.
The bundled legacy configs are examples, not replacements for a tuned site.
