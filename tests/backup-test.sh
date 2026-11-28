#!/bin/sh
#
# Test backups and restores of the M/Monit image against one database
# type: sqlite3, mysql (MariaDB) or postgresql.
#
# Usage: tests/backup-test.sh DATABASE [IMAGE]
#
# M/Monit itself is not started: without a license it fetches a trial
# license from mmonit.com, which is throttled.  The test image is the
# image under test with the mmonit service removed, so the init
# scripts that configure backups still run.

set -u

db_type="${1:?Usage: ${0} sqlite3|mysql|postgresql [IMAGE]}"
image="${2:-mmonit:devel}"
platform="--platform linux/amd64"
mariadb_image="${MARIADB_IMAGE:-mariadb:11.8}"
postgres_image="${POSTGRES_IMAGE:-postgres:18}"

name="mmonit-test-${db_type}-$$"
test_image="mmonit-test:$$"
mm="${name}-mmonit"
db="${name}-db"
failures=0

cleanup () {
    docker rm -f "${mm}" "${db}" > /dev/null 2>&1
    docker network rm "${name}" > /dev/null 2>&1
    docker rmi "${test_image}" > /dev/null 2>&1
}
trap cleanup 0
trap 'exit 1' HUP INT QUIT PIPE TERM

pass () {
    echo "PASS: ${*}"
}

fail () {
    echo "FAIL: ${*}"
    failures=$((failures + 1))
}

die () {
    echo "ERROR: ${*}" >&2
    exit 1
}

check () {
    description="${1}"
    shift
    if "$@"; then
	pass "${description}"
    else
	fail "${description}"
    fi
}

equal () {
    test "${1}" = "${2}" || { echo "    expected '${2}', got '${1}'"; return 1; }
}

# Wait until COMMAND succeeds, for up to SECONDS
wait_for () {
    seconds="${1}"
    shift
    i=0
    until "$@" > /dev/null 2>&1; do
	i=$((i + 1))
	test ${i} -ge ${seconds} && return 1
	sleep 1
    done
}

case "${db_type}" in
    sqlite3|mysql|postgresql)
	;;
    *)
	die "Unknown database type: ${db_type}"
	;;
esac

mmonit_version=$(docker run --rm ${platform} --entrypoint /bin/sh "${image}" -c 'echo ${MMONIT_VERSION}') ||
    die "Unable to run ${image}"
mmonit_dir="/config/mmonit-${mmonit_version}"
schema="/opt/mmonit-${mmonit_version}/db/mmonit-schema.${db_type%3}"

docker build -q ${platform} -t "${test_image}" - > /dev/null <<EOF || die "Unable to build ${test_image}"
FROM ${image}
RUN rm /etc/s6-overlay/s6-rc.d/user/contents.d/mmonit
EOF

docker network create "${name}" > /dev/null || die "Unable to create network ${name}"

# Run SQL against the database as an administrator and print the result
sql () {
    case "${db_type}" in
	sqlite3)
	    docker exec "${mm}" sqlite3 "${mmonit_dir}/db/mmonit.db" "PRAGMA foreign_keys = OFF; ${1}"
	    ;;
	mysql)
	    docker exec "${db}" mariadb -uroot -proot -N mmonit -e "SET FOREIGN_KEY_CHECKS = 0; ${1}"
	    ;;
	postgresql)
	    docker exec "${db}" psql -q -U postgres -d mmonit -tA -v ON_ERROR_STOP=1 \
		   -c "SET session_replication_role = replica; ${1}"
	    ;;
    esac
}

count () {
    sql "SELECT COUNT(*) FROM ${1};" | tr -d '[:space:]'
}

