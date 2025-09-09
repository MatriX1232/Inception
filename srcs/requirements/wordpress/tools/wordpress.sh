#!/bin/bash
set -e

mkdir -p /var/www/wordpress
cd /var/www/wordpress

if ! command -v wp >/dev/null 2>&1; then
  curl -sS -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
  chmod +x /usr/local/bin/wp
fi

MYSQL_PASSWORD="$(cat /run/secrets/db_password.txt)"
WP_ADMIN_PASSWORD="$(cat /run/secrets/wp_admin_password.txt)"
WP_USER_PASSWORD="$(cat /run/secrets/wp_user_password.txt)"

: "${MYSQL_DATABASE:?MYSQL_DATABASE missing}"
: "${MYSQL_USER:?MYSQL_USER missing}"
: "${MYSQL_PASSWORD:?MYSQL_PASSWORD missing}"
: "${MYSQL_HOST:?MYSQL_HOST missing}"
: "${SITE_TITLE:?SITE_TITLE missing}"
: "${WP_ADMIN_USER:?WP_ADMIN_USER missing}"
: "${WP_ADMIN_EMAIL:?WP_ADMIN_EMAIL missing}"
: "${WP_USER:?WP_USER missing}"
: "${WP_USER_EMAIL:?WP_USER_EMAIL missing}"

if [ ! -f wp-includes/version.php ]; then
  wp core download --allow-root
fi

if [ ! -f wp-config.php ]; then
  wp config create     --dbname="${MYSQL_DATABASE}"     --dbuser="${MYSQL_USER}"     --dbpass="${MYSQL_PASSWORD}"     --dbhost="${MYSQL_HOST}"     --skip-salts     --allow-root
  wp config shuffle-salts --allow-root
fi


i=0
until wp db check --allow-root >/dev/null 2>&1; do
  i=$((i+1))
  if [ "$i" -gt 60 ]; then
    echo "Database not reachable after 60s" >&2
    exit 1
  fi
  sleep 1
done


if ! wp core is-installed --allow-root; then
  wp core install     --url="https://${DOMAIN_NAME:-localhost}"     --title="${SITE_TITLE}"     --admin_user="${WP_ADMIN_USER}"     --admin_password="${WP_ADMIN_PASSWORD}"     --admin_email="${WP_ADMIN_EMAIL}"     --skip-email     --allow-root

  wp user create     "${WP_USER}" "${WP_USER_EMAIL}"     --user_pass="${WP_USER_PASSWORD}"     --role=subscriber     --allow-root
fi

mkdir -p /run/php
exec php-fpm7.4 -F
