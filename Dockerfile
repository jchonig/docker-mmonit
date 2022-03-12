FROM lsiobase/ubuntu:focal

ARG DEBIAN_FRONTEND=noninteractive
ARG mmonit_version
ARG mmonit_architecture=x64
ARG mmonit_url=https://mmonit.com/dist/mmonit-${mmonit_version}-linux-${mmonit_architecture}.tar.gz

ENV \
        MMONIT_VERSION=$mmonit_version \
        MMONIT_DATAABSE_URL= \
        MMONIT_LICENSE_OWNER= \
        MMONIT_LICENSE_KEY= \
        MMOUNT_DATABASE_URL= \
        MMONIT_LIMIT_FD=4096 \
        MMONIT_TLS_VERSION= \
        TZ=UTC

WORKDIR /opt

# Set up
RUN \
echo "*** install utilities needed ****" && \
	apt update && \
        apt upgrade -y && \
	apt -y install rsync xmlstarlet && \
	rm -rf /var/lib/apt/lists/* && \
	echo "*** install M/Monit ***" && \
	curl -o - ${mmonit_url} | tar -xzf -

# Add configuration files
COPY root /

EXPOSE 8080

VOLUME /config
