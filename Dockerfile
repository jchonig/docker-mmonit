FROM lsiobase/alpine:3.19

ARG mmonit_version
ARG mmonit_os=alpine
ARG mmonit_architecture=x64
ARG mmonit_url=https://mmonit.com/dist/mmonit-${mmonit_version}-${mmonit_os}-${mmonit_architecture}.tar.gz

ENV \
        MMONIT_VERSION=$mmonit_version \
        MMONIT_OS=$mmonit_os \
        MMONIT_DATABASE_URL= \
        MMONIT_LICENSE_OWNER= \
        MMONIT_LICENSE_KEY= \
        MMONIT_LIMIT_FD=4096 \
        MMONIT_TLS_VERSION= \
        TZ=UTC

WORKDIR /opt

# Set up
RUN \
        echo "*** install utilities needed ****" && \
        apk add --no-cache dpkg logrotate rsync xmlstarlet trurl && \
        echo "*** install M/Monit ***" && \
        curl -o - "${mmonit_url}" | tar -xzf -

# Add configuration files
COPY root /

EXPOSE 8080

VOLUME /config
