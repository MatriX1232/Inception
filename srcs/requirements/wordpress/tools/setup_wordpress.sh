#!/bin/bash
set -euo pipefail

read_secret() {
    local secret_path=$1
    [[ -f "$secret_path" ]] && cat "$secret_path"
}

DB_PASS=${DB_PASS:-$(read_secret /run/secrets/db_password || true)}
WP_ADMIN_PASS=${WP_ADMIN_PASS:-$(read_secret /run/secrets/wp_admin_password || true)}
WP_ADMIN_PASS=${WP_ADMIN_PASS:-$DB_PASS}

wait_for_database() {
    until mysql -h mariadb -u "${DB_USER}" -p"${DB_PASS}" -e "SELECT 1" >/dev/null 2>&1; do
        echo "Awaiting MariaDB availability..."
        sleep 2
    done
    echo "MariaDB connection established."
}

prepare_runtime() {
    mkdir -p /run/php
}

bootstrap_wordpress() {
    if [[ ! -f /var/www/html/wp-config.php ]]; then
        echo "Initializing WordPress..."
        wp core download --allow-root
        wp config create \
            --dbname="${DB_NAME}" \
            --dbuser="${DB_USER}" \
            --dbpass="${DB_PASS}" \
            --dbhost="mariadb" \
            --allow-root
        wp core install \
            --url="https://${DOMAIN_NAME}" \
            --title="My Inception Project" \
            --admin_user="${WP_ADMIN_USER}" \
            --admin_password="${WP_ADMIN_PASS}" \
            --admin_email="user@example.com" \
            --skip-email \
            --allow-root
        echo "WordPress setup complete."
    else
        echo "Existing WordPress installation detected; skipping bootstrap."
    fi
}

fix_permissions() {
    echo "Applying ownership and permissions..."
    chown -R www-data:www-data /var/www/html
    find /var/www/html -type d -exec chmod 755 {} \;
    find /var/www/html -type f -exec chmod 644 {} \;
    echo "Ownership and permissions applied."
}

main() {
    wait_for_database
    prepare_runtime
    bootstrap_wordpress
    fix_permissions
    exec "$@"
}

main "$@"