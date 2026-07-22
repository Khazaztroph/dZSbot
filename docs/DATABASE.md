# Database

dZSbot 2.0 can run without MySQL. Local storage remains the default so a fresh
bot can start without external services.

MySQL can be enabled for modules that support it. When a MySQL-backed module
loads, it connects and creates its required tables with `CREATE TABLE IF NOT
EXISTS`.

## MySQL Config

Configure in `config/dzsbot.conf`:

```tcl
::dZSbot::Config::Set database.mysql.enabled 1
::dZSbot::Config::Set database.mysql.host "127.0.0.1"
::dZSbot::Config::Set database.mysql.port 3306
::dZSbot::Config::Set database.mysql.user "dzsbot"
::dZSbot::Config::Set database.mysql.password "secret"
::dZSbot::Config::Set database.mysql.database "dzsbot"
```

dZSbot loads local Tcl packages from `lib/` before the system Tcl paths. The
bundled MySQL path is `tdbc::mysql`, with automatic fallback to global
`mysqltcl` if it exists. MySQL 8.4 is the current LTS line and MySQL 9.x is the
innovation/current line, so avoid depending on legacy authentication behaviour
from old MySQL 5.x era clients.

For Tcl 9.0.2 builds, use TDBC/MySQL packages built for Tcl 9. A clean Cygwin
install normally places them under:

```text
/opt/tcl-9.0.2/lib/tdbc1.1.11
/opt/tcl-9.0.2/lib/tdbcmysql1.1.11
```

The Tcl 9 package DLLs use names like `cygtcl9tdbc1.1.11.dll` and
`cygtcl9tdbcmysql1.1.11.dll`. If `package require tdbc` reports `Permission
denied`, `Exec format error`, or a missing `cygtcl9...dll`, verify that Windows
ASR/Defender is not blocking Cygwin, Eggdrop, `/opt`, or the dZSbot directory.
Also make sure no old `/usr/local/lib/tdbc*` package index is being loaded before
the matching `/opt/tcl-9.0.2/lib` path.

When Eggdrop runs from its own root directory, Cygwin runtime dependencies may
also need to be visible from that root. For Tcl 9.0.2 with `tdbc::mysql`, the
working setup uses these MySQL client DLLs in the Eggdrop root:

```text
cygmysql-15.dll
libmysql.dll.15
```

This mirrors how TLS DLLs often need to be available to Eggdrop itself, not only
inside the Tcl package directory.

## MySQL TLS

TLS is optional by default and can be required:

```tcl
::dZSbot::Config::Set database.mysql.ssl.required 1
::dZSbot::Config::Set database.mysql.ssl.ca "/path/to/ca.pem"
::dZSbot::Config::Set database.mysql.ssl.cert "/path/to/client-cert.pem"
::dZSbot::Config::Set database.mysql.ssl.key "/path/to/client-key.pem"
```

Optional settings:

```tcl
::dZSbot::Config::Set database.mysql.ssl.capath "/path/to/ca-directory"
::dZSbot::Config::Set database.mysql.ssl.cipher "TLS_AES_256_GCM_SHA384"
::dZSbot::Config::Set database.mysql.extra_options {}
```

`database.mysql.extra_options` is appended to the active MySQL driver call. Use
it only for options supported by the installed `tdbc::mysql` or `mysqltcl`
driver.

When `database.mysql.ssl.required` is `1`, dZSbot connects, checks the MySQL
`Ssl_cipher`/`Ssl_version` status values, and rejects the connection if TLS is
not active.

For stronger enforcement, also configure the MySQL server to require secure
transport, for example with `require_secure_transport=ON`.

## PRE With MySQL

```tcl
::dZSbot::Config::Set pre.backend "mysql"
::dZSbot::Config::Set pre.mysql.table "predb"
```

These PRE settings live in `config/modules/pre.conf`.

When PRE loads, it ensures this table exists:

```text
predb
```

Fields:

```text
id section relname u_name g_name nukereason pretime predate preage size files
```

If MySQL is disabled, unavailable, or cannot connect, PRE falls back to the TSV
store so commands can still work.
