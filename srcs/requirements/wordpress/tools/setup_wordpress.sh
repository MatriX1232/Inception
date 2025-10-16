#!/bin/bash

# Read DB password from Docker secret or env
DB_PASSWORD="${DB_PASSWORD:-}"
if [ -f "/run/secrets/db_password" ]; then
    DB_PASSWORD="$(cat /run/secrets/db_password)"
fi

# Read WP admin password from Docker secret or env, fallback to DB password
if [ -f "/run/secrets/wp_admin_password" ]; then
    WP_ADMIN_PASSWORD="$(cat /run/secrets/wp_admin_password)"
else
    WP_ADMIN_PASSWORD="${WP_ADMIN_PASSWORD:-$DB_PASSWORD}"
fi

# DB host (default to the mariadb service)
DB_HOST="${DB_HOST:-mariadb}"

# Wait for MariaDB to be ready
until mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "USE $DB_NAME" 2>/dev/null; do
    echo "Waiting for MariaDB at ${DB_HOST}..."
    sleep 2
done
echo "MariaDB is ready."

mkdir -p /run/php

if [ ! -f "/var/www/html/wp-config.php" ]; then
    echo "WordPress not found. Installing now..."

    wp core download --allow-root

    wp config create --dbname="$DB_NAME" \
                     --dbuser="$DB_USER" \
                     --dbpass="$DB_PASS" \
                     --dbhost="mariadb" \
                     --allow-root

    # Install WordPress with HTTPS protocol
    wp core install --url="https://$DOMAIN_NAME" \
                    --title="My Inception Project" \
                    --admin_user="$WP_ADMIN_USER" \
                    --admin_password="$WP_ADMIN_PASS" \
                    --admin_email="user@example.com" \
                    --skip-email \
                    --allow-root

    echo "WordPress installed successfully."
else
    echo "WordPress is already installed."
fi

echo "Setting file permissions..."
chown -R www-data:www-data /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;
echo "Permissions set."

exec "$@"