# Start the database and load the M/Monit schema
case "${db_type}" in
    mysql)
	# A password with characters that need escaping in the URL
	password='m:o@n%it'
	url_password='m%3Ao%40n%25it'
	docker run -d --name "${db}" --network "${name}" --network-alias db \
	       -e MARIADB_ROOT_PASSWORD=root -e MARIADB_DATABASE=mmonit \
	       -e MARIADB_USER=mmonit -e MARIADB_PASSWORD="${password}" \
	       "${mariadb_image}" > /dev/null || die "Unable to start ${mariadb_image}"
	wait_for 120 docker exec "${db}" mariadb -ummonit -p"${password}" mmonit -e 'SELECT 1' ||
	    die "MariaDB did not start"
	docker run --rm ${platform} --entrypoint cat "${image}" "${schema}" |
	    docker exec -i "${db}" mariadb -ummonit -p"${password}" mmonit || die "Unable to load ${schema}"
	database_url="mysql://mmonit:${url_password}@db:3306/mmonit"
	;;
    postgresql)
	# A password with characters that need escaping in the URL and
	# in the password file
	password='m:o\n@i%t'
	url_password='m%3Ao%5Cn%40i%25t'
	docker run -d --name "${db}" --network "${name}" --network-alias db \
	       -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=mmonit \
	       "${postgres_image}" > /dev/null || die "Unable to start ${postgres_image}"
	wait_for 120 docker exec "${db}" psql -U postgres -d mmonit -c 'SELECT 1' ||
	    die "PostgreSQL did not start"
	# psql only interpolates :'password' in SQL read from input
	docker exec -i "${db}" psql -q -U postgres -d mmonit -v ON_ERROR_STOP=1 \
	       -v password="${password}" <<'EOF' || die "Unable to create the mmonit role"
CREATE ROLE mmonit LOGIN PASSWORD :'password';
ALTER DATABASE mmonit OWNER TO mmonit;
ALTER SCHEMA public OWNER TO mmonit;
EOF
	docker run --rm ${platform} --entrypoint cat "${image}" "${schema}" |
	    docker exec -i "${db}" psql -q -U mmonit -d mmonit -v ON_ERROR_STOP=1 > /dev/null ||
	    die "Unable to load ${schema}"
	database_url="postgresql://mmonit:${url_password}@db:5432/mmonit"
	;;
    sqlite3)
	database_url=
	;;
esac

docker run -d ${platform} --name "${mm}" --network "${name}" \
       -e MMONIT_DATABASE_URL="${database_url}" \
       -e MMONIT_DATABASE_BACKUP_STATS=no \
       --tmpfs /backup:mode=1777 \
       "${test_image}" > /dev/null || die "Unable to start ${test_image}"
wait_for 120 sh -c "docker logs '${mm}' 2>&1 | grep -q 'ls.io-init\] done'" ||
    { docker logs "${mm}"; die "Container init did not finish"; }

# Seed a host with one service, one statistics row and one event.  The
# rows must satisfy the foreign keys: PostgreSQL checks them when a
# dump is restored.
sql "INSERT INTO name (id, name) VALUES (900001, 'test-host'), (900002, 'test-service'),
                                        (900003, '/etc/monitrc');
     INSERT INTO host (id, status, nameid, monitid, ipaddrin, controlfilenameid)
     VALUES (900001, 0, 900001, 'test-monitid', '127.0.0.1', 900003);
     INSERT INTO service (id, nameid, hostid, type, status, statushint, monitoringstate,
                          monitoringmode, onreboot)
     VALUES (900001, 900002, 900001, 0, 0, 0, 0, 0, 0);
     INSERT INTO statistics (id, serviceid, type, datatype) VALUES (900001, 900001, 0, 0);
     INSERT INTO statistics_aggregate_1m (statisticsid, collectedsec, value_avg)
     VALUES (900001, 1, 1.0);
     INSERT INTO event (id, hostid, serviceid, collectedsec, collectedusec, service_nameid,
                        servicetype, class, event, state, action, message)
     VALUES (900001, 900001, 900001, 1, 0, 900002, 0, 0, 0, 0, 0, 'test event');
     INSERT INTO eventnotice (eventid, date, uname, notice)
     VALUES (900001, 1, 'admin', 'test notice');" > /dev/null ||
    die "Unable to seed statistics"
users=$(count users)
check "schema has users" test "${users}" -gt 0

