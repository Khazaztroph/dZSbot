# MySQL / TSV Storage

dZSbot can run without MySQL. TSV storage is the default for clean installs, and
MySQL can be enabled for sites that want central storage.

## TSV Default

TSV is local file storage. It is simple, fast and works without external
services.

Common TSV files:

```text
database/pre.tsv
database/requests.tsv
```

Runtime test files under `runtime/` are not release data and should not be
committed or copied as production storage.

## MySQL Enable

Main MySQL connection settings live in:

```text
config/dzsbot.conf
```

```tcl
::dZSbot::Config::Set database.mysql.enabled 1
::dZSbot::Config::Set database.mysql.host "127.0.0.1"
::dZSbot::Config::Set database.mysql.port 3306
::dZSbot::Config::Set database.mysql.user "dzsbot"
::dZSbot::Config::Set database.mysql.password "secret"
::dZSbot::Config::Set database.mysql.database "dzsbot"
```

PRE MySQL settings live in:

```text
config/modules/pre.conf
```

```tcl
::dZSbot::Config::Set pre.backend "mysql"
::dZSbot::Config::Set pre.mysql.table "predb"
::dZSbot::Config::Set pre.mysql.fallback_to_tsv 1
```

## Tables

When a MySQL-backed module loads, dZSbot creates required tables if they do not
exist.

PRE uses:

```text
predb
```

Core fields:

```text
id section relname u_name g_name nukereason pretime predate preage size files
```

## MySQL TLS

Require encrypted MySQL transport:

```tcl
::dZSbot::Config::Set database.mysql.ssl.required 1
::dZSbot::Config::Set database.mysql.ssl.ca "/path/to/ca.pem"
::dZSbot::Config::Set database.mysql.ssl.cert "/path/to/client-cert.pem"
::dZSbot::Config::Set database.mysql.ssl.key "/path/to/client-key.pem"
```

dZSbot checks the MySQL SSL status after connecting when TLS is required.

## Tcl 9 / Cygwin Notes

For Tcl 9.0.2, make sure the TDBC/MySQL packages match Tcl 9. If Eggdrop loads
packages from `/opt/tcl-9.0.2`, the MySQL client DLLs may also need to be in the
Eggdrop root:

```text
cygmysql-15.dll
libmysql.dll.15
```

If `tdbc::mysql` reports `Exec format error`, `Permission denied`, or a missing
DLL, verify that the package was compiled for the same Tcl runtime and that
Windows Defender/ASR is not blocking Cygwin or Eggdrop.

More detail is available in [Database Reference](DATABASE.md).
