#!/bin/bash
set -euo pipefail

secret_or_exit() {
	local path="$1" label="$2"
	if [[ -f "$path" ]]; then
		cat "$path"
	else
		printf "Missing required secret: %s\n" "$label" >&2
		exit 1
	fi
}

DB_PASS="${DB_PASS:-$(secret_or_exit /run/secrets/db_password db_password)}"
DB_ROOT_PASS="${DB_ROOT_PASS:-$(secret_or_exit /run/secrets/db_root_password db_root_password)}"

service mariadb start

for attempt in {1..15}; do
	if mysqladmin ping --silent >/dev/null 2>&1; then
		break
	fi
	sleep 1
	if [[ $attempt -eq 15 ]]; then
		printf "MariaDB did not become ready in time.\n" >&2
		exit 1
	fi
done

db_exists=$(mysql -uroot -e "SELECT 1 FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${DB_NAME}'" 2>/dev/null | tail -n +2 || true)

if [[ -z "$db_exists" ]]; then
	printf "Initializing secure configuration and provisioning '%s'.\n" "$DB_NAME"

	printf "\ny\n%s\n%s\ny\ny\ny\ny\n" "$DB_ROOT_PASS" "$DB_ROOT_PASS" | mysql_secure_installation

	mysql -uroot -p"${DB_ROOT_PASS}" <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
SQL
else
	printf "Schema '%s' already present; skipping creation.\n" "$DB_NAME"
fi

service mariadb stop

exec "$@"