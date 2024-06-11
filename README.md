# docker-mmonit
A container running [M/Monit](https://mmonit.com).

# Usage

## docker

```
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
  jchonig/mmonit
```

### docker-compose

Compatible with docker-compose v2 schemas.

```
---
version: "2"
services:
  monit:
    image: jchonig/mmonit
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
```

# Parameters

## Ports (--expose)

| Volume | Function                                         |
|--------|--------------------------------------------------|
| 8080   | Used for web access and for clients to report in |

## Environment Variables (-e)

| Env                          | Function                                                            |
|------------------------------|---------------------------------------------------------------------|
| PUID=1000                    | for UserID - see below for explanation                              |
| PGID=1000                    | for GroupID - see below for explanation                             |
| TZ=UTC                       | Specify a timezone to use EG UTC                                    |
| MMONIT_VERSION               | The version of M\/Monit to build                                    |
| MMONIT_LICENSE_OWNER         | Owner name from M\/Monit license                                    |
| MMONIT_LICENSE_KEY           | Text of the M/Monit license                                         |
| MMONIT_DATABASE_BACKUP_STATS | "yes" or "no" to backup statistics tables (which can be very large) |
| MMONIT_DATABASE_URL          | URL to access the M\/Monit database                                 |
| MMONIT_LIMIT_FD              | Override the default of 4096                                        |
| MMONIT_TLS_VERSION           | Override the TLS version                                            |

## Volume Mappings (-v)

| Volume  | Function                                    |
|---------|---------------------------------------------|
| /config | All the config files reside here            |
| /backup | Optional location to store periodic backups |

# Application Setup

  * Environment variables can also be passed in a file named `env` in
    the `config` directory. This file is sourced by the shell.
  * The M/Monit configuration directories are extracted into a
    directory in /config named monit-${MONIT_VERSION} unless it
    already exists. 
  * It is recommended to use nginx as an SSL proxy for security.

# Backups

If the /backup volume is mounted, periodic (hourly, daily, weekly and
monthly) backups will be created with a retention of (25 hours, 8
days, 5 weeks, and 12 months respectively). The onwership will be the
container PUID and PGID.

Logs will be stored in /config/logs/backup.log and rotated monthly.

This has been tested with sqlite3 and mariadb.

Also see `MMONIT_DATABASE_BACKUP_STATS` when using mariadb.

# Upgrading

  * The container will automatically run the M/Monit upgrade script if
    */config/version* indicates an older version was last run.
  * Old versions /config/mmonit-${MMONIT_VERSION} will need to be
    manually removed at this time.

# More information

See the [Wiki](https://github.com/jchonig/docker-mmonit/wiki).
