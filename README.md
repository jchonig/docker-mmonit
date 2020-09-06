# docker-mmonit
A container running [M/Monit](https://mmonit.com).

# Usage

## docker

```
docker create \
  --name=monit \
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
  monit:
    image: jchonig/monit
    container_name: monit
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

| Env                  | Function                                |
| ---                  | --------                                |
| PUID=1000            | for UserID - see below for explanation  |
| PGID=1000            | for GroupID - see below for explanation |
| TZ=UTC               | Specify a timezone to use EG UTC        |
| MMONIT_VERSION       | The version of M\/Monit to build        |
| MMONIT_LICENSE_OWNER | Owner name from M\/Monit license        |
| MMONIT_LICENSE_KEY   | Text of the M/Monit license             |
| MMONIT_DATABSE_URL   | URL to access the M\/Monit databse      |
| MMONIT_LIMIT_FD      | Override the default of 4096            |

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

## TODO
  * Facilitate setup of a dataabase other than sqlite3.



