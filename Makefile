TAG=devel
IMAGE=mmonit
VERSION=$(shell cat VERSION | sed -e 's/-.*//')
# M/Monit only ships x64 binaries for Alpine
PLATFORM=--platform linux/amd64
VOLUMES= \
    -v ${PWD}/config:/config
ENV=
PORTS=-p 8080:8080

all: build

build:
	docker build ${PLATFORM} -t ${IMAGE}:${TAG} --build-arg mmonit_version=${VERSION} .

test: build
	docker run ${PLATFORM} ${VOLUMES} ${ENV} ${PORTS} ${IMAGE}:${TAG}

# Test backups and restores against each database type
DATABASES=sqlite3 mysql postgresql

test-backups: build
	for db in $(DATABASES); do tests/backup-test.sh $$db $(IMAGE):$(TAG) || exit 1; done

test-backup-%: build
	tests/backup-test.sh $* $(IMAGE):$(TAG)

# Run the container with just a bash shell
run-bash: build
	docker run ${PLATFORM} ${VOLUMES} ${ENV} ${PORTS} -it --entrypoint /bin/bash ${IMAGE}:${TAG}

# Start the container and run a bash shell
exec-bash: build
	docker run ${PLATFORM} ${VOLUMES} ${ENV} ${PORTS} -it ${IMAGE}:${TAG} /bin/bash

