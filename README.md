# docker-mmonit
A container running [M/Mmonit](https://mmonit.com).

# Usage

## docker

```
docker create \
  --name=monit \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Europe/London \
  -e MMONIT_LICENSE_OWNER="Fred" \
  -e MMONIT_LICENSE="MMONIT_LICENSE" \
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
	  - MMONIT_LICENSE="MMONIT_LICENSE"
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

XXX - Security

## Environment Variables (-e)

| Env                  | Function                                |
| ---                  | --------                                |
| PUID=1000            | for UserID - see below for explanation  |
| PGID=1000            | for GroupID - see below for explanation |
| TZ=UTC               | Specify a timezone to use EG UTC        |
| MMONIT_VERSION       | The version of M\/Monit to build        |
| MMONIT_LICENSE_OWNER | Owner name from M\/Monit license        |
| MMONIT_LICENSE       |                                         |
| MMONIT_DATABSE_URL   | URL to access the M/\\/Monit databse    |
| MMONIT_LIMIT_FD      | Override the default of 4096            |

## Volume Mappings (-v)

| Volume  | Function                         |
| ------  | --------                         |
| /config | All the config files reside here |

# Application Setup

  * Environment variables can also be passed in a file named `env` in
    the `config` directory. This file is sourced by the shell.
  * Monit configuration is assembled from config files found in
    `config/monit.d`.
XXX  * If it does not exist, `config/monit.d/http` is used created to
    specify the port Monit listens on.

## TODO

  * [ ] Document configuration
  * [ ] Document security
  



