# docker-mmonit

A container running [M/Monit](https://mmonit.com).

Image hosted at: `ghcr.io/ghcr.io/jchonig/mmonit`

## Usage

## docker

```sh
docker create \
  --name=mmonit \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Europe/London \
  -e MMONIT_LICENSE_OWNER="Fred" \
  -e MMONIT_LICENSE_KEY="<M/Monit license key>" \
  --expose 8080 \
  -v </path/to/appdata/config>:/config \
  -v </path/to/backupdir>:/backup \
  --restart unless-stopped \
  --stop-timeout 120 \
  ghcr.io/jchonig/mmonit
```

### docker-compose

Compatible with docker-compose v2 schemas.

```yaml
---
version: "2"
services:
  monit:
    image: ghcr.io/jchonig/mmonit
    container_name: mmonit
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/London
      - MMONIT_LICENSE_OWNER="Fred"
      - MMONIT_LICENSE_KEY="<M/Monit license key>"
    volumes:
      - </path/to/appdata/config>:/config
      - </path/to/backupdir>:/backup
    expose:
      - 8080
    restart: unless-stopped
    stop_grace_period: 2m
```

## Parameters

## Ports (--expose)

| Volume | Function                                         |
|--------|--------------------------------------------------|
| 8080   | Used for web access and for clients to report in |

## Environment Variables (-e)

| Env                          | Function                                  |
|------------------------------|-------------------------------------------|
| PUID=1000                    | UserID, see below                         |
| PGID=1000                    | GroupID, see below                        |
| TZ=UTC                       | Timezone to use, e.g. UTC                 |
| MMONIT_VERSION               | M/Monit version to build                  |
| MMONIT_LICENSE_OWNER         | Owner name from M/Monit license           |
| MMONIT_LICENSE_KEY           | Text of the M/Monit license               |
| MMONIT_DATABASE_BACKUP_STATS | "no" skips statistics tables in backups   |
| MMONIT_BACKUP_TIMEOUT        | Seconds before a dump fails (1800)        |
| MMONIT_DATABASE_URL          | URL to access the M/Monit database        |
| MMONIT_LIMIT_FD              | Override the default of 4096              |
| MMONIT_UPGRADE_TIMEOUT       | Seconds before an upgrade fails (3600)    |
| MMONIT_TLS_VERSION           | Override the TLS version                  |

## Volume Mappings (-v)

| Volume  | Function                                    |
|---------|---------------------------------------------|
| /config | All the config files reside here            |
| /backup | Optional location to store periodic backups |

## Application Setup

* Environment variables can also be passed in a file named `env` in
  the `config` directory. This file is sourced by the shell.
* The M/Monit configuration directories are extracted into a
  directory in /config named monit-${MONIT_VERSION} unless it
  already exists.
* It is recommended to use nginx as an SSL proxy for security.
  Since M/Monit 4.4.0 the proxy must pass HTTP 401 responses
  through unchanged (don't set `proxy_intercept_errors` in nginx or
  `ProxyErrorOverride` in Apache), and a proxy that rewrites the
  `Host` header must set `X-Forwarded-Host`:

  ```nginx
  proxy_set_header X-Forwarded-Host $http_host;
  ```

  M/Monit 4.4.0 builds redirect URLs from the `Host` header alone, so
  a proxy that rewrites `Host` (for example to `localhost`) must also
  rewrite `Location` headers back to the browser's address.  4.3.4
  includes the port (`http://localhost:8080/...`) and 4.4.0 leaves it
  out (`http://localhost/...`).  With Caddy:

  ```caddyfile
  header_down Location ^https?://localhost(?::8080)?(/.*)?$ https://{host}$1
  ```

* M/Monit can take a while to save statistics and pending alerts
  when it stops, so give the container two minutes to stop
  (`--stop-timeout 120` or `stop_grace_period: 2m`) instead of
  Docker's default of 10 seconds.

## Backups

If the /backup volume is mounted, periodic (hourly, daily, weekly and
monthly) backups will be created with a retention of (25 hours, 8
days, 5 weeks, and 12 months respectively). The onwership will be the
container PUID and PGID.

Logs will be stored in /config/logs/backup.log and rotated monthly.

This has been tested with sqlite3 and mariadb.  Backups of postgresql
are not yet supported.

Also see `MMONIT_DATABASE_BACKUP_STATS` when using mariadb.  On a
slower system, dumping all the statistics can cause M/Monit to drop
data and cause problems.

Backups can be run by hand by running `/usr/local/bin/mmonit_backup`.
Specify a type with `--type FOO` to separate them from periodic
backups.

## Upgrading

* The container will automatically run the M/Monit upgrade script if
  */config/version* indicates an older version was last run.
* Old versions /config/mmonit-${MMONIT_VERSION} will need to be
  manually removed at this time.
* If an upgrade fails, /config/.upgrade_failed will have contain the
  reason for the failure and M/Monit will not start until the issue
  is fixed and the file is removed.
* The upgrade fails if it takes longer than `MMONIT_UPGRADE_TIMEOUT`
  seconds.  The 4.4.0 upgrade converts MySQL/MariaDB databases to
  utf8mb4, which can take a long time on a large database and needs
  free space in the database server's temporary directory
  (`innodb_tmpdir`, or `tmpdir` if that is unset).
* If backups are configured, a full backup of the database will be
  done before the upgrade starts.  If the upgrade fails, the
  database will be restored from the backup.

## More information

See the [Wiki](https://github.com/jchonig/docker-mmonit/wiki).
