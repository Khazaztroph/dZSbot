# dZSbot Bundle Install

This repository is packaged as a complete ioFTPD sitebot bundle:

```text
dZSbot/
legacy/
  init.itcl
  nxLib.tcl
  ioNiNJA/
  nxTools/
```

## Target Layout

Recommended live layout:

```text
C:/ioFTPD/eggdrop/scripts/dZSbot
C:/ioFTPD/scripts/init.itcl
C:/ioFTPD/scripts/nxLib.tcl
C:/ioFTPD/scripts/ioNiNJA
C:/ioFTPD/scripts/nxTools
```

## Install

1. Copy the dZSbot repository contents to:

```text
C:/ioFTPD/eggdrop/scripts/dZSbot
```

2. Copy the bundled legacy tools:

```text
legacy/init.itcl -> C:/ioFTPD/scripts/init.itcl
legacy/nxLib.tcl -> C:/ioFTPD/scripts/nxLib.tcl
legacy/ioNiNJA -> C:/ioFTPD/scripts/ioNiNJA
legacy/nxTools -> C:/ioFTPD/scripts/nxTools
```

3. Edit configs before starting:

```text
C:/ioFTPD/eggdrop/scripts/dZSbot/config/
C:/ioFTPD/scripts/init.itcl
C:/ioFTPD/scripts/ioNiNJA/ioNiNJA.cfg
C:/ioFTPD/scripts/nxTools/nxTools.cfg
C:/ioFTPD/scripts/nxTools/nxPre.cfg
```

4. Do not blindly overwrite existing config files during upgrades. Compare and
merge settings.

5. Start Eggdrop normally:

```text
eggdrop.exe eggdrop.conf
```

Use foreground/debug mode only when troubleshooting:

```text
eggdrop.exe -t eggdrop.conf
```

## Notes

- `legacy/nxTools/data` is intentionally empty. nxTools creates runtime
  databases there.
- `legacy/init.itcl` loads `nxTools/nxTools.cfg`, `nxLib.tcl`,
  `ioNiNJA/ioNiNJA.cfg`, the selected ioNiNJA theme and `NiNJALiB.tcl`.
- Backup folders and live databases are intentionally not included.
- API keys and passwords are intentionally blank in bundled legacy configs.
- dZSbot itself can run with TSV storage by default and MySQL when configured.
