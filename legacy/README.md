# Legacy Bundle

This directory contains legacy ioFTPD tools bundled with dZSbot:

```text
init.itcl
nxLib.tcl
ioNiNJA/
nxTools/
```

The goal is a complete install package for new users while keeping dZSbot Core
modern and independent.

## What Is Included

- ioNiNJA Tcl scripts and plugins.
- nxTools Tcl scripts and text templates.
- `init.itcl` and `nxLib.tcl`, required in the ioFTPD scripts root for the
  legacy stack to load.
- Tcl 9/ioFTPD 8.1 compatibility updates already used by the dZSbot setup.
- Clean example configs.

## What Is Not Included

- Live nxTools SQLite databases.
- Local backup folders.
- API keys, passwords, tokens or site-specific private paths.

## Install Paths

Copy these folders to:

```text
legacy/init.itcl -> C:/ioFTPD/scripts/init.itcl
legacy/nxLib.tcl -> C:/ioFTPD/scripts/nxLib.tcl
legacy/ioNiNJA -> C:/ioFTPD/scripts/ioNiNJA
legacy/nxTools -> C:/ioFTPD/scripts/nxTools
```

Then edit:

```text
C:/ioFTPD/scripts/ioNiNJA/ioNiNJA.cfg
C:/ioFTPD/scripts/nxTools/nxTools.cfg
C:/ioFTPD/scripts/nxTools/nxPre.cfg
```

See the root `INSTALL.md` and `docs/LEGACY_BUNDLE.md`.
