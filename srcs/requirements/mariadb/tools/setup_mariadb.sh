#!/bin/bash
set -e

if [ -f "/run/secrets/db_password" ]; then
    DB_PASS=$(cat /run/secrets/db_password)
fi

if [ -f "/run/secrets/db_root_password" ]; then
    DB_ROOT_PASS=$(cat /run/secrets/db_root_password)
fi

service mariadb start

# Wait for MariaDB to become responsive (timeout after ~30s)
wait_for_mariadb() {
    local tries=0
    local max=30
    while true; do
        if [ -z "${DB_ROOT_PASS:-}" ]; then
            mysqladmin ping >/dev/null 2>&1 && return 0 || true
        else
            mysqladmin ping -u root -p"${DB_ROOT_PASS}" >/dev/null 2>&1 && return 0 || true
        fi
        tries=$((tries + 1))
        if [ "$tries" -ge "$max" ]; then
            echo "Timed out waiting for MariaDB to start"
            return 1
        fi
        sleep 1
    done
}

wait_for_mariadb

if ! mysql -u root -e "SHOW DATABASES;" | grep -q "$DB_NAME"; then
    echo "Database '$DB_NAME' not found. Creating and configuring..."

    # Run mysql_secure_installation with provided root password
    mysql_secure_installation <<EOF

y
${DB_ROOT_PASS}
${DB_ROOT_PASS}
y
y
y
y
EOF

    # Create the database and user with credentials from .env
    mysql -u root -p"${DB_ROOT_PASS}" -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;"
    mysql -u root -p"${DB_ROOT_PASS}" -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';"
    mysql -u root -p"${DB_ROOT_PASS}" -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';"
    mysql -u root -p"${DB_ROOT_PASS}" -e "FLUSH PRIVILEGES;"

    echo "Database and user created successfully."
else
    echo "Database '$DB_NAME' already exists. Skipping setup."
fi

service mariadb stop

exec "$@"