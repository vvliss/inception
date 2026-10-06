#!/bin/bash

set -e

while ! mysqladmin ping \
    -h "$MYSQL_HOST" \
    -P "$MYSQL_PORT" \
    -u "$MYSQL_USER" \
    --password="$MYSQL_PASSWORD" \
    --connect-timeout=2 \
    --silent; do
    echo "Database not responding"
    sleep 1
done

echo "database is ready"

if [ ! -f /var/www/html/wp-load.php ]; then
    echo "downloading wp"

    wp core download \
        --allow-root \
        --path=/var/www/html
fi

#is wp alive
if [ ! -f /var/www/html/wp-config.php ]; then
    echo "wp doesn't exist"
    
    wp config create \
        --allow-root \
        --path=/var/www/html \
        --dbname="$MYSQL_DATABASE" \
        --dbuser="$MYSQL_USER" \
        --dbpass="$MYSQL_PASSWORD" \
        --dbhost="$MYSQL_HOST:$MYSQL_PORT"
fi

if ! wp core is-installed \
    --allow-root \
    --path=/var/www/html; then

    echo "installing wp"

    wp core install \
        --allow-root \
        --path=/var/www/html \
        --url="$DOMAIN_NAME" \
        --title="inception" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --skip-email
fi

if ! wp user get "$WP_USER" \
    --allow-root \
    --path=/var/www/html >/dev/null 2>&1; then

    echo "creating wp user"

    wp user create \
        --allow-root \
        --path=/var/www/html \
        "$WP_USER" \
        "$WP_USER_EMAIL" \
        --role=editor \
        --user_pass="$WP_USER_PASSWORD"
fi

exec "$@"