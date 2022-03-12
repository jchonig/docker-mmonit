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
  --restart unless-stopped \
  jchonig/mmonit
```

### docker-compose

Compatible with docker-compose v2 schemas.

```
---
version: "2"
services:
  mmonit:
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
    expose:
      - 8080
    restart: unless-stopped
```

# Parameters

## Ports (--expose)

| Volume | Function                                         |
| ------ | --------                                         |
| 8080   | Used for web access and for clients to report in |

## Environment Variables (-e)

| Env                    | Function                                |
| ---                    | --------                                |
| PUID=1000              | for UserID - see below for explanation  |
| PGID=1000              | for GroupID - see below for explanation |
| TZ=UTC                 | Specify a timezone to use EG UTC        |
| MMONIT_VERSION         | The version of M\/Monit to build        |
| MMONIT_LICENSE_OWNER   | Owner name from M\/Monit license        |
| MMONIT_LICENSE_KEY     | Text of the M/Monit license             |
| MMONIT_DATABASE_URL    | URL to access the M\/Monit database     |
| MMONIT_DATABASE_MIN_CON  | Minimum number of database connections to use |
| MMONIT_DATABASE_MAX_CON  | Maximum number to database connections to use |
| MMONIT_LIMIT_FD        | Override the default of 4096            |
| MMONIT_SESSION_TIMEOUT | Override the default session timeout of 1800 (in seconds) |
| MMONIT_TLS_VERSION     | Override the TLS version                |
| MMONIT_PROXY_SCHEME    | Set HTTP scheme used by frontend reverse proxy (optional, "http" or "https") |
| MMONIT_PROXY_NAME      | Set HTTP server DNS name used by frontend reverse proxy (optional) |
| MMONIT_PROXY_PORT      | Set HTTP port used by frontend reverse proxy (optional)        |

## Volume Mappings (-v)

| Volume  | Function                         |
| ------  | --------                         |
| /config | All the config files reside here |

# Application Setup

  * Environment variables can also be passed in a file named `env` in
    the `config` directory. This file is sourced by the shell.
  * The M/Monit configuration directories are extracted into
    subdirectories of /config (conf, db, docroot, logs) unless they
    already exist.
  * It is recommended to use nginx as an SSL proxy for security.

# Upgrading

  * The container will automatically run the M/Monit upgrade script if
    */config/version* indicates an older version was last run.

# Running behind a HTTP reverse proxy

To run this docker image behind a HTTP reverse proxy like Apache or NGinx change the `expose` setting inside the
`docker-compose.yml` to `ports` to export these to be reachable by the docker host and (optionally) configure the
`MMONIT_PROXY_` env vars as needed. The desciption and some Apache/Nginx configuration examples are documented
in the M/Monit documentation available at https://mmonit.com/documentation/mmonit_manual.pdf - Chapter 
"M/Monit behind a proxy".

```
---
version: "2"
services:
  mmonit:
    image: jchonig/mmonit
    container_name: mmonit
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/London
      - MMONIT_LICENSE_OWNER="Fred"
      - MMONIT_LICENSE_KEY="<M/Monit license key>"
      - MMONIT_PROXY_SCHEME=https
    volumes:
      - </path/to/appdata/config>:/config
    ports:
      - 8080:8080
    restart: unless-stopped
```

## TODO
  * Facilitate setup of a database other than sqlite3.