# Print the newest backup of TYPE
latest () {
    docker exec "${mm}" sh -c "ls -t /backup/*_${1}.* 2>/dev/null | head -n 1"
}

# Print the number of rows of TABLE in backup FILE
rows_in_backup () {
    case "${db_type}" in
	sqlite3)
	    docker exec "${mm}" sqlite3 "${1}" "SELECT COUNT(*) FROM ${2};"
	    ;;
	mysql)
	    # An INSERT statement holds one or more rows separated by
	    # "),(", on one line or one row per line
	    docker exec "${mm}" awk -v start="INSERT INTO \`${2}\` VALUES" '
		index($0, start) == 1 { inserting = 1; statement = "" }
		inserting {
		    statement = statement $0
		    if ($0 ~ /\);$/) {
			n += gsub(/\),[[:space:]]*\(/, "", statement) + 1
			inserting = 0
		    }
		}
		END { print n + 0 }' "${1}"
	    ;;
	postgresql)
	    docker exec "${mm}" awk -v table="public.${2}" '
		$1 == "COPY" && $2 == table { copying = 1; next }
		copying && $0 == "\\." { copying = 0 }
		copying { n++ }
		END { print n + 0 }' "${1}"
	    ;;
    esac
}

# Periodic backups, which leave out statistics data when
# MMONIT_DATABASE_BACKUP_STATS=no.  SQLite backups copy the whole
# database file.
check "hourly backup" docker exec "${mm}" /etc/periodic/hourly/mmonit_backup
hourly=$(latest hourly)
check "hourly backup file exists" test -n "${hourly}"
check "hourly backup has users" equal "$(rows_in_backup "${hourly}" users)" "${users}"
case "${db_type}" in
    sqlite3)
	stats_rows=1
	;;
    *)
	stats_rows=0
	;;
esac
for table in event eventnotice statistics_aggregate_1m; do
    check "hourly backup has ${stats_rows} rows of ${table}" \
	  equal "$(rows_in_backup "${hourly}" "${table}")" "${stats_rows}"
done

# Upgrade backups always include statistics
check "upgrade backup" docker exec -w "${mmonit_dir}" "${mm}" /usr/local/sbin/mmonit_backup --type upgrade-test
upgrade=$(latest upgrade-test)
check "upgrade backup file exists" test -n "${upgrade}"
for table in users event eventnotice statistics_aggregate_1m; do
    expected=$(count "${table}")
    check "upgrade backup has ${expected} rows of ${table}" \
	  equal "$(rows_in_backup "${upgrade}" "${table}")" "${expected}"
done
check ".last_backup names the upgrade backup" \
      equal "$(docker exec "${mm}" cat /config/.last_backup)" "${upgrade}"

# Restore the upgrade backup over a damaged database
sql "DELETE FROM users; DELETE FROM statistics_aggregate_1m;" > /dev/null
check "users deleted" equal "$(count users)" 0
check "restore upgrade backup" \
      docker exec "${mm}" /usr/local/sbin/mmonit_restore --dir "${mmonit_dir}" "${upgrade}"
check "restore brought back users" equal "$(count users)" "${users}"
check "restore brought back statistics" equal "$(count statistics_aggregate_1m)" 1

check "backups and restores leave no temporary files" \
      equal "$(docker exec "${mm}" sh -c 'ls -A /tmp | wc -l' | tr -d ' ')" 0

# The healthcheck fails while M/Monit isn't running and leaves nothing behind
check "healthcheck fails without M/Monit" sh -c "! docker exec '${mm}' /usr/local/sbin/healthcheck 2>/dev/null"
check "healthcheck leaves no temporary files" \
      equal "$(docker exec "${mm}" sh -c 'ls -A /tmp | wc -l; test -e /cookie && echo /cookie' | tr -d ' ')" 0

if [ ${failures} -ne 0 ]; then
    echo "${db_type}: ${failures} check(s) failed"
    docker exec "${mm}" cat /config/logs/backup.log 2>/dev/null
    exit 1
fi
echo "${db_type}: all checks passed"
