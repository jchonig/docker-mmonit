FROM lsiobase/alpine:3.24

ARG mmonit_version
ARG mmonit_os=alpine
ARG mmonit_architecture=x64
ARG mmonit_url=https://mmonit.com/dist/mmonit-${mmonit_version}-${mmonit_os}-${mmonit_architecture}.tar.gz

ENV \
        MMONIT_VERSION=$mmonit_version \
        MMONIT_OS=$mmonit_os \
        MMONIT_DATABASE_URL= \
        MMONIT_DATABASE_BACKUP_STATS=yes \
        MMONIT_BACKUP_TIMEOUT=1800 \
        MMONIT_LICENSE_OWNER= \
        MMONIT_LICENSE_KEY= \
        MMONIT_LIMIT_FD=4096 \
        MMONIT_UPGRADE_TIMEOUT=3600 \
        MMONIT_TLS_VERSION= \
        S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
        TZ=UTC

WORKDIR /opt

# Add configuration files
COPY root /

# Set up
RUN \
	echo "*** fix directory modes copied from the build context ***" && \
	chmod go+rx /etc /etc/logrotate.d /etc/periodic /etc/s6-overlay && \
	echo "*** upgrade base packages ***" && \
        apk upgrade --no-cache && \
	echo "*** install utilities needed ****" && \
        apk add --no-cache dpkg logrotate rsync trurl xmlstarlet && \
	echo "*** install M/Monit ***" && \
	curl -o - "${mmonit_url}" | tar -xzf -

HEALTHCHECK --start-period=300s CMD /usr/local/sbin/healthcheck

EXPOSE 8080

VOLUME /config
