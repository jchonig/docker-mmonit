# docker-mmonit

A container running [M/Monit](https://mmonit.com).

Image hosted at: `ghcr.io/jchonig/mmonit`

The `backup-*` tags are no longer published, and `backup-4.4.0` has
been removed. Backups are now in the main image, so use the version
tags (for example `4.4.0`) or `latest`.

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
| MMONIT_DATABASE_BACKUP_STATS | "no" leaves statistics out, see Backups   |
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
monthly) backups will be created with a retention of (24 hours, 8
days, 5 weeks, and 12 months respectively). The ownership will be the
container PUID and PGID.

When /backup is mounted, the container installs the database client
(`mariadb-client`, `postgresql18-client` or `sqlite`) with `apk` each
time it starts, so it needs access to the Alpine package repositories
at startup.

Logs will be stored in /config/logs/backup.log and rotated monthly.

Backups work with each database M/Monit supports, chosen by the
scheme of `MMONIT_DATABASE_URL`:

| Database   | Backup file | Made with                         |
|------------|-------------|-----------------------------------|
| SQLite     | `*.sq3`     | `sqlite3 .backup`                 |
| MySQL      | `*.sql`     | `mariadb-dump`                    |
| PostgreSQL | `*.pgsql`   | `pg_dump --clean`, plain SQL      |

The PostgreSQL client is version 18, which can dump servers back to
PostgreSQL 9.2.

Also see `MMONIT_DATABASE_BACKUP_STATS` when using MySQL or
PostgreSQL.  On a slower system, dumping all the statistics can
cause M/Monit to drop data and cause problems.  When it is `no`,
periodic backups keep the statistics and event tables' definitions
but not their rows; the backup taken before an upgrade always
includes everything.  SQLite backups always copy the whole database.

Backups can be run by hand by running `/usr/local/sbin/mmonit_backup`.
Specify a type with `--type FOO` to separate them from periodic
backups.  For SQLite, run it from the M/Monit directory
(`/config/mmonit-${MMONIT_VERSION}`).

Stop M/Monit before restoring a backup with
`/usr/local/sbin/mmonit_restore FILE`.  For SQLite, `--dir DIR`
names the M/Monit directory to restore into; it defaults to
`/config/mmonit-${MMONIT_VERSION}`.

## Testing

`make test-backups` builds the image and tests backups and restores
against SQLite, MariaDB and PostgreSQL in containers;
`make test-backup-sqlite3`, `make test-backup-mysql` and
`make test-backup-postgresql` test one.  M/Monit itself is not
started, so the tests don't need a license.  CI runs them for every
push and pull request.

## Updates and security

* [Renovate](https://docs.renovatebot.com) opens pull requests for
  new base images (the lsiobase image is pinned by digest, so each
  rebuild of it is a pull request) and GitHub Actions versions.
* New M/Monit releases appear on Renovate's Dependency Dashboard issue
  instead of as pull requests, because they need upgrade testing.
  Tick the release there to have Renovate open the pull request that
  updates `VERSION`.
* The weekly scheduled build only builds and pushes when the published
  image has Alpine package updates; the image runs `apk upgrade` when
  it is built.  Run the Build and Push workflow by hand with `force`
  to push anyway.
* A daily scan runs [Trivy](https://trivy.dev) on the published image,
  with the database clients that are installed at startup added, and
  reports fixable HIGH and CRITICAL vulnerabilities in the repository's
  Security tab.  The scan fails while any are found; a rebuild fixes
  them.

## Upgrading

* The container will automatically run the M/Monit upgrade script if
  */config/version* indicates an older version was last run.
* Old versions /config/mmonit-${MMONIT_VERSION} will need to be
  manually removed at this time.
* If an upgrade fails, /config/.upgrade_failed will contain the
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